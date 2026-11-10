from datetime import date
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
    "id,connection_id,questions,answers,day,completed_at,created_at,"
    "connection:connections!inner(id,mother_id,counterpart_id)"
)

_FLAT_COLUMNS = (
    "id,connection_id,questions,answers,day,completed_at,created_at"
)

_PAGE_SIZE = 1000
_MAX_PAGES = 200

_DRAFT = "draft"
_COMPLETED = "completed"


def fetch_active_connection(companion_id: str, mother_id: str) -> Optional[dict]:
    resp = _request(
        _client().get,
        f"{_base_url()}/rest/v1/connections",
        params={
            "mother_id": f"eq.{mother_id}",
            "counterpart_id": f"eq.{companion_id}",
            "counterpart_role": "eq.companion",
            "ended_at": "is.null",
            "select": "id,mother_id,counterpart_id",
        },
        headers=supabase_service_http(),
        timeout=TIMEOUT,
    )
    if resp.status_code >= 400:
        raise _error_from_response(resp)
    rows = resp.json()
    return rows[0] if rows else None


def create_observation(connection_id: str, questions: list[dict]) -> dict:
    resp = _request(
        _client().post,
        f"{_base_url()}/rest/v1/observations",
        headers={**supabase_service_http(), "Prefer": "return=representation"},
        json={
            "connection_id": connection_id,
            "questions": questions,
        },
        timeout=TIMEOUT,
    )
    if resp.status_code >= 400:
        raise _error_from_response(resp)
    rows = resp.json()
    if not rows:
        raise SupabaseError(500, "No row returned after insert")
    return rows[0]


def fetch_observation(user_id: str, observation_id: str) -> Optional[dict]:
    resp = _request(
        _client().get,
        f"{_base_url()}/rest/v1/observations",
        params=[
            ("id", f"eq.{observation_id}"),
            ("select", _COLUMNS),
            ("connection.counterpart_id", f"eq.{user_id}"),
            ("limit", "1"),
        ],
        headers=supabase_service_http(),
        timeout=TIMEOUT,
    )
    if resp.status_code >= 400:
        raise _error_from_response(resp)
    rows = resp.json()
    return rows[0] if rows else None


def _filters(
    user_id: str,
    connection_id: Optional[str] = None,
    day: Optional[date] = None,
    status: Optional[str] = None,
) -> list[tuple[str, str]]:
    params: list[tuple[str, str]] = [
        ("connection.counterpart_id", f"eq.{user_id}"),
    ]
    if connection_id is not None:
        params.append(("connection_id", f"eq.{connection_id}"))
    if day is not None:
        params.append(("day", f"eq.{day.isoformat()}"))
    if status == _DRAFT:
        params.append(("completed_at", "is.null"))
    elif status == _COMPLETED:
        params.append(("completed_at", "not.is.null"))
    return params


def list_observations_all(
    user_id: str,
    connection_id: Optional[str] = None,
    day: Optional[date] = None,
    status: Optional[str] = None,
) -> list:
    collected: list = []
    offset = 0

    for _ in range(_MAX_PAGES):
        resp = _request(
            _client().get,
            f"{_base_url()}/rest/v1/observations",
            params=[
                *_filters(user_id, connection_id, day, status),
                ("select", _COLUMNS),
                ("order", "created_at.desc"),
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
        f"Listing observations did not terminate after {_MAX_PAGES} pages; "
        "the upstream appears to be ignoring the offset parameter",
    )


def list_observations(
    user_id: str,
    connection_id: Optional[str],
    day: Optional[date],
    status: Optional[str],
    offset: int,
    limit: int,
) -> tuple[list, int]:
    count_resp = _request(
        _client().get,
        f"{_base_url()}/rest/v1/observations",
        params=[
            *_filters(user_id, connection_id, day, status),
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
        f"{_base_url()}/rest/v1/observations",
        params=[
            *_filters(user_id, connection_id, day, status),
            ("select", _COLUMNS),
            ("order", "created_at.desc"),
            ("offset", str(offset)),
            ("limit", str(limit)),
        ],
        headers=supabase_service_http(),
        timeout=TIMEOUT,
    )
    if resp.status_code >= 400:
        raise _error_from_response(resp)
    return resp.json(), total


def complete_observation(
    observation_id: str, answers: list[dict], day: date
) -> Optional[dict]:
    resp = _request(
        _client().patch,
        f"{_base_url()}/rest/v1/observations",
        params={
            "id": f"eq.{observation_id}",
            "completed_at": "is.null",
            "select": _FLAT_COLUMNS,
        },
        headers={**supabase_service_http(), "Prefer": "return=representation"},
        json={
            "answers": answers,
            "day": day.isoformat(),
            "completed_at": _utc_now_iso(),
        },
        timeout=TIMEOUT,
    )
    if resp.status_code >= 400:
        raise _error_from_response(resp)
    rows = resp.json()
    return rows[0] if rows else None
