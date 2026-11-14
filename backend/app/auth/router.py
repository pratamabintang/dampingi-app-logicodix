from enum import Enum
from typing import Optional

import jwt
from fastapi import APIRouter, Depends, HTTPException, Request, Response
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jwt import PyJWKClient

from app.auth import supabase, service
from app.auth.schemas import (
    ChangePasswordRequest,
    ForgotPasswordRequest,
    LoginRequest,
    LoginResponse,
    PASSWORD_RULE,
    RefreshRequest,
    RefreshResponse,
    RegisterRequest,
    RegisterResponse,
    ResendConfirmationRequest,
    ResetPasswordRequest,
    UpdateMeRequest,
    UserOut,
    VerifyEmailRequest,
)
from app.config import get_settings
from app import throttle

router = APIRouter(tags=["auth"])

_ALGORITHMS = ("ES256", "RS256", "PS256", "EdDSA")

_jwk_client: Optional[PyJWKClient] = None


def _jwk() -> PyJWKClient:
    global _jwk_client
    if _jwk_client is None:
        _jwk_client = PyJWKClient(supabase.jwks_url(), cache_keys=True)
    return _jwk_client


def _issuer() -> str:
    return f"{get_settings().supabase_url.rstrip('/')}/auth/v1"

bearer = HTTPBearer(auto_error=False)


def verified_session(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(bearer),
) -> service.Session:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(status_code=401, detail="Missing bearer token")
    token = credentials.credentials
    try:
        signing_key = _jwk().get_signing_key_from_jwt(token)
        claims = jwt.decode(
            token,
            signing_key.key,
            algorithms=list(_ALGORITHMS),
            audience="authenticated",
            issuer=_issuer(),
            options={"require": ["exp", "sub"]},
        )
    except jwt.PyJWKClientError as exc:
        raise HTTPException(
            status_code=401,
            detail=(
                "Token rejected: no trusted signing key matched. If your "
                "Supabase project still uses the legacy JWT secret, "
                "migrate to signing keys (docs/supabase-setup.md)."
            ),
        ) from exc
    except jwt.InvalidTokenError as exc:
        raise HTTPException(status_code=401, detail="Invalid or expired token") from exc
    return service.Session(user_id=claims["sub"], email=claims.get("email", ""), token=token)


def _deleted() -> HTTPException:
    return HTTPException(status_code=403, detail="This account has been deleted")


def _invalid_credentials() -> HTTPException:
    return HTTPException(status_code=401, detail="Invalid email or password")


def _already_registered() -> HTTPException:
    return HTTPException(
        status_code=409, detail="This Gmail address is already registered"
    )


# Supabase spaces confirmation codes per address and answers `429` with its
# own cooldown; the app should back off for about a minute either way.
_UPSTREAM_COOLDOWN_SECONDS = 60


def _upstream_cooldown() -> throttle.RateLimited:
    return throttle.RateLimited(_UPSTREAM_COOLDOWN_SECONDS)


def _unverified_email() -> HTTPException:
    return HTTPException(
        status_code=403,
        detail="Email belum diverifikasi. Cek email untuk kode verifikasi.",
    )


def _handle_auth_errors(func, *args):
    try:
        return func(*args)
    except service.AccountDeleted as exc:
        raise _deleted() from exc
    except supabase.SupabaseError as exc:
        if _is_banned(exc):
            raise _deleted() from exc
        raise


def _is_banned(exc: supabase.SupabaseError) -> bool:
    return exc.error_code == "user_banned"


def _is_weak_password(exc: supabase.SupabaseError) -> bool:
    return exc.error_code == "weak_password"


def _weak_password() -> HTTPException:
    return HTTPException(status_code=422, detail=PASSWORD_RULE)


def _is_unverified(exc: supabase.SupabaseError) -> bool:
    return exc.error_code == "email_not_confirmed"


@router.post(
    "/auth/register",
    status_code=201,
    response_model=RegisterResponse,
    summary="Register with name, Gmail address, password, role, and timezone",
)
def register(request: Request, payload: RegisterRequest) -> RegisterResponse:
    throttle.record_registration(request, payload.email)
    try:
        account = service.register_user(
            payload.name,
            payload.email,
            payload.password,
            payload.role.value,
            payload.timezone,
        )
    except service.EmailAlreadyRegistered as exc:
        raise _already_registered() from exc
    except supabase.SupabaseError as exc:
        if exc.status == 429:
            raise _upstream_cooldown() from exc
        if _is_weak_password(exc):
            raise _weak_password() from exc
        if exc.error_code in ("user_already_exists", "email_exists") or (
            "already registered" in exc.message.lower()
            or "already been registered" in exc.message.lower()
        ):
            raise _already_registered() from exc
        raise
    return RegisterResponse(user=service.user_out(account), access_token=account.token or None)


@router.post(
    "/auth/login",
    response_model=LoginResponse,
    summary="Log in with Gmail address and password",
)
def login(request: Request, payload: LoginRequest) -> LoginResponse:
    if throttle.record_login(request, payload.email) is not None:
        raise _invalid_credentials()
    try:
        account = service.login_user(payload.email, payload.password)
    except supabase.SupabaseError as exc:
        if _is_banned(exc):
            raise _deleted() from exc
        if _is_unverified(exc):
            raise _unverified_email() from exc
        if exc.status == 503:
            raise
        raise _invalid_credentials() from exc
    return LoginResponse(
        access_token=account.token,
        refresh_token=account.refresh_token or None,
        expires_in=account.expires_in,
        user=service.user_out(account),
    )


@router.post(
    "/auth/refresh",
    response_model=RefreshResponse,
    summary="Exchange a refresh token for a new Session pair",
    description=(
        "Rotates the refresh token: the caller must replace its stored pair "
        "with the one returned here. A token Supabase no longer accepts ends "
        "the Session with `401`; the client must log in again."
    ),
)
def refresh(request: Request, payload: RefreshRequest) -> RefreshResponse:
    throttle.record_refresh(request)
    try:
        session = service.refresh_session(payload.refresh_token)
    except supabase.SupabaseError as exc:
        if exc.status == 429:
            raise _upstream_cooldown() from exc
        if exc.status >= 500:
            raise
        raise HTTPException(
            status_code=401,
            detail="Sesi tidak valid. Silakan masuk kembali.",
        ) from exc
    return RefreshResponse(
        access_token=session.access_token,
        refresh_token=session.refresh_token,
        expires_in=session.expires_in,
    )


@router.post(
    "/auth/verify-email",
    response_model=LoginResponse,
    summary="Confirm an email address with the code Supabase sent",
    description=(
        "Exchanges the signup confirmation code for a session, so the "
        "caller is logged in as soon as the address is confirmed. Wrong or "
        "expired codes answer the same `400`, which keeps the endpoint from "
        "telling an attacker whether an address is registered (ADR-0005)."
    ),
)
def verify_email(request: Request, payload: VerifyEmailRequest) -> LoginResponse:
    throttle.record_verification(request, payload.email)
    try:
        account = service.verify_email(payload.email, payload.token)
    except supabase.SupabaseError as exc:
        if _is_banned(exc):
            raise _deleted() from exc
        if exc.status >= 500:
            raise
        if exc.status == 429:
            raise _upstream_cooldown() from exc
        raise HTTPException(
            status_code=400,
            detail="Kode verifikasi salah atau sudah kedaluwarsa.",
        ) from exc
    return LoginResponse(
        access_token=account.token,
        refresh_token=account.refresh_token or None,
        expires_in=account.expires_in,
        user=service.user_out(account),
    )


@router.post(
    "/auth/resend-confirmation",
    status_code=202,
    summary="Ask for a fresh signup confirmation code",
    description=(
        "Always answers `202` with the same body, whether or not the address "
        "is registered, so it cannot be used to enumerate accounts. Upstream "
        "outages (`503`) and upstream rate limits (`429`) are still surfaced."
    ),
)
def resend_confirmation(request: Request, payload: ResendConfirmationRequest) -> dict:
    throttle.record_resend(request, payload.email)
    try:
        service.resend_confirmation(payload.email)
    except supabase.SupabaseError as exc:
        if exc.status == 429:
            raise _upstream_cooldown() from exc
        if exc.status >= 500:
            raise
    return {"detail": "Jika email terdaftar, kode verifikasi sudah dikirim ulang."}


@router.post(
    "/auth/forgot-password",
    status_code=202,
    summary="Ask for a password-reset code",
    description=(
        "Always answers `202` with the same body, whether or not the address "
        "is registered, so it cannot be used to enumerate accounts. Upstream "
        "outages (`503`) and upstream rate limits (`429`) are still surfaced."
    ),
)
def forgot_password(request: Request, payload: ForgotPasswordRequest) -> dict:
    throttle.record_forgot(request, payload.email)
    try:
        service.request_password_reset(payload.email)
    except supabase.SupabaseError as exc:
        if exc.status == 429:
            raise _upstream_cooldown() from exc
        if exc.status >= 500:
            raise
    return {"detail": "Jika email terdaftar, kode reset sudah dikirim."}


@router.post(
    "/auth/reset-password",
    status_code=204,
    summary="Set a new password with the code from the reset email",
    description=(
        "Exchanges the recovery code for a session, sets the new password "
        "and revokes every session. Wrong or expired codes answer the same "
        "`400`, so the endpoint does not reveal whether an address exists."
    ),
)
def reset_password(request: Request, payload: ResetPasswordRequest) -> Response:
    throttle.record_reset(request, payload.email)
    try:
        service.reset_password(payload.email, payload.token, payload.new_password)
    except supabase.SupabaseError as exc:
        if _is_banned(exc):
            raise _deleted() from exc
        if _is_weak_password(exc):
            raise _weak_password() from exc
        if exc.error_code == "same_password" or "different from the old" in exc.message.lower():
            raise HTTPException(
                status_code=400,
                detail="Sandi baru harus berbeda dari sandi lama.",
            ) from exc
        if exc.status == 429:
            raise _upstream_cooldown() from exc
        if exc.status >= 500:
            raise
        raise HTTPException(
            status_code=400,
            detail="Kode reset salah atau sudah kedaluwarsa.",
        ) from exc
    return Response(status_code=204)


@router.get(
    "/me",
    response_model=UserOut,
    summary="The registered name, email, and role of the caller",
)
def me(session: service.Session = Depends(verified_session)) -> UserOut:
    profile = _handle_auth_errors(service.active_profile, session.user_id)
    return service.profile_out(session, profile)


@router.post(
    "/auth/logout",
    status_code=204,
    summary="Log out: revoke every session for the caller",
    description=(
        "Revokes all refresh tokens (scope=global), so no new access tokens "
        "can be minted from any of the caller's sessions. The current access "
        "token is NOT invalidated: Supabase has no access-token revocation, "
        "so it keeps verifying until it expires. Idempotent — calling it "
        "again is a no-op that still returns 204."
    ),
)
def logout(session: service.Session = Depends(verified_session)):
    _handle_auth_errors(service.logout, session)
    return Response(status_code=204)


@router.patch(
    "/me",
    response_model=UserOut,
    summary="Change the caller's name (role is immutable)",
    description=(
        "The only editable Profile field is the name. Sending any other "
        "field — including `role` — is rejected with 422: a silently "
        "ignored role would read as success to the caller (ADR-0005)."
    ),
)
def update_me(
    payload: UpdateMeRequest, session: service.Session = Depends(verified_session)
) -> UserOut:
    return _handle_auth_errors(service.update_name, session, payload.name)


@router.post(
    "/auth/password",
    status_code=204,
    summary="Change the caller's password (current password required)",
    description=(
        "Verifies `current_password` by attempting a login, then sets "
        "`new_password` and revokes every session — the caller must log in "
        "again. Other devices' live access tokens keep working until they "
        "expire (Supabase has no access-token revocation)."
    ),
)
def change_password(
    payload: ChangePasswordRequest,
    session: service.Session = Depends(verified_session),
):
    try:
        service.change_password(
            session, payload.current_password, payload.new_password
        )
    except service.AccountDeleted as exc:
        raise _deleted() from exc
    except service.CurrentPasswordIncorrect as exc:
        raise HTTPException(status_code=400, detail="Current password is incorrect") from exc
    except service.PasswordUnchanged as exc:
        raise HTTPException(
            status_code=400, detail="New password must differ from the current one"
        ) from exc
    except supabase.SupabaseError as exc:
        if _is_banned(exc):
            raise _deleted() from exc
        if _is_weak_password(exc):
            raise _weak_password() from exc
        if exc.error_code == "current_password_invalid":
            raise HTTPException(
                status_code=400, detail="Current password is incorrect"
            ) from exc
        if exc.error_code == "current_password_required":
            raise HTTPException(
                status_code=400,
                detail="Current password is required to set a new password.",
            ) from exc
        raise
    return Response(status_code=204)

@router.delete(
    "/me",
    status_code=204,
    summary="Soft-delete the caller's account (data is retained)",
)
def delete_me(session: service.Session = Depends(verified_session)):
    try:
        service.soft_delete_user(session)
    except service.AccountDeleted as exc:
        raise _deleted() from exc
    except supabase.SupabaseError as exc:
        raise
    return Response(status_code=204)
