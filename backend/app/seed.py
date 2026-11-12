"""Seed script for local development.

Creates deterministic test content for every table, via the real signup
path for Profiles and the service-key REST endpoints for their rows. The
script is idempotent: running it twice merges the same rows and reports no
new Profiles.

    python -m app.seed

Profiles go through `supabase.signup()`, so the auth trigger, role
validation, and metadata flow are exercised exactly as production does
(only `profiles` is never written directly). Every child row carries a
UUID derived from a fixed name (`uuid.uuid5`), so re-running upserts the
same rows instead of duplicating them — including rows for the two extra
Profiles that exist only to make the multi-patient and replacement-
Professional cases real.

If a signup fails, the script halts with a clear error message and does
NOT silently skip (a wrongly-labelled role is worse than a failed signup).
Cleanup is manual: run `python -m app.admin purge` if needed.
"""

import sys
import uuid
from datetime import date, datetime, time, timedelta, timezone
from typing import Dict, List, Optional

from app.auth import supabase as auth_supabase
from app.config import get_settings, supabase_service_http
from app.supabase import (
    TIMEOUT,
    _base_url,
    _client,
    _error_from_response,
    _request,
    SupabaseError,
)

# Profiles. `key` names the Profile for the domain rows below; `delete`
# marks the tombstoned Mother whose banned-identity path is under test.
SEED_PROFILES = [
    {"key": "mother", "name": "Mother", "email": "seed.mother@gmail.com", "role": "mother"},
    {"key": "companion", "name": "Companion", "email": "seed.companion@gmail.com", "role": "companion"},
    {
        "key": "professional",
        "name": "Professional",
        "email": "seed.professional@gmail.com",
        "role": "professional",
    },
    {
        "key": "deleted_mother",
        "name": "Deleted Mother",
        "email": "seed.deleted.mother@gmail.com",
        "role": "mother",
        "delete": True,
    },
    # A second Mother and a second Professional: without them the
    # multi-patient caseload read and the replacement-Professional history
    # have nothing to read.
    {
        "key": "mother2",
        "name": "Second Mother",
        "email": "seed.mother2@gmail.com",
        "role": "mother",
    },
    {
        "key": "professional2",
        "name": "Second Professional",
        "email": "seed.professional2@gmail.com",
        "role": "professional",
    },
]

SEED_PASSWORD = "Seed!123"

# One namespace keeps every derived UUID stable across runs and machines.
SEED_NAMESPACE = uuid.uuid5(uuid.NAMESPACE_DNS, "seed.dampingi.local")

QUESTIONS = [
    {
        "id": "q1",
        "prompt": "How did today feel?",
        "options": [
            {"id": "q1o1", "label": "Calm"},
            {"id": "q1o2", "label": "Tense"},
        ],
    },
    {
        "id": "q2",
        "prompt": "Did you sleep well?",
        "options": [
            {"id": "q2o1", "label": "Yes"},
            {"id": "q2o2", "label": "No"},
        ],
    },
]

ANSWERS = [
    {"question_id": "q1", "option_id": "q1o1"},
    {"question_id": "q2", "option_id": "q2o2"},
]


def is_seed_email(email: str) -> bool:
    """True if the email is one of the deterministic seed emails."""
    return email.startswith("seed.") and email.endswith("@gmail.com")


def seed_id(name: str) -> str:
    """The stable UUID a named seed row is keyed by."""
    return str(uuid.uuid5(SEED_NAMESPACE, name))


def find_existing_seed_users() -> dict:
    """Find any existing seed users (by admin API).

    Returns a dict: {email: user_id} for users matching seed.*@gmail.com.
    """
    existing = {}
    try:
        page = 1
        while True:
            batch, next_page, _total = auth_supabase.admin_list_users(page=page)
            for user in batch:
                email = user.get("email")
                if email and is_seed_email(email):
                    existing[email] = user.get("id")
            if not next_page:
                break
            page = next_page
    except auth_supabase.SupabaseError as exc:
        raise SystemExit(
            f"Failed to list users: {exc.message} (code={exc.error_code})"
        ) from exc
    return existing


def seed_one(
    name: str, email: str, role: str, delete: bool = False, existing: Optional[dict] = None
) -> dict:
    """Create or skip one seed Profile.

    Returns {email, user_id, created, message}.
    - If the user exists, skips creation.
    - If delete=True, bans and tombstones after creation.
    """
    if existing is None:
        existing = find_existing_seed_users()
    if email in existing:
        return {
            "email": email,
            "user_id": existing[email],
            "created": False,
            "message": "already exists",
        }

    try:
        resp = auth_supabase.signup(
            name=name, email=email, password=SEED_PASSWORD, role=role
        )
        user_id = resp.get("user", {}).get("id")
        if not user_id:
            raise auth_supabase.SupabaseError(
                400, f"Signup returned no user ID for {email}"
            )

        if delete:
            try:
                auth_supabase.ban_user(user_id)
                auth_supabase.tombstone_profile(user_id)
                message = "created and soft-deleted"
            except auth_supabase.SupabaseError as exc:
                raise auth_supabase.SupabaseError(
                    exc.status,
                    f"Failed to soft-delete {email}: {exc.message}",
                    exc.error_code,
                ) from exc
        else:
            message = "created"

        return {"email": email, "user_id": user_id, "created": True, "message": message}

    except auth_supabase.SupabaseError as exc:
        raise SystemExit(
            f"Signup failed for {email} (role={role}): {exc.message} "
            f"(code={exc.error_code})"
        ) from exc


def upsert(table: str, rows: List[dict]) -> None:
    """Upsert rows by primary key, so a re-run merges instead of duplicating.

    Uses the service key: RLS is closed to the public roles (ADR-0016), so
    the seeder talks to PostgREST the way the app's own transports do.
    """
    if not rows:
        return
    resp = _request(
        _client().post,
        f"{_base_url()}/rest/v1/{table}",
        params={"on_conflict": "id"},
        headers={
            **supabase_service_http(),
            "Prefer": "resolution=merge-duplicates,return=representation",
        },
        json=rows,
        timeout=TIMEOUT,
    )
    if resp.status_code >= 400:
        raise _error_from_response(resp)


def _rows() -> Dict[str, List[dict]]:
    """Every domain row, keyed by table, dates relative to today.

    Dates are relative so "today" is always a valid (non-future) day and
    the day-scoped reads have something recent to return.
    """
    now = datetime.now(timezone.utc)
    today = now.date()

    def day(days_ago: int) -> str:
        return (today - timedelta(days=days_ago)).isoformat()

    def ts(days_ago: int, hour: int = 9) -> str:
        return datetime.combine(
            today - timedelta(days=days_ago), time(hour=hour), tzinfo=timezone.utc
        ).isoformat()

    def hours_ago(hours: float) -> str:
        return (now - timedelta(hours=hours)).isoformat()

    def hours_ahead(hours: float) -> str:
        return (now + timedelta(hours=hours)).isoformat()

    conn_m1_c1 = seed_id("connection.mother1.companion1")
    conn_m1_p1 = seed_id("connection.mother1.professional1")
    conn_m1_p2 = seed_id("connection.mother1.professional2")
    conn_m2_p1 = seed_id("connection.mother2.professional1")

    connections = [
        {
            "id": conn_m1_c1,
            "mother_id": "mother",
            "counterpart_id": "companion",
            "counterpart_role": "companion",
            "connected_at": ts(20),
            "ended_at": None,
            "ended_by": None,
        },
        {
            "id": conn_m1_p1,
            "mother_id": "mother",
            "counterpart_id": "professional",
            "counterpart_role": "professional",
            "connected_at": ts(18),
            "ended_at": None,
            "ended_by": None,
        },
        # The replaced Professional: ended, so the slot is free and the
        # history has a second episode to look back at.
        {
            "id": conn_m1_p2,
            "mother_id": "mother",
            "counterpart_id": "professional2",
            "counterpart_role": "professional",
            "connected_at": ts(30),
            "ended_at": ts(20),
            "ended_by": "mother",
        },
        # Same Professional, another Mother: the caseload case.
        {
            "id": conn_m2_p1,
            "mother_id": "mother2",
            "counterpart_id": "professional",
            "counterpart_role": "professional",
            "connected_at": ts(10),
            "ended_at": None,
            "ended_by": None,
        },
    ]

    invite_codes = [
        {
            "id": seed_id("invite_code.companion.live"),
            "issuer_id": "mother",
            "target_role": "companion",
            "code": "SEED-CMPN",
            "created_at": hours_ago(0.5),
            "expires_at": hours_ahead(0.5),
            "redeemed_at": None,
            "redeemed_by": None,
            "revoked_at": None,
        },
        {
            "id": seed_id("invite_code.professional.live"),
            "issuer_id": "mother",
            "target_role": "professional",
            "code": "SEED-PRFN",
            "created_at": hours_ago(0.5),
            "expires_at": hours_ahead(0.5),
            "redeemed_at": None,
            "redeemed_by": None,
            "revoked_at": None,
        },
        {
            "id": seed_id("invite_code.mother.live"),
            "issuer_id": "mother",
            "target_role": "mother",
            "code": "SEED-MTHR",
            "created_at": hours_ago(0.5),
            "expires_at": hours_ahead(0.5),
            "redeemed_at": None,
            "redeemed_by": None,
            "revoked_at": None,
        },
        # Born before it expired, so the `expires_at > created_at` check holds.
        {
            "id": seed_id("invite_code.expired"),
            "issuer_id": "mother",
            "target_role": "companion",
            "code": "SEED-EXPD",
            "created_at": hours_ago(2),
            "expires_at": hours_ago(1),
            "redeemed_at": None,
            "redeemed_by": None,
            "revoked_at": None,
        },
        {
            "id": seed_id("invite_code.revoked"),
            "issuer_id": "mother",
            "target_role": "companion",
            "code": "SEED-RVKD",
            "created_at": hours_ago(0.5),
            "expires_at": hours_ahead(0.5),
            "redeemed_at": None,
            "redeemed_by": None,
            "revoked_at": hours_ago(0.2),
        },
        {
            "id": seed_id("invite_code.redeemed"),
            "issuer_id": "mother",
            "target_role": "companion",
            "code": "SEED-RDMD",
            "created_at": hours_ago(0.5),
            "expires_at": hours_ahead(0.5),
            "redeemed_at": hours_ago(0.2),
            "redeemed_by": "companion",
            "revoked_at": None,
        },
    ]

    moods = [
        {
            "id": seed_id("mood.mother.today"),
            "user_id": "mother",
            "created_at": day(0),
            "mood": 4,
            "description": "Steady",
        },
        {
            "id": seed_id("mood.mother.yesterday"),
            "user_id": "mother",
            "created_at": day(1),
            "mood": 3,
            "description": None,
        },
        {
            "id": seed_id("mood.mother.six_days_ago"),
            "user_id": "mother",
            "created_at": day(6),
            "mood": 2,
            "description": None,
        },
        {
            "id": seed_id("mood.mother2.today"),
            "user_id": "mother2",
            "created_at": day(0),
            "mood": 5,
            "description": "Good day",
        },
    ]

    journals = [
        {
            "id": seed_id("journal.mother.today"),
            "user_id": "mother",
            "created_at": day(0),
            "title": "Morning pages",
            "content": "Slept better; the morning walk helped.",
        },
        {
            "id": seed_id("journal.mother.three_days_ago"),
            "user_id": "mother",
            "created_at": day(3),
            "title": "Hard afternoon",
            "content": "Tired by three, but the call with my companion helped.",
        },
        {
            "id": seed_id("journal.companion.today"),
            "user_id": "companion",
            "created_at": day(0),
            "title": "Notes",
            "content": "Reading list for the week.",
        },
    ]

    observations = [
        # A draft: no day yet, so it does not occupy the Connection's day.
        {
            "id": seed_id("observation.mother1.companion1.draft"),
            "connection_id": conn_m1_c1,
            "questions": QUESTIONS,
            "answers": None,
            "day": None,
            "created_at": hours_ago(2),
            "completed_at": None,
        },
        {
            "id": seed_id("observation.mother1.companion1.completed"),
            "connection_id": conn_m1_c1,
            "questions": QUESTIONS,
            "answers": ANSWERS,
            "day": day(2),
            "created_at": ts(3),
            "completed_at": ts(2),
        },
    ]

    professional_notes = [
        {
            "id": seed_id("professional_note.connection1.active"),
            "connection_id": conn_m1_p1,
            "content": "Reports better sleep; continue weekly check-ins.",
            "created_at": ts(5),
            "deleted_at": None,
        },
        # Soft-deleted (ADR-0014): kept, stamped, excluded from reads.
        {
            "id": seed_id("professional_note.connection1.deleted"),
            "connection_id": conn_m1_p1,
            "content": "Superseded note, kept for history.",
            "created_at": ts(9),
            "deleted_at": ts(8),
        },
        {
            "id": seed_id("professional_note.connection2.active"),
            "connection_id": conn_m2_p1,
            "content": "First session held; goals set for the month.",
            "created_at": ts(4),
            "deleted_at": None,
        },
    ]

    # `profiles` is deliberately absent: signup's trigger owns it.
    return {
        "connections": connections,
        "invite_codes": invite_codes,
        "moods": moods,
        "journals": journals,
        "observations": observations,
        "professional_notes": professional_notes,
    }


def _resolve_ids(rows: Dict[str, List[dict]], ids: Dict[str, str]) -> Dict[str, List[dict]]:
    """Replace Profile placeholder keys ("mother") with their real UUIDs.

    Child rows are authored with readable placeholders because the ids are
    only known after signup; this is the one place that translation happens.
    """
    profile_columns = {
        "connections": ("mother_id", "counterpart_id", "ended_by"),
        "invite_codes": ("issuer_id", "redeemed_by"),
        "moods": ("user_id",),
        "journals": ("user_id",),
        "professional_notes": (),
    }
    resolved: Dict[str, List[dict]] = {}
    for table, table_rows in rows.items():
        columns = profile_columns.get(table, ())
        fixed = []
        for row in table_rows:
            row = dict(row)
            for column in columns:
                value = row.get(column)
                if value in ids:
                    row[column] = ids[value]
            fixed.append(row)
        resolved[table] = fixed
    return resolved


def seed_domain(ids: Dict[str, str]) -> Dict[str, int]:
    """Upsert every non-Profile row, in foreign-key order.

    Returns {table: row count}.
    """
    rows = _resolve_ids(_rows(), ids)
    counts: Dict[str, int] = {}
    for table, table_rows in rows.items():
        upsert(table, table_rows)
        counts[table] = len(table_rows)
    return counts


def main(argv: Optional[List[str]] = None) -> int:
    """Seed the database with test Profiles and their rows."""
    try:
        settings = get_settings()
    except SystemExit as exc:
        raise SystemExit(f"Configuration error: {exc}") from exc

    print(f"Seeding {settings.supabase_url}...")
    print()

    existing = find_existing_seed_users()
    results = []
    ids: Dict[str, str] = {}
    for profile in SEED_PROFILES:
        result = seed_one(
            name=profile["name"],
            email=profile["email"],
            role=profile["role"],
            delete=profile.get("delete", False),
            existing=existing,
        )
        results.append(result)
        if result["user_id"]:
            ids[profile["key"]] = result["user_id"]
        print(f"  {result['email']:<35} {result['message']}")

    missing = [p["key"] for p in SEED_PROFILES if p["key"] not in ids]
    if missing:
        raise SystemExit(f"Seed Profiles without an id: {missing}")

    try:
        counts = seed_domain(ids)
    except SupabaseError as exc:
        raise SystemExit(
            f"Failed to seed domain rows: {exc.message} (code={exc.error_code})"
        ) from exc

    print()
    for table, count in counts.items():
        print(f"  {table:<20} {count} row(s) seeded")
    print()

    created = sum(1 for r in results if r["created"])
    print(f"Done. Created {created} new profile(s).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
