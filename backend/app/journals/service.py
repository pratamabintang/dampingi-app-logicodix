from datetime import date, datetime, timezone, tzinfo
from typing import Optional
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from app.auth import supabase as auth_supabase
from app.journals import supabase
from app.journals.schemas import JournalOut, JournalListOut
from app.supabase import SupabaseError


class JournalInvalidDate(Exception):
    """The supplied date is malformed or not a real calendar day."""


class JournalFutureDate(Exception):
    """A Journal cannot be written for a day that has not happened yet."""


class JournalDuplicate(Exception):
    """The Author already has a Journal for that day."""

    def __init__(self, created_at: str):
        super().__init__(created_at)
        self.created_at = created_at


class JournalProfileNotFound(Exception):
    """The caller has no active Profile."""


class JournalNotFound(Exception):
    """No Journal exists for this Author on this day."""


class JournalNothingToUpdate(Exception):
    """An edit supplied neither a title nor a content."""


_UNIQUE_VIOLATION = "23505"


def _parse_date(date_str: str) -> date:
    try:
        return datetime.strptime(date_str, "%Y-%m-%d").date()
    except (ValueError, TypeError) as exc:
        raise JournalInvalidDate(
            f"Invalid date format: expected YYYY-MM-DD, got '{date_str}'"
        ) from exc


def _zone_of(profile: Optional[dict]) -> tzinfo:
    name = (profile or {}).get("timezone")
    if not name:
        return timezone.utc
    try:
        return ZoneInfo(name)
    except (ZoneInfoNotFoundError, ValueError, TypeError):
        return timezone.utc


def _today_for(profile: Optional[dict]) -> date:
    return datetime.now(_zone_of(profile)).date()


def _to_out(row: dict) -> JournalOut:
    return JournalOut(
        user_id=row["user_id"],
        created_at=row["created_at"],
        title=row["title"],
        content=row["content"],
    )


def _is_duplicate(exc: SupabaseError) -> bool:
    return exc.error_code == _UNIQUE_VIOLATION


def _require_active_profile(user_id: str) -> dict:
    profile = auth_supabase.fetch_profile(user_id)
    if not profile or profile.get("deleted_at"):
        raise JournalProfileNotFound()
    return profile


def create_journal(
    user_id: str, title: str, content: str, created_at: Optional[str] = None
) -> JournalOut:
    profile = _require_active_profile(user_id)

    if created_at is None:
        day = _today_for(profile).isoformat()
    else:
        parsed = _parse_date(created_at)
        if parsed > _today_for(profile):
            raise JournalFutureDate()
        day = parsed.isoformat()

    try:
        row = supabase.create_journal(user_id, day, title, content)
    except SupabaseError as exc:
        if _is_duplicate(exc):
            raise JournalDuplicate(day) from exc
        raise

    return _to_out(row)


def get_journal(user_id: str, created_at: str) -> JournalOut:
    day = _parse_date(created_at).isoformat()
    row = supabase.fetch_journal(user_id, day)
    if not row:
        raise JournalNotFound()
    return _to_out(row)


def update_journal(
    user_id: str,
    created_at: str,
    title: Optional[str] = None,
    content: Optional[str] = None,
) -> JournalOut:
    day = _parse_date(created_at).isoformat()

    if title is None and content is None:
        raise JournalNothingToUpdate()

    _require_active_profile(user_id)

    row = supabase.update_journal(user_id, day, title, content)
    if not row:
        raise JournalNotFound()
    return _to_out(row)


def delete_journal(user_id: str, created_at: str) -> None:
    day = _parse_date(created_at).isoformat()

    _require_active_profile(user_id)

    if not supabase.delete_journal(user_id, day):
        raise JournalNotFound()


def list_journals(
    user_id: str,
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    offset: Optional[int] = None,
    limit: Optional[int] = None,
) -> JournalListOut:
    if offset is None and limit is None:
        journals, total = supabase.list_journals_all(user_id, start_date, end_date)
        return JournalListOut(
            journals=[_to_out(row) for row in journals],
            count=len(journals),
            offset=0,
            limit=len(journals),
            total=len(journals),
        )
    
    offset = offset or 0
    limit = limit or 20
    journals, total = supabase.list_journals(user_id, start_date, end_date, offset, limit)
    return JournalListOut(
        journals=[_to_out(row) for row in journals],
        count=len(journals),
        offset=offset,
        limit=limit,
        total=total,
    )
