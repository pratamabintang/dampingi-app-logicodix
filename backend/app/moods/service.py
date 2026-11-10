from datetime import date
from typing import Optional

from app.auth import supabase as auth_supabase
from app.moods import supabase
from app.shared.day import parse_day, today_for
from app.supabase import SupabaseError
from app.moods.schemas import MoodOut, MoodListOut


class MoodFutureDate(Exception):
    pass


class MoodNotFound(Exception):
    pass


class MoodDuplicate(Exception):

    def __init__(self, created_at: str):
        super().__init__(created_at)
        self.created_at = created_at


class ProfileNotFound(Exception):
    pass


class InvalidDate(Exception):
    pass


_UNIQUE_VIOLATION = "23505"


def _is_duplicate(exc: SupabaseError) -> bool:
    return exc.error_code == _UNIQUE_VIOLATION


def _parse_date(date_str: str) -> date:
    try:
        return parse_day(date_str)
    except (ValueError, TypeError) as e:
        raise InvalidDate(f"Invalid date format: expected YYYY-MM-DD, got '{date_str}'") from e


def _mood_out(row: dict) -> MoodOut:
    return MoodOut(
        id=row["id"],
        user_id=row.get("user_id", ""),
        created_at=row.get("created_at", ""),
        mood=row.get("mood", 0),
        description=row.get("description"),
    )


def create_mood(
    user_id: str, created_at: Optional[str], mood: int, description: Optional[str] = None
) -> MoodOut:
    profile = auth_supabase.fetch_profile(user_id)
    if not profile or profile.get("deleted_at"):
        raise ProfileNotFound()

    today = today_for(profile)

    if created_at is None:
        day = today.isoformat()
    else:
        parsed = _parse_date(created_at)
        if parsed > today:
            raise MoodFutureDate()
        day = parsed.isoformat()

    try:
        row = supabase.create_mood(user_id, day, mood, description)
    except SupabaseError as exc:
        if _is_duplicate(exc):
            raise MoodDuplicate(day) from exc
        raise

    return _mood_out(row)


def get_mood(user_id: str, mood_id: str) -> Optional[MoodOut]:
    row = supabase.fetch_mood(user_id, mood_id)
    if not row:
        return None
    return _mood_out(row)


def list_moods(
    user_id: str,
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    offset: Optional[int] = None,
    limit: Optional[int] = None,
) -> MoodListOut:
    if start_date:
        _parse_date(start_date)
    if end_date:
        _parse_date(end_date)
    
    if offset is None and limit is None:
        rows, total = supabase.list_moods_all(user_id, start_date, end_date)
        moods = [_mood_out(row) for row in rows]
        return MoodListOut(
            moods=moods,
            count=len(moods),
            offset=0,
            limit=len(moods),
            total=len(moods),
        )
    
    offset = offset or 0
    limit = limit or 20
    rows, total = supabase.list_moods(user_id, start_date, end_date, offset, limit)
    moods = [_mood_out(row) for row in rows]
    
    return MoodListOut(
        moods=moods,
        count=len(moods),
        offset=offset,
        limit=limit,
        total=total,
    )


def update_mood(
    user_id: str,
    mood_id: str,
    mood: Optional[int] = None,
    description: Optional[str] = None,
) -> MoodOut:
    row = supabase.update_mood(user_id, mood_id, mood, description)
    if not row:
        raise MoodNotFound()
    return _mood_out(row)


def delete_mood(user_id: str, mood_id: str) -> bool:
    return supabase.delete_mood(user_id, mood_id)
