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


def register_user(name: str, email: str, password: str, role: str) -> Account:
    body = supabase.signup(name, email, password, role)
    user = body.get("user") or {}
    session = body.get("session") or {}
    access_token = body.get("access_token") or session.get("access_token")
    profile = supabase.fetch_profile(user.get("id", ""))
    return Account(user=user, token=access_token or "", profile=profile or {})


def login_user(email: str, password: str) -> Account:
    body = supabase.login(email, password)
    user = body.get("user") or {}
    profile = supabase.fetch_profile(user.get("id", ""))
    return Account(user=user, token=body.get("access_token", ""), profile=profile or {})


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
    return UserOut(
        id=account.user.get("id", ""),
        email=account.user.get("email", ""),
        name=account.profile.get("name"),
        role=account.profile.get("role"),
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
