from app.config import supabase_service_http
from app.supabase import (
    TIMEOUT,
    _client,
    _base_url,
    _error_from_response,
    _request,
    SupabaseError,
)


def create_mood(user_id: str, created_at: str, mood: int, description: str | None = None) -> dict:
    payload = {
        "user_id": user_id,
        "created_at": created_at,
        "mood": mood,
    }
    if description is not None:
        payload["description"] = description
    
    resp = _request(
        _client().post,
        f"{_base_url()}/rest/v1/moods",
        headers={**supabase_service_http(), "Prefer": "return=representation"},
        json=payload,
        timeout=TIMEOUT,
    )
    if resp.status_code >= 400:
        raise _error_from_response(resp)
    rows = resp.json()
    if not rows:
        raise SupabaseError(500, "No row returned after insert")
    return rows[0]


def fetch_mood(user_id: str, created_at: str) -> dict | None:
    resp = _request(
        _client().get,
        f"{_base_url()}/rest/v1/moods",
        params={
            "user_id": f"eq.{user_id}",
            "created_at": f"eq.{created_at}",
            "select": "user_id,created_at,mood,description",
        },
        headers=supabase_service_http(),
        timeout=TIMEOUT,
    )
    if resp.status_code >= 400:
        raise _error_from_response(resp)
    rows = resp.json()
    return rows[0] if rows else None


_PAGE_SIZE = 1000

_MAX_PAGES = 200

def list_moods_all(
    user_id: str,
    start_date: str | None = None,
    end_date: str | None = None,
) -> tuple[list, int]:
    filters = {"user_id": f"eq.{user_id}"}
    conditions: list[tuple[str, str]] = []
    if start_date:
        conditions.append(("created_at", f"gte.{start_date}"))
    if end_date:
        conditions.append(("created_at", f"lte.{end_date}"))

    collected: list = []
    offset = 0

    for _ in range(_MAX_PAGES):
        resp = _request(
            _client().get,
            f"{_base_url()}/rest/v1/moods",
            params=[
                *filters.items(),
                ("select", "user_id,created_at,mood,description"),
                ("order", "created_at.desc"),
                ("limit", str(_PAGE_SIZE)),
                ("offset", str(offset)),
                *conditions,
            ],
            headers=supabase_service_http(),
            timeout=TIMEOUT,
        )
        if resp.status_code >= 400:
            raise _error_from_response(resp)

        page = resp.json()
        if not page:
            return collected, len(collected)

        collected.extend(page)
        offset += len(page)

    raise SupabaseError(
        500,
        f"Listing moods did not terminate after {_MAX_PAGES} pages; "
        "the upstream appears to be ignoring the offset parameter",
    )



def list_moods(
    user_id: str,
    start_date: str | None = None,
    end_date: str | None = None,
    offset: int = 0,
    limit: int = 20,
) -> tuple[list, int]:
    filters = {"user_id": f"eq.{user_id}"}
    conditions: list[tuple[str, str]] = []
    if start_date:
        conditions.append(("created_at", f"gte.{start_date}"))
    if end_date:
        conditions.append(("created_at", f"lte.{end_date}"))

    count_resp = _request(
        _client().get,
        f"{_base_url()}/rest/v1/moods",
        params=[
            *filters.items(),
            ("select", "count"),
            *conditions,
        ],
        headers={**supabase_service_http(), "Prefer": "count=exact"},
        timeout=TIMEOUT,
    )
    if count_resp.status_code >= 400:
        raise _error_from_response(count_resp)
    
    total = int(count_resp.headers.get("content-range", "0/0").split("/")[1])

    resp = _request(
        _client().get,
        f"{_base_url()}/rest/v1/moods",
        params=[
            *filters.items(),
            ("select", "user_id,created_at,mood,description"),
            ("order", "created_at.desc"),
            ("limit", str(limit)),
            ("offset", str(offset)),
            *conditions,
        ],
        headers=supabase_service_http(),
        timeout=TIMEOUT,
    )
    if resp.status_code >= 400:
        raise _error_from_response(resp)

    rows = resp.json()
    return rows, total


def update_mood(user_id: str, created_at: str, mood: int | None = None, description: str | None = None) -> dict | None:
    payload = {}
    if mood is not None:
        payload["mood"] = mood
    if description is not None:
        payload["description"] = description
    
    resp = _request(
        _client().patch,
        f"{_base_url()}/rest/v1/moods",
        params={
            "user_id": f"eq.{user_id}",
            "created_at": f"eq.{created_at}",
            "select": "user_id,created_at,mood,description",
        },
        headers={**supabase_service_http(), "Prefer": "return=representation"},
        json=payload,
        timeout=TIMEOUT,
    )
    if resp.status_code >= 400:
        raise _error_from_response(resp)
    rows = resp.json()
    return rows[0] if rows else None


def delete_mood(user_id: str, created_at: str) -> bool:
    resp = _request(
        _client().delete,
        f"{_base_url()}/rest/v1/moods",
        params={
            "user_id": f"eq.{user_id}",
            "created_at": f"eq.{created_at}",
        },
        headers=supabase_service_http(),
        timeout=TIMEOUT,
    )
    if resp.status_code >= 400:
        raise _error_from_response(resp)
    return resp.status_code < 300
