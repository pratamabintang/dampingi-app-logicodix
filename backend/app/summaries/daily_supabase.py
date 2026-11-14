
from datetime import datetime, timezone

from app.config import supabase_service_http
from app.supabase import (
    TIMEOUT,
    _client,
    _base_url,
    _error_from_response,
    _request,
    SupabaseError,
)


_DAILY_SUMMARY_COLUMNS = (
    "id,mother_id,summary_date,status,overview,limitations,"
    "source_refs,prompt_version,schema_version,updated_at"
)


def save_daily_summary(payload: dict) -> dict:
    payload = {
        **payload,
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }

    resp = _request(
        _client().post,
        f"{_base_url()}/rest/v1/daily_summaries",
        params={"on_conflict": "mother_id,summary_date"},
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
        raise SupabaseError(500, "No daily summary row returned after save")

    return rows[0]


def get_daily_summary(
    mother_id: str,
    summary_date: str,
) -> dict | None:
    resp = _request(
        _client().get,
        f"{_base_url()}/rest/v1/daily_summaries",
        params=[
            ("mother_id", f"eq.{mother_id}"),
            ("summary_date", f"eq.{summary_date}"),
            ("select", _DAILY_SUMMARY_COLUMNS),
            ("limit", "1"),
        ],
        headers=supabase_service_http(),
        timeout=TIMEOUT,
    )

    if resp.status_code >= 400:
        raise _error_from_response(resp)

    rows = resp.json()
    return rows[0] if rows else None
