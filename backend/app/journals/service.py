from typing import Optional

from app.journals import supabase
from app.journals.schemas import JournalOut, JournalListOut
from app.shared.day import parse_day, today_for
from app.shared.profile import active_profile
from app.supabase import SupabaseError


class JournalInvalidDate(Exception):
    pass


class JournalFutureDate(Exception):
    pass


class JournalDuplicate(Exception):

    def __init__(self, created_at: str):
        super().__init__(created_at)
        self.created_at = created_at


class JournalProfileNotFound(Exception):
    pass


class JournalNotFound(Exception):
    pass


class JournalNothingToUpdate(Exception):
    pass


_UNIQUE_VIOLATION = "23505"


def _to_out(row: dict) -> JournalOut:
    return JournalOut(
        id=row["id"],
        user_id=row["user_id"],
        created_at=row["created_at"],
        title=row["title"],
        content=row["content"],
    )


def _is_duplicate(exc: SupabaseError) -> bool:
    return exc.error_code == _UNIQUE_VIOLATION


def _require_active_profile(user_id: str) -> dict:
    profile = active_profile(user_id)
    if profile is None:
        raise JournalProfileNotFound()
    return profile


def create_journal(
    user_id: str, title: str, content: str, created_at: Optional[str] = None
) -> JournalOut:
    profile = _require_active_profile(user_id)
    today = today_for(profile)

    if created_at is None:
        day = today.isoformat()
    else:
        try:
            parsed = parse_day(created_at)
        except (ValueError, TypeError) as exc:
            raise JournalInvalidDate(
                f"Invalid date format: expected YYYY-MM-DD, got '{created_at}'"
            ) from exc
        if parsed > today:
            raise JournalFutureDate()
        day = parsed.isoformat()

    try:
        row = supabase.create_journal(user_id, day, title, content)
    except SupabaseError as exc:
        if _is_duplicate(exc):
            raise JournalDuplicate(day) from exc
        raise

    return _to_out(row)


def get_journal(user_id: str, journal_id: str) -> JournalOut:
    row = supabase.fetch_journal(user_id, journal_id)
    if not row:
        raise JournalNotFound()
    return _to_out(row)


def update_journal(
    user_id: str,
    journal_id: str,
    title: Optional[str] = None,
    content: Optional[str] = None,
) -> JournalOut:
    if title is None and content is None:
        raise JournalNothingToUpdate()

    _require_active_profile(user_id)

    row = supabase.update_journal(user_id, journal_id, title, content)
    if not row:
        raise JournalNotFound()
    return _to_out(row)


def delete_journal(user_id: str, journal_id: str) -> None:
    _require_active_profile(user_id)

    if not supabase.delete_journal(user_id, journal_id):
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
