from typing import Optional

from app.config import supabase_service_http
from app.supabase import (
    TIMEOUT,
    _base_url,
    _client,
    _error_from_response,
    _request,
    _utc_now_iso,
    SupabaseError,
)

_COLUMNS = (
    "id,connection_id,content,created_at,updated_at,deleted_at,"
    "connection:connections!inner("
    "id,mother_id,counterpart_id,counterpart_role,ended_at)"
)

_FLAT_COLUMNS = "id,connection_id,content,created_at,updated_at,deleted_at"

_PAGE_SIZE = 1000
_MAX_PAGES = 200

_MOTHER = "mother"
_PROFESSIONAL = "professional"


def fetch_active_professional_connection(
    professional_id: str, connection_id: str
) -> Optional[dict]:
    resp = _request(
        _client().get,
        f"{_base_url()}/rest/v1/connections",
        params={
            "id": f"eq.{connection_id}",
            "counterpart_id": f"eq.{professional_id}",
            "counterpart_role": f"eq.{_PROFESSIONAL}",
            "ended_at": "is.null",
            "select": (
                "id,mother_id,counterpart_id,counterpart_role,ended_at"
            ),
            "limit": "1",
        },
        headers=supabase_service_http(),
        timeout=TIMEOUT,
    )
    if resp.status_code >= 400:
        raise _error_from_response(resp)
    rows = resp.json()
    return rows[0] if rows else None


def create_note(connection_id: str, content: str) -> dict:
    resp = _request(
        _client().post,
        f"{_base_url()}/rest/v1/professional_notes",
        headers={**supabase_service_http(), "Prefer": "return=representation"},
        json={"connection_id": connection_id, "content": content},
        timeout=TIMEOUT,
    )
    if resp.status_code >= 400:
        raise _error_from_response(resp)
    rows = resp.json()
    if not rows:
        raise SupabaseError(500, "No row returned after insert")
    return rows[0]


def _scope_filters(user_id: str, role: str) -> list[tuple[str, str]]:
    if role == _MOTHER:
        return [("connection.mother_id", f"eq.{user_id}")]
    return [
        ("connection.counterpart_id", f"eq.{user_id}"),
        ("connection.counterpart_role", f"eq.{_PROFESSIONAL}"),
    ]


def fetch_note(user_id: str, role: str, note_id: str) -> Optional[dict]:
    resp = _request(
        _client().get,
        f"{_base_url()}/rest/v1/professional_notes",
        params=[
            ("id", f"eq.{note_id}"),
            ("deleted_at", "is.null"),
            ("select", _COLUMNS),
            *_scope_filters(user_id, role),
            ("limit", "1"),
        ],
        headers=supabase_service_http(),
        timeout=TIMEOUT,
    )
    if resp.status_code >= 400:
        raise _error_from_response(resp)
    rows = resp.json()
    return rows[0] if rows else None


def update_note(note_id: str, content: str) -> Optional[dict]:
    resp = _request(
        _client().patch,
        f"{_base_url()}/rest/v1/professional_notes",
        params={
            "id": f"eq.{note_id}",
            "deleted_at": "is.null",
            "select": _FLAT_COLUMNS,
        },
        headers={**supabase_service_http(), "Prefer": "return=representation"},
        json={"content": content},
        timeout=TIMEOUT,
    )
    if resp.status_code >= 400:
        raise _error_from_response(resp)
    rows = resp.json()
    return rows[0] if rows else None


def soft_delete_note(note_id: str) -> bool:
    resp = _request(
        _client().patch,
        f"{_base_url()}/rest/v1/professional_notes",
        params={
            "id": f"eq.{note_id}",
            "deleted_at": "is.null",
            "select": "id",
        },
        headers={**supabase_service_http(), "Prefer": "return=representation"},
        json={"deleted_at": _utc_now_iso()},
        timeout=TIMEOUT,
    )
    if resp.status_code >= 400:
        raise _error_from_response(resp)
    return bool(resp.json())


def _filters(
    user_id: str, role: str, connection_id: Optional[str]
) -> list[tuple[str, str]]:
    params: list[tuple[str, str]] = [
        ("deleted_at", "is.null"),
        *_scope_filters(user_id, role),
    ]
    if connection_id is not None:
        params.append(("connection_id", f"eq.{connection_id}"))
    return params


def list_notes_all(
    user_id: str, role: str, connection_id: Optional[str]
) -> list:
    collected: list = []
    offset = 0

    for _ in range(_MAX_PAGES):
        resp = _request(
            _client().get,
            f"{_base_url()}/rest/v1/professional_notes",
            params=[
                *_filters(user_id, role, connection_id),
                ("select", _COLUMNS),
                ("order", "created_at.desc,id.desc"),
                ("limit", str(_PAGE_SIZE)),
                ("offset", str(offset)),
            ],
            headers=supabase_service_http(),
            timeout=TIMEOUT,
        )
        if resp.status_code >= 400:
            raise _error_from_response(resp)

        page = resp.json()
        if not page:
            return collected
        collected.extend(page)
        offset += len(page)

    raise SupabaseError(
        500,
        f"Listing professional notes did not terminate after {_MAX_PAGES} "
        "pages; the upstream appears to be ignoring the offset parameter",
    )


def list_notes(
    user_id: str,
    role: str,
    connection_id: Optional[str],
    offset: int,
    limit: int,
) -> tuple[list, int]:
    count_resp = _request(
        _client().get,
        f"{_base_url()}/rest/v1/professional_notes",
        params=[
            *_filters(user_id, role, connection_id),
            ("select", "id,connection:connections!inner(id)"),
        ],
        headers={**supabase_service_http(), "Prefer": "count=exact"},
        timeout=TIMEOUT,
    )
    if count_resp.status_code >= 400:
        raise _error_from_response(count_resp)
    total = int(count_resp.headers.get("content-range", "0/0").split("/")[1])

    resp = _request(
        _client().get,
        f"{_base_url()}/rest/v1/professional_notes",
        params=[
            *_filters(user_id, role, connection_id),
            ("select", _COLUMNS),
            ("order", "created_at.desc,id.desc"),
            ("offset", str(offset)),
            ("limit", str(limit)),
        ],
        headers=supabase_service_http(),
        timeout=TIMEOUT,
    )
    if resp.status_code >= 400:
        raise _error_from_response(resp)
    return resp.json(), total
