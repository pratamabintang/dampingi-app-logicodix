from app.config import supabase_service_http
from app.supabase import (
    TIMEOUT,
    _client,
    _base_url,
    _error_from_response,
    _request,
    SupabaseError,
)

_COLUMNS = "user_id,created_at,title,content"


def create_journal(user_id: str, created_at: str, title: str, content: str) -> dict:
    resp = _request(
        _client().post,
        f"{_base_url()}/rest/v1/journals",
        headers={**supabase_service_http(), "Prefer": "return=representation"},
        json={
            "user_id": user_id,
            "created_at": created_at,
            "title": title,
            "content": content,
        },
        timeout=TIMEOUT,
    )
    if resp.status_code >= 400:
        raise _error_from_response(resp)
    rows = resp.json()
    if not rows:
        raise SupabaseError(500, "No row returned after insert")
    return rows[0]


def fetch_journal(user_id: str, created_at: str) -> dict | None:
    resp = _request(
        _client().get,
        f"{_base_url()}/rest/v1/journals",
        params={
            "user_id": f"eq.{user_id}",
            "created_at": f"eq.{created_at}",
            "select": _COLUMNS,
        },
        headers=supabase_service_http(),
        timeout=TIMEOUT,
    )
    if resp.status_code >= 400:
        raise _error_from_response(resp)
    rows = resp.json()
    return rows[0] if rows else None


def update_journal(
    user_id: str,
    created_at: str,
    title: str | None = None,
    content: str | None = None,
) -> dict | None:
    payload = {}
    if title is not None:
        payload["title"] = title
    if content is not None:
        payload["content"] = content

    resp = _request(
        _client().patch,
        f"{_base_url()}/rest/v1/journals",
        params={
            "user_id": f"eq.{user_id}",
            "created_at": f"eq.{created_at}",
            "select": _COLUMNS,
        },
        headers={**supabase_service_http(), "Prefer": "return=representation"},
        json=payload,
        timeout=TIMEOUT,
    )
    if resp.status_code >= 400:
        raise _error_from_response(resp)
    rows = resp.json()
    return rows[0] if rows else None


def delete_journal(user_id: str, created_at: str) -> bool:
    resp = _request(
        _client().delete,
        f"{_base_url()}/rest/v1/journals",
        params={
            "user_id": f"eq.{user_id}",
            "created_at": f"eq.{created_at}",
            "select": _COLUMNS,
        },
        headers={**supabase_service_http(), "Prefer": "return=representation"},
        timeout=TIMEOUT,
    )
    if resp.status_code >= 400:
        raise _error_from_response(resp)
    rows = resp.json()
    return bool(rows)


_PAGE_SIZE = 1000
_MAX_PAGES = 200


def list_journals_all(
    user_id: str,
    start_date: str | None = None,
    end_date: str | None = None,
) -> tuple[list[dict], int]:
    filters = {"user_id": f"eq.{user_id}"}
    conditions: list[tuple[str, str]] = []
    if start_date:
        conditions.append(("created_at", f"gte.{start_date}"))
    if end_date:
        conditions.append(("created_at", f"lte.{end_date}"))

    collected: list[dict] = []
    offset = 0

    for _ in range(_MAX_PAGES):
        resp = _request(
            _client().get,
            f"{_base_url()}/rest/v1/journals",
            params=[
                *filters.items(),
                ("select", _COLUMNS),
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
        f"Listing journals did not terminate after {_MAX_PAGES} pages; "
        "the upstream appears to be ignoring the offset parameter",
    )



def list_journals(
    user_id: str,
    start_date: str | None = None,
    end_date: str | None = None,
    offset: int = 0,
    limit: int = 20,
) -> tuple[list[dict], int]:
    filters = {"user_id": f"eq.{user_id}"}
    conditions: list[tuple[str, str]] = []
    if start_date:
        conditions.append(("created_at", f"gte.{start_date}"))
    if end_date:
        conditions.append(("created_at", f"lte.{end_date}"))

    count_resp = _request(
        _client().get,
        f"{_base_url()}/rest/v1/journals",
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
        f"{_base_url()}/rest/v1/journals",
        params=[
            *filters.items(),
            ("select", _COLUMNS),
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