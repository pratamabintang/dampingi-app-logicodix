from app.config import supabase_service_http
from app.supabase import (
    TIMEOUT,
    _client,
    _base_url,
    _error_from_response,
    _request,
    SupabaseError,
)


_SUMMARY_COLUMNS = (
    "id,mother_id,period_start,period_end,audience,status,"
    "overview,limitations,source_refs,prompt_version,"
    "schema_version,created_at"
)


def save_summary(payload: dict) -> dict:
    resp = _request(
        _client().post,
        f"{_base_url()}/rest/v1/weekly_summaries",
        params={
            "on_conflict": "mother_id,period_start,audience",
        },
        headers={
            **supabase_service_http(),
            "Prefer": "resolution=merge-duplicates,return=representation",
        },
        json=payload,
        timeout=TIMEOUT,
    )

    if resp.status_code >= 400:
        raise _error_from_response(resp)

    rows = resp.json()
    if not rows:
        raise SupabaseError(500, "No summary row returned after save")

    return rows[0]


def get_summary(
    mother_id: str,
    period_start: str,
    audience: str,
) -> dict | None:
    resp = _request(
        _client().get,
        f"{_base_url()}/rest/v1/weekly_summaries",
        params=[
            ("mother_id", f"eq.{mother_id}"),
            ("period_start", f"eq.{period_start}"),
            ("audience", f"eq.{audience}"),
            ("select", _SUMMARY_COLUMNS),
            ("limit", "1"),
        ],
        headers=supabase_service_http(),
        timeout=TIMEOUT,
    )

    if resp.status_code >= 400:
        raise _error_from_response(resp)

    rows = resp.json()
    return rows[0] if rows else None