from typing import Optional

import httpx

from app.config import supabase_auth_http, supabase_service_http
from app.supabase import (
    TIMEOUT,
    BAN_DURATION,
    _client,
    _base_url,
    _publishable_key,
    _error_from_response,
    _request,
    _utc_now_iso,
    SupabaseError,
)


def signup(
    name: str,
    email: str,
    password: str,
    role: str,
    timezone: str = "Asia/Jakarta",
) -> dict:
    resp = _request(
        _client().post,
        f"{_base_url()}/auth/v1/signup",
        headers=supabase_auth_http(),
        json={
            "email": email,
            "password": password,
            "data": {"name": name, "role": role, "timezone": timezone},
        },
        timeout=TIMEOUT,
    )
    if resp.status_code >= 400:
        raise _error_from_response(resp)
    return resp.json()


def login(email: str, password: str) -> dict:
    resp = _request(
        _client().post,
        f"{_base_url()}/auth/v1/token",
        params={"grant_type": "password"},
        headers=supabase_auth_http(),
        json={"email": email, "password": password},
        timeout=TIMEOUT,
    )
    if resp.status_code >= 400:
        raise _error_from_response(resp)
    return resp.json()


# The GoTrue `type` values that identify one-time passwords.
_SIGNUP_OTP_TYPE = "signup"
_RECOVERY_OTP_TYPE = "recovery"


def _verify_otp(email: str, token: str, otp_type: str) -> dict:
    """Exchange a one-time password for a session.

    `type` travels both as a query parameter and in the body: GoTrue
    versions differ on where they read it, unknown JSON fields are ignored,
    so sending both is the portable call.
    """
    resp = _request(
        _client().post,
        f"{_base_url()}/auth/v1/verify",
        params={"type": otp_type},
        headers=supabase_auth_http(),
        json={"email": email, "token": token, "type": otp_type},
        timeout=TIMEOUT,
    )
    if resp.status_code >= 400:
        raise _error_from_response(resp)
    return resp.json()


def verify_signup_otp(email: str, token: str) -> dict:
    """Exchange the signup confirmation OTP for a session."""
    return _verify_otp(email, token, _SIGNUP_OTP_TYPE)


def verify_recovery_otp(email: str, token: str) -> dict:
    """Exchange the password-reset OTP for a session."""
    return _verify_otp(email, token, _RECOVERY_OTP_TYPE)


def resend_signup_confirmation(email: str) -> None:
    """Ask Supabase to send the signup confirmation again."""
    resp = _request(
        _client().post,
        f"{_base_url()}/auth/v1/resend",
        headers=supabase_auth_http(),
        json={"type": _SIGNUP_OTP_TYPE, "email": email},
        timeout=TIMEOUT,
    )
    if resp.status_code >= 400:
        raise _error_from_response(resp)


def send_recovery(email: str) -> None:
    """Ask Supabase to send the password-reset code.

    GoTrue answers `200` for an unknown address too, so this does not tell
    the caller whether the account exists.
    """
    resp = _request(
        _client().post,
        f"{_base_url()}/auth/v1/recover",
        headers=supabase_auth_http(),
        json={"email": email},
        timeout=TIMEOUT,
    )
    if resp.status_code >= 400:
        raise _error_from_response(resp)


def update_profile_name(user_id: str, name: str) -> dict:
    resp = _request(
        _client().patch,
        f"{_base_url()}/rest/v1/profiles",
        params={"user_id": f"eq.{user_id}", "select": "user_id,name,deleted_at,role"},
        headers={**supabase_service_http(), "Prefer": "return=representation"},
        json={"name": name},
        timeout=TIMEOUT,
    )
    if resp.status_code >= 400:
        raise _error_from_response(resp)
    rows = resp.json()
    if not rows:
        raise SupabaseError(404, f"No profile row for user {user_id}")
    return rows[0]


def update_password(user_token: str, new_password: str) -> None:
    resp = _request(
        _client().put,
        f"{_base_url()}/auth/v1/user",
        headers={
            "apikey": _publishable_key(),
            "Authorization": f"Bearer {user_token}",
            "Content-Type": "application/json",
        },
        json={"password": new_password},
        timeout=TIMEOUT,
    )
    if resp.status_code >= 400:
        raise _error_from_response(resp)


def fetch_profile(user_id: str) -> Optional[dict]:
    resp = _request(
        _client().get,
        f"{_base_url()}/rest/v1/profiles",
        params={
            "user_id": f"eq.{user_id}",
            "select": "user_id,name,deleted_at,role,timezone",
        },
        headers=supabase_service_http(),
        timeout=TIMEOUT,
    )
    if resp.status_code >= 400:
        raise _error_from_response(resp)
    rows = resp.json()
    return rows[0] if rows else None


def tombstone_profile(user_id: str) -> bool:
    resp = _request(
        _client().patch,
        f"{_base_url()}/rest/v1/profiles",
        params={"user_id": f"eq.{user_id}"},
        headers=supabase_service_http(),
        json={"deleted_at": _utc_now_iso()},
        timeout=TIMEOUT,
    )
    if resp.status_code >= 400:
        raise _error_from_response(resp)
    return resp.status_code < 300


def ban_user(user_id: str) -> dict:
    resp = _request(
        _client().put,
        f"{_base_url()}/auth/v1/admin/users/{user_id}",
        headers=supabase_service_http(),
        json={"ban_duration": BAN_DURATION},
        timeout=TIMEOUT,
    )
    if resp.status_code >= 400:
        raise _error_from_response(resp)
    return resp.json()


def admin_confirm_user(user_id: str) -> dict:
    """Mark an address confirmed without the user entering anything.

    Used by the seeder: with email confirmation on, a fresh signup stays
    pending and the deterministic seed accounts could not log in. The admin
    update is idempotent, so re-running the seeder is safe.
    """
    resp = _request(
        _client().put,
        f"{_base_url()}/auth/v1/admin/users/{user_id}",
        headers=supabase_service_http(),
        json={"email_confirm": True},
        timeout=TIMEOUT,
    )
    if resp.status_code >= 400:
        raise _error_from_response(resp)
    return resp.json()


def admin_create_user(
    name: str,
    email: str,
    password: str,
    role: str,
    timezone: str = "Asia/Jakarta",
) -> dict:
    """Create a confirmed account without sending a confirmation email.

    The live suite needs a few hundred authenticated fixtures per run.
    `POST /auth/register` mails a code for every one of them, which would
    spend the project's whole send quota on tests. This admin call sends
    nothing; the `handle_new_user` trigger still writes the Profile row
    from the metadata, exactly as a signup would.
    """
    resp = _request(
        _client().post,
        f"{_base_url()}/auth/v1/admin/users",
        headers=supabase_service_http(),
        json={
            "email": email,
            "password": password,
            "email_confirm": True,
            "user_metadata": {"name": name, "role": role, "timezone": timezone},
        },
        timeout=TIMEOUT,
    )
    if resp.status_code >= 400:
        raise _error_from_response(resp)
    return resp.json()


def revoke_sessions(user_token: str, scope: str = "global") -> None:
    resp = _request(
        _client().post,
        f"{_base_url()}/auth/v1/logout",
        params={"scope": scope},
        headers={
            "apikey": _publishable_key(),
            "Authorization": f"Bearer {user_token}",
        },
        timeout=TIMEOUT,
    )
    if resp.status_code >= 400:
        raise _error_from_response(resp)


def update_own_metadata(user_token: str, metadata: dict) -> dict:
    resp = _request(
        _client().put,
        f"{_base_url()}/auth/v1/user",
        headers={
            "apikey": _publishable_key(),
            "Authorization": f"Bearer {user_token}",
            "Content-Type": "application/json",
        },
        json={"data": metadata},
        timeout=TIMEOUT,
    )
    if resp.status_code >= 400:
        raise _error_from_response(resp)
    return resp.json()


def refresh_grant(refresh_token: str) -> httpx.Response:
    return _request(
        _client().post,
        f"{_base_url()}/auth/v1/token",
        params={"grant_type": "refresh_token"},
        json={"refresh_token": refresh_token},
        headers=supabase_auth_http(),
        timeout=TIMEOUT,
    )


def admin_list_users(page: int = 1, per_page: int = 100) -> tuple:
    resp = _request(
        _client().get,
        f"{_base_url()}/auth/v1/admin/users",
        params={"page": page, "per_page": per_page},
        headers=supabase_service_http(),
        timeout=TIMEOUT,
    )
    if resp.status_code >= 400:
        raise _error_from_response(resp)
    body = resp.json()
    total = resp.headers.get("x-total-count")
    return body.get("users", []), body.get("next_page"), total


def generate_signup_otp(email: str) -> str:
    """Mint a fresh signup confirmation code without sending an email.

    Admin-only (`generate_link`): it lets a flow be finished end to end when
    there is no mailbox to read, as in the live tests. Needs the secret key,
    so no request from a caller can reach it.
    """
    resp = _request(
        _client().post,
        f"{_base_url()}/auth/v1/admin/generate_link",
        headers=supabase_service_http(),
        json={"type": _SIGNUP_OTP_TYPE, "email": email},
        timeout=TIMEOUT,
    )
    if resp.status_code >= 400:
        raise _error_from_response(resp)
    return resp.json()["email_otp"]


def delete_user(user_id: str) -> bool:
    resp = _request(
        _client().delete,
        f"{_base_url()}/auth/v1/admin/users/{user_id}",
        headers=supabase_service_http(),
        timeout=TIMEOUT,
    )
    if resp.status_code < 300:
        return True
    if resp.status_code == 404:
        return False
    raise _error_from_response(resp)


def jwks_url() -> str:
    return f"{_base_url()}/auth/v1/.well-known/jwks.json"
