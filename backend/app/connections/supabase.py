from app.config import supabase_service_http
from app.supabase import (
    TIMEOUT,
    _client,
    _base_url,
    _error_from_response,
    _request,
    _utc_now_iso,
    SupabaseError,
)

_UNIQUE_VIOLATION = "23505"

_PAGE_SIZE = 1000
_MAX_PAGES = 200


def create_invite_code(
    issuer_id: str, target_role: str, code: str, expires_at: str
) -> dict:
    resp = _request(
        _client().post,
        f"{_base_url()}/rest/v1/invite_codes",
        headers={**supabase_service_http(), "Prefer": "return=representation"},
        json={
            "issuer_id": issuer_id,
            "target_role": target_role,
            "code": code,
            "expires_at": expires_at,
        },
        timeout=TIMEOUT,
    )
    if resp.status_code >= 400:
        raise _error_from_response(resp)
    rows = resp.json()
    if not rows:
        raise SupabaseError(500, "No row returned after insert")
    return rows[0]


def count_active_professional_connections(mother_id: str) -> int:
    resp = _request(
        _client().get,
        f"{_base_url()}/rest/v1/connections",
        params={
            "mother_id": f"eq.{mother_id}",
            "counterpart_role": "eq.professional",
            "ended_at": "is.null",
            "select": "id",
        },
        headers=supabase_service_http(),
        timeout=TIMEOUT,
    )
    if resp.status_code >= 400:
        raise _error_from_response(resp)
    return len(resp.json())


def count_active_mother_connections(counterpart_id: str) -> int:
    resp = _request(
        _client().get,
        f"{_base_url()}/rest/v1/connections",
        params={
            "counterpart_id": f"eq.{counterpart_id}",
            "counterpart_role": "eq.companion",
            "ended_at": "is.null",
            "select": "id",
        },
        headers=supabase_service_http(),
        timeout=TIMEOUT,
    )
    if resp.status_code >= 400:
        raise _error_from_response(resp)
    return len(resp.json())


def fetch_invite_code(code: str) -> dict | None:
    resp = _request(
        _client().get,
        f"{_base_url()}/rest/v1/invite_codes",
        params={
            "code": f"eq.{code}",
            "redeemed_at": "is.null",
            "revoked_at": "is.null",
            "expires_at": f"gt.{_utc_now_iso()}",
            "select": "id,issuer_id,target_role",
        },
        headers=supabase_service_http(),
        timeout=TIMEOUT,
    )
    if resp.status_code >= 400:
        raise _error_from_response(resp)
    rows = resp.json()
    return rows[0] if rows else None


def list_live_invite_codes(
    issuer_id: str, offset: int = 0, limit: int = 100
) -> tuple[list, int]:
    filters = {
        "issuer_id": f"eq.{issuer_id}",
        "redeemed_at": "is.null",
        "revoked_at": "is.null",
        "expires_at": f"gt.{_utc_now_iso()}",
    }

    count_resp = _request(
        _client().get,
        f"{_base_url()}/rest/v1/invite_codes",
        params=[*filters.items(), ("select", "count")],
        headers={**supabase_service_http(), "Prefer": "count=exact"},
        timeout=TIMEOUT,
    )
    if count_resp.status_code >= 400:
        raise _error_from_response(count_resp)
    total = int(count_resp.headers.get("content-range", "0/0").split("/")[1])

    resp = _request(
        _client().get,
        f"{_base_url()}/rest/v1/invite_codes",
        params=[
            *filters.items(),
            ("select", "id,code,target_role,expires_at"),
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


def revoke_invite_code(id: str, issuer_id: str) -> bool:
    resp = _request(
        _client().patch,
        f"{_base_url()}/rest/v1/invite_codes",
        params={
            "id": f"eq.{id}",
            "issuer_id": f"eq.{issuer_id}",
            "redeemed_at": "is.null",
            "revoked_at": "is.null",
            "expires_at": f"gt.{_utc_now_iso()}",
        },
        headers={
            **supabase_service_http(),
            "Prefer": "return=representation",
        },
        json={"revoked_at": _utc_now_iso()},
        timeout=TIMEOUT,
    )
    if resp.status_code >= 400:
        raise _error_from_response(resp)
    return len(resp.json()) == 1


def claim_invite_code(id: str, redeemer_id: str) -> bool:
    resp = _request(
        _client().patch,
        f"{_base_url()}/rest/v1/invite_codes",
        params={
            "id": f"eq.{id}",
            "redeemed_at": "is.null",
            "revoked_at": "is.null",
            "expires_at": f"gt.{_utc_now_iso()}",
        },
        headers={
            **supabase_service_http(),
            "Prefer": "return=representation",
        },
        json={
            "redeemed_at": _utc_now_iso(),
            "redeemed_by": redeemer_id,
        },
        timeout=TIMEOUT,
    )
    if resp.status_code >= 400:
        raise _error_from_response(resp)
    return len(resp.json()) == 1


def create_connection(
    mother_id: str, counterpart_id: str, counterpart_role: str
) -> dict:
    resp = _request(
        _client().post,
        f"{_base_url()}/rest/v1/connections",
        headers={**supabase_service_http(), "Prefer": "return=representation"},
        json={
            "mother_id": mother_id,
            "counterpart_id": counterpart_id,
            "counterpart_role": counterpart_role,
        },
        timeout=TIMEOUT,
    )
    if resp.status_code >= 400:
        raise _error_from_response(resp)
    rows = resp.json()
    if not rows:
        raise SupabaseError(500, "No row returned after insert")
    return rows[0]


def list_active_connections(user_id: str) -> list:
    scope = f"(mother_id.eq.{user_id},counterpart_id.eq.{user_id})"
    columns = (
        "id,connected_at,mother_id,counterpart_id,"
        "mother:profiles!mother_id(name,role,deleted_at),"
        "counterpart:profiles!counterpart_id(name,role,deleted_at)"
    )
    collected: list = []
    offset = 0

    for _ in range(_MAX_PAGES):
        resp = _request(
            _client().get,
            f"{_base_url()}/rest/v1/connections",
            params=[
                ("select", columns),
                ("order", "connected_at.desc"),
                ("limit", str(_PAGE_SIZE)),
                ("offset", str(offset)),
                ("or", scope),
                ("ended_at", "is.null"),
            ],
            headers=supabase_service_http(),
            timeout=TIMEOUT,
        )
        if resp.status_code >= 400:
            raise _error_from_response(resp)
        rows = resp.json()
        collected.extend(rows)
        if len(rows) < _PAGE_SIZE:
            return collected
        offset += len(rows)

    raise SupabaseError(
        500,
        f"Listing connections did not terminate after {_MAX_PAGES} pages; "
        "the upstream appears to be ignoring the offset parameter",
    )


def fetch_professional_connection_for_mother(
    mother_id: str, connection_id: str
) -> dict | None:
    return _fetch_professional_connection(
        connection_id=connection_id,
        mother_id=mother_id,
    )


def fetch_active_professional_connection(
    professional_id: str, connection_id: str
) -> dict | None:
    return _fetch_professional_connection(
        connection_id=connection_id,
        professional_id=professional_id,
    )


def _fetch_professional_connection(
    *,
    connection_id: str,
    mother_id: str | None = None,
    professional_id: str | None = None,
) -> dict | None:
    params = [
        ("id", f"eq.{connection_id}"),
        ("counterpart_role", "eq.professional"),
        ("ended_at", "is.null"),
        (
            "select",
            "id,mother_id,counterpart_id,share_weekly_summary,share_epds,"
            "share_journal,mother:profiles!mother_id(name)",
        ),
        ("limit", "1"),
    ]
    if mother_id is not None:
        params.append(("mother_id", f"eq.{mother_id}"))
    if professional_id is not None:
        params.append(("counterpart_id", f"eq.{professional_id}"))

    resp = _request(
        _client().get,
        f"{_base_url()}/rest/v1/connections",
        params=params,
        headers=supabase_service_http(),
        timeout=TIMEOUT,
    )
    if resp.status_code >= 400:
        raise _error_from_response(resp)
    rows = resp.json()
    return rows[0] if rows else None


def update_professional_sharing_permissions(
    mother_id: str,
    connection_id: str,
    permissions: dict[str, bool],
) -> dict | None:
    resp = _request(
        _client().patch,
        f"{_base_url()}/rest/v1/connections",
        params=[
            ("id", f"eq.{connection_id}"),
            ("mother_id", f"eq.{mother_id}"),
            ("counterpart_role", "eq.professional"),
            ("ended_at", "is.null"),
            (
                "select",
                "id,mother_id,counterpart_id,share_weekly_summary,"
                "share_epds,share_journal",
            ),
        ],
        headers={
            **supabase_service_http(),
            "Prefer": "return=representation",
        },
        json=permissions,
        timeout=TIMEOUT,
    )
    if resp.status_code >= 400:
        raise _error_from_response(resp)
    rows = resp.json()
    return rows[0] if rows else None


def end_connection(id: str, user_id: str) -> bool:
    resp = _request(
        _client().patch,
        f"{_base_url()}/rest/v1/connections",
        params={
            "id": f"eq.{id}",
            "or": f"(mother_id.eq.{user_id},counterpart_id.eq.{user_id})",
            "ended_at": "is.null",
        },
        headers={
            **supabase_service_http(),
            "Prefer": "return=representation",
        },
        json={
            "ended_at": _utc_now_iso(),
            "ended_by": user_id,
        },
        timeout=TIMEOUT,
    )
    if resp.status_code >= 400:
        raise _error_from_response(resp)
    return len(resp.json()) == 1


def end_active_connections(user_id: str) -> None:
    resp = _request(
        _client().patch,
        f"{_base_url()}/rest/v1/connections",
        params={
            "or": f"(mother_id.eq.{user_id},counterpart_id.eq.{user_id})",
            "ended_at": "is.null",
        },
        headers={
            **supabase_service_http(),
            "Prefer": "return=minimal",
        },
        json={
            "ended_at": _utc_now_iso(),
            "ended_by": user_id,
        },
        timeout=TIMEOUT,
    )
    if resp.status_code >= 400:
        raise _error_from_response(resp)


def is_unique_violation(exc: SupabaseError) -> bool:
    return exc.error_code == _UNIQUE_VIOLATION
