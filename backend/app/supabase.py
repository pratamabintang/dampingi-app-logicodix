from typing import Any, Optional

import httpx

from app.config import get_settings, supabase_auth_http, supabase_service_http

TIMEOUT = 10.0

BAN_DURATION = "876000h"



_client_override: Optional[httpx.Client] = None
_default_client: Optional[httpx.Client] = None


def _client() -> httpx.Client:
    global _default_client
    if _client_override is not None:
        return _client_override
    if _default_client is None:
        _default_client = httpx.Client(timeout=TIMEOUT)
    return _default_client


def use_client(client: Optional[httpx.Client]) -> None:
    global _client_override
    _client_override = client


def _base_url() -> str:
    return get_settings().supabase_url.rstrip("/")


def _publishable_key() -> str:
    return get_settings().supabase_publishable_key


class SupabaseError(Exception):

    def __init__(self, status: int, message: str, error_code: Optional[str] = None):
        super().__init__(message)
        self.status = status
        self.message = message
        self.error_code = error_code

    @property
    def is_transport(self) -> bool:
        return self.status == 503 and self.error_code is None


def _error_from_response(resp: httpx.Response) -> SupabaseError:
    error_code = None
    message = resp.text
    try:
        body = resp.json()
        error_code = body.get("error_code") or body.get("code")
        message = body.get("msg") or body.get("message") or resp.text
    except ValueError:
        pass
    return SupabaseError(resp.status_code, message, error_code)


def _request(func, *args, **kwargs) -> httpx.Response:
    try:
        return func(*args, **kwargs)
    except httpx.HTTPError as exc:
        raise SupabaseError(503, f"Supabase unreachable: {exc}") from exc


def signup(name: str, email: str, password: str, role: str) -> dict:
    resp = _request(
        _client().post,
        f"{_base_url()}/auth/v1/signup",
        headers=supabase_auth_http(),
        json={
            "email": email,
            "password": password,
            "data": {"name": name, "role": role},
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
            "select": "user_id,name,deleted_at,role",
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


def _utc_now_iso() -> str:
    from datetime import datetime, timezone

    return datetime.now(timezone.utc).isoformat()


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
