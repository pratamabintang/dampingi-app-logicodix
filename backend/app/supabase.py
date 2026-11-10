from typing import Optional

import httpx

from app.config import get_settings

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


def _utc_now_iso() -> str:
    from datetime import datetime, timezone

    return datetime.now(timezone.utc).isoformat()
