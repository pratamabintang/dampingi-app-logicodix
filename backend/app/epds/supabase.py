
from app.config import supabase_service_http
from app.supabase import (
    TIMEOUT,
    _client,
    _base_url,
    _error_from_response,
    _request,
    SupabaseError,
)


_ASSESSMENT_COLUMNS = (
    "id,mother_id,instrument,instrument_version,evaluation_mode,"
    "answers,total_score,follow_up_required,item10_positive,"
    "immediate_review_required,rules_version,disclaimer,created_at"
)

_ALERT_COLUMNS = (
    "id,mother_id,assessment_id,alert_type,evaluation_mode,"
    "message,created_at,read_at"
)


def create_assessment(payload: dict) -> dict:
    resp = _request(
        _client().post,
        f"{_base_url()}/rest/v1/epds_assessments",
        headers={
            **supabase_service_http(),
            "Prefer": "return=representation",
        },
        json=payload,
        timeout=TIMEOUT,
    )

    if resp.status_code >= 400:
        raise _error_from_response(resp)

    rows = resp.json()
    if not rows:
        raise SupabaseError(500, "No assessment row returned after insert")

    return rows[0]


def list_assessments(
    mother_id: str,
    offset: int = 0,
    limit: int = 20,
) -> tuple[list, int]:
    count_resp = _request(
        _client().get,
        f"{_base_url()}/rest/v1/epds_assessments",
        params=[
            ("mother_id", f"eq.{mother_id}"),
            ("select", "count"),
        ],
        headers={
            **supabase_service_http(),
            "Prefer": "count=exact",
        },
        timeout=TIMEOUT,
    )

    if count_resp.status_code >= 400:
        raise _error_from_response(count_resp)

    content_range = count_resp.headers.get("content-range", "*/0")
    total = int(content_range.split("/")[-1])

    resp = _request(
        _client().get,
        f"{_base_url()}/rest/v1/epds_assessments",
        params=[
            ("mother_id", f"eq.{mother_id}"),
            ("select", _ASSESSMENT_COLUMNS),
            ("order", "created_at.desc"),
            ("limit", str(limit)),
            ("offset", str(offset)),
        ],
        headers=supabase_service_http(),
        timeout=TIMEOUT,
    )

    if resp.status_code >= 400:
        raise _error_from_response(resp)

    return resp.json(), total


def create_alert(payload: dict) -> dict:
    resp = _request(
        _client().post,
        f"{_base_url()}/rest/v1/alerts",
        headers={
            **supabase_service_http(),
            "Prefer": "return=representation",
        },
        json=payload,
        timeout=TIMEOUT,
    )

    if resp.status_code >= 400:
        raise _error_from_response(resp)

    rows = resp.json()
    if not rows:
        raise SupabaseError(500, "No alert row returned after insert")

    return rows[0]


def list_alerts(
    mother_id: str,
    offset: int = 0,
    limit: int = 20,
) -> tuple[list, int]:
    count_resp = _request(
        _client().get,
        f"{_base_url()}/rest/v1/alerts",
        params=[
            ("mother_id", f"eq.{mother_id}"),
            ("select", "count"),
        ],
        headers={
            **supabase_service_http(),
            "Prefer": "count=exact",
        },
        timeout=TIMEOUT,
    )

    if count_resp.status_code >= 400:
        raise _error_from_response(count_resp)

    content_range = count_resp.headers.get("content-range", "*/0")
    total = int(content_range.split("/")[-1])

    resp = _request(
        _client().get,
        f"{_base_url()}/rest/v1/alerts",
        params=[
            ("mother_id", f"eq.{mother_id}"),
            ("select", _ALERT_COLUMNS),
            ("order", "created_at.desc"),
            ("limit", str(limit)),
            ("offset", str(offset)),
        ],
        headers=supabase_service_http(),
        timeout=TIMEOUT,
    )

    if resp.status_code >= 400:
        raise _error_from_response(resp)

    return resp.json(), total


def mark_alert_read(
    mother_id: str,
    alert_id: str,
    read_at: str,
) -> dict | None:
    resp = _request(
        _client().patch,
        f"{_base_url()}/rest/v1/alerts",
        params=[
            ("id", f"eq.{alert_id}"),
            ("mother_id", f"eq.{mother_id}"),
            ("select", _ALERT_COLUMNS),
        ],
        headers={
            **supabase_service_http(),
            "Prefer": "return=representation",
        },
        json={"read_at": read_at},
        timeout=TIMEOUT,
    )

    if resp.status_code >= 400:
        raise _error_from_response(resp)

    rows = resp.json()
    return rows[0] if rows else None
