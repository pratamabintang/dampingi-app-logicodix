from dataclasses import dataclass

from app.auth import supabase
from app.auth.schemas import UserOut


class AccountDeleted(Exception):
    pass


class CurrentPasswordIncorrect(Exception):
    pass


class PasswordUnchanged(Exception):
    pass


@dataclass(frozen=True)
class Session:

    user_id: str
    email: str
    token: str


@dataclass(frozen=True)
class Account:

    user: dict
    token: str
    profile: dict


class EmailAlreadyRegistered(Exception):
    """Supabase answered with its pretend user: the address already exists."""


# An empty id is never a real user either.
_EMPTY_USER_IDS = frozenset({"", "00000000-0000-0000-0000-000000000000"})


def _id(user: dict) -> str:
    return user.get("id") or ""


def is_obfuscated_user(user: dict) -> bool:
    """True when Supabase answered with its pretend user, not the real one.

    With email confirmation on, `/signup` for an address that already exists
    and is confirmed answers `200` with a fabricated user instead of an
    error, so the endpoint cannot be used to probe which addresses are
    registered (see `docs/api/auth.md`). The fabrication carries a fresh
    random id, `role: ""`, empty `user_metadata`, and — the marker that does
    not depend on ids — an empty `identities` list. Every real answer,
    pending or confirmed, carries at least one identity.
    """
    return user.get("identities") == [] or _id(user) in _EMPTY_USER_IDS


def register_user(
    name: str,
    email: str,
    password: str,
    role: str,
    timezone: str = "Asia/Jakarta",
) -> Account:
    """Register, tolerating both signup answer shapes.

    With email confirmation on, Supabase answers `/signup` with the User
    object itself: no `session`, no `access_token`, and no `user` wrapper.
    The token is then empty and the caller must verify before logging in.

    An address that already exists and is confirmed comes back as the
    pretend user instead of an error; that is reported as
    `EmailAlreadyRegistered` rather than returned as a registration that
    never happened.
    """
    body = supabase.signup(name, email, password, role, timezone)
    user = body.get("user") or body
    if is_obfuscated_user(user):
        raise EmailAlreadyRegistered(email)
    session = body.get("session") or {}
    access_token = body.get("access_token") or session.get("access_token") or ""
    profile = supabase.fetch_profile(_id(user))
    return Account(user=user, token=access_token, profile=profile or {})


def login_user(email: str, password: str) -> Account:
    body = supabase.login(email, password)
    user = body.get("user") or {}
    profile = supabase.fetch_profile(user.get("id", ""))
    return Account(user=user, token=body.get("access_token", ""), profile=profile or {})


def verify_email(email: str, token: str) -> Account:
    """Exchange the signup confirmation OTP for a session."""
    body = supabase.verify_signup_otp(email, token)
    user = body.get("user") or body
    profile = {} if is_obfuscated_user(user) else supabase.fetch_profile(_id(user))
    return Account(
        user=user, token=body.get("access_token") or "", profile=profile or {}
    )


def resend_confirmation(email: str) -> None:
    """Ask Supabase to send the signup confirmation again."""
    supabase.resend_signup_confirmation(email)


def request_password_reset(email: str) -> None:
    """Ask Supabase to send the password-reset code."""
    supabase.send_recovery(email)


def reset_password(email: str, token: str, new_password: str) -> None:
    """Exchange the recovery code for a session and set the new password.

    The recovery answer carries a session, but it exists only to authorise
    the change: it is revoked straight after, so the caller does not stay
    logged in on a token minted from an email code.
    """
    body = supabase.verify_recovery_otp(email, token)
    user_token = body.get("access_token") or ""
    if not user_token:
        raise supabase.SupabaseError(400, "recovery returned no session")
    supabase.update_password(user_token, new_password)
    supabase.revoke_sessions(user_token)


def active_profile(user_id: str) -> dict:
    profile = supabase.fetch_profile(user_id)
    if profile and profile.get("deleted_at"):
        raise AccountDeleted()
    return profile or {}


def logout(session: Session) -> None:
    active_profile(session.user_id)

    try:
        supabase.revoke_sessions(session.token)
    except supabase.SupabaseError as exc:
        if exc.error_code == "session_not_found":
            return
        raise


def soft_delete_user(session: Session) -> None:
    active_profile(session.user_id)

    supabase.revoke_sessions(session.token)
    supabase.ban_user(session.user_id)
    supabase.tombstone_profile(session.user_id)

    from app.connections import supabase as connections_supabase

    try:
        connections_supabase.end_active_connections(session.user_id)
    except supabase.SupabaseError:
        pass


def profile_out(session: Session, profile: dict) -> UserOut:
    return UserOut(
        id=session.user_id,
        email=session.email,
        name=profile.get("name"),
        role=profile.get("role"),
    )


def user_out(account: Account) -> UserOut:
    metadata = account.user.get("user_metadata") or {}
    return UserOut(
        id=account.user.get("id", ""),
        email=account.user.get("email", ""),
        name=account.profile.get("name") or metadata.get("name"),
        role=account.profile.get("role") or metadata.get("role"),
    )


def update_name(session: Session, name: str) -> UserOut:
    profile = active_profile(session.user_id)
    updated = supabase.update_profile_name(session.user_id, name)
    return profile_out(session, {**profile, **updated})


def change_password(session: Session, current_password: str, new_password: str) -> None:
    active_profile(session.user_id)

    try:
        throwaway = supabase.login(session.email, current_password)
    except supabase.SupabaseError as exc:
        if exc.is_transport or exc.status == 429:
            raise
        raise CurrentPasswordIncorrect() from exc

    _revoke_quietly(throwaway.get("access_token", ""), scope="local")

    if current_password == new_password:
        raise PasswordUnchanged()

    supabase.update_password(session.token, new_password)
    supabase.revoke_sessions(session.token)


def _revoke_quietly(user_token: str, scope: str) -> None:
    try:
        supabase.revoke_sessions(user_token, scope=scope)
    except supabase.SupabaseError:
        pass
