import secrets
from datetime import datetime, timedelta, timezone

from app.connections import supabase
from app.connections.schemas import (
    ConnectionListOut,
    ConnectionOut,
    CounterpartOut,
    InviteCodeListOut,
    InviteCodeOut,
)
from app.shared.profile import active_profile
from app.supabase import SupabaseError

ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"

CODE_LENGTH = 8

CODE_LIFETIME = timedelta(hours=1)

_MAX_CODE_ATTEMPTS = 10

_ALLOWED_TARGETS = {
    "mother": ("companion", "professional"),
    "companion": ("mother",),
    "professional": ("mother",),
}


class ConnectionProfileNotFound(Exception):
    pass


class InviteCodeMalformed(Exception):

    def __init__(self, code: str):
        super().__init__(f"Invite code is malformed: {code!r}")
        self.code = code


class InviteCodeInvalidTarget(Exception):

    def __init__(self, issuer_role: str, target_role: str):
        super().__init__(f"{issuer_role} may not invite {target_role}")
        self.issuer_role = issuer_role
        self.target_role = target_role


class InviteCodeLimitReached(Exception):

    def __init__(self, target_role: str):
        super().__init__(target_role)
        self.target_role = target_role


class ConnectionLimitReached(Exception):

    def __init__(self, target_role: str):
        super().__init__(target_role)
        self.target_role = target_role


class InviteCodeRoleMismatch(Exception):

    def __init__(self, redeemer_role: str, target_role: str):
        super().__init__(f"{redeemer_role} cannot redeem a code for {target_role}")
        self.redeemer_role = redeemer_role
        self.target_role = target_role


class InviteCodeNotFound(Exception):
    pass


class InviteCodeNotIssued(Exception):
    pass


class ConnectionNotFound(Exception):
    pass


def _normalise_code(code: str) -> str:
    raw = code.replace("-", "").upper()
    if len(raw) != CODE_LENGTH:
        raise InviteCodeMalformed(code)
    if any(ch not in ALPHABET for ch in raw):
        raise InviteCodeMalformed(code)
    return f"{raw[:4]}-{raw[4:]}"


def redeem_invite_code(user_id: str, code: str) -> dict:
    profile = _require_active_profile(user_id)
    redeemer_id = profile["user_id"]
    redeemer_role = profile["role"]

    normalised = _normalise_code(code)

    invite = supabase.fetch_invite_code(normalised)
    if not invite:
        raise InviteCodeNotFound()

    issuer_id = invite["issuer_id"]
    target_role = invite["target_role"]

    try:
        issuer_profile = _require_active_profile(issuer_id)
    except ConnectionProfileNotFound:
        raise InviteCodeNotFound()

    if redeemer_role != target_role:
        raise InviteCodeRoleMismatch(redeemer_role, target_role)

    if redeemer_role == "mother":
        mother_id = redeemer_id
        row_counterpart_id = issuer_id
        row_counterpart_role = issuer_profile["role"]
    else:
        mother_id = issuer_id
        row_counterpart_id = redeemer_id
        row_counterpart_role = redeemer_role

    if row_counterpart_role == "professional":
        if supabase.count_active_professional_connections(mother_id):
            raise ConnectionLimitReached("professional")
    elif row_counterpart_role == "companion":
        if supabase.count_active_mother_connections(row_counterpart_id):
            raise ConnectionLimitReached("mother")

    if not supabase.claim_invite_code(invite["id"], redeemer_id):
        raise InviteCodeNotFound()

    try:
        conn = supabase.create_connection(
            mother_id, row_counterpart_id, row_counterpart_role
        )
    except SupabaseError as exc:
        if supabase.is_unique_violation(exc):
            raise ConnectionLimitReached(row_counterpart_role)
        raise

    return {
        "id": conn["id"],
        "connected_at": conn["connected_at"],
        "counterpart": {
            "name": issuer_profile["name"],
            "role": issuer_profile["role"],
        },
    }



def list_invite_codes(
    user_id: str, offset: int = 0, limit: int = 100
) -> InviteCodeListOut:
    _require_active_profile(user_id)
    rows, total = supabase.list_live_invite_codes(user_id, offset, limit)
    return InviteCodeListOut(
        invite_codes=[
            InviteCodeOut(
                id=row["id"],
                code=row["code"],
                target_role=row["target_role"],
                expires_at=row["expires_at"],
            )
            for row in rows
        ],
        count=len(rows),
        offset=offset,
        limit=limit,
        total=total,
    )


def revoke_invite_code(user_id: str, code_id: str) -> None:
    _require_active_profile(user_id)
    if not supabase.revoke_invite_code(code_id, user_id):
        raise InviteCodeNotFound()


def list_connections(
    user_id: str, offset: int = 0, limit: int = 100
) -> ConnectionListOut:
    _require_active_profile(user_id)
    rows = supabase.list_active_connections(user_id)

    items = []
    for row in rows:
        if row["mother_id"] == user_id:
            counterpart = row["counterpart"]
        else:
            counterpart = row["mother"]
        if counterpart["deleted_at"]:
            continue
        items.append(
            ConnectionOut(
                id=row["id"],
                connected_at=row["connected_at"],
                counterpart=CounterpartOut(
                    name=counterpart["name"], role=counterpart["role"]
                ),
            )
        )

    page = items[offset : offset + limit]
    return ConnectionListOut(
        connections=page,
        count=len(page),
        offset=offset,
        limit=limit,
        total=len(items),
    )


def end_connection(user_id: str, connection_id: str) -> None:
    _require_active_profile(user_id)
    if not supabase.end_connection(connection_id, user_id):
        raise ConnectionNotFound()


def generate_code() -> str:
    raw = "".join(secrets.choice(ALPHABET) for _ in range(CODE_LENGTH))
    return f"{raw[:4]}-{raw[4:]}"


def _expiry_from(now: datetime) -> str:
    return (now + CODE_LIFETIME).isoformat()


def _require_active_profile(user_id: str) -> dict:
    profile = active_profile(user_id)
    if profile is None:
        raise ConnectionProfileNotFound()
    return profile


def _require_target_allowed(issuer_role: str, target_role: str) -> None:
    if target_role not in _ALLOWED_TARGETS.get(issuer_role, ()):
        raise InviteCodeInvalidTarget(issuer_role, target_role)


def _require_limit_not_reached(user_id: str, issuer_role: str, target_role: str) -> None:
    if issuer_role == "mother" and target_role == "professional":
        if supabase.count_active_professional_connections(user_id):
            raise InviteCodeLimitReached(target_role)
        return

    if issuer_role == "companion" and target_role == "mother":
        if supabase.count_active_mother_connections(user_id):
            raise InviteCodeLimitReached(target_role)


def issue_invite_code(user_id: str, target_role: str) -> InviteCodeOut:
    profile = _require_active_profile(user_id)
    issuer_role = profile["role"]

    _require_target_allowed(issuer_role, target_role)
    _require_limit_not_reached(user_id, issuer_role, target_role)

    now = datetime.now(timezone.utc)
    expires_at = _expiry_from(now)

    for _ in range(_MAX_CODE_ATTEMPTS):
        code = generate_code()
        try:
            row = supabase.create_invite_code(user_id, target_role, code, expires_at)
        except SupabaseError as exc:
            if supabase.is_unique_violation(exc):
                continue
            raise
        return InviteCodeOut(
            id=row["id"],
            code=row["code"],
            target_role=row["target_role"],
            expires_at=row["expires_at"],
        )

    raise InviteCodeNotIssued()
