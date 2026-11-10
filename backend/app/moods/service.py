from datetime import date, datetime, timezone
from typing import Optional

from app.auth import supabase as auth_supabase
from app.moods import supabase
from app.supabase import SupabaseError
from app.moods.schemas import MoodOut


class MoodFutureDate(Exception):
    pass


class MoodNotFound(Exception):
    pass


class ProfileNotFound(Exception):
    pass


class InvalidDate(Exception):
    pass


def _parse_date(date_str: str) -> date:
    try:
        return datetime.strptime(date_str, "%Y-%m-%d").date()
    except (ValueError, TypeError) as e:
        raise InvalidDate(f"Invalid date format: expected YYYY-MM-DD, got '{date_str}'") from e


def _today() -> date:
    return datetime.now(timezone.utc).date()


def _is_future(date_str: str) -> bool:
    parsed_date = _parse_date(date_str)
    return parsed_date > _today()


def create_mood(
    user_id: str, created_at: str, mood: int, description: Optional[str] = None
) -> MoodOut:
    if _is_future(created_at):
        raise MoodFutureDate()

    profile = auth_supabase.fetch_profile(user_id)
    if not profile or profile.get("deleted_at"):
        raise ProfileNotFound()

    row = supabase.create_mood(user_id, created_at, mood, description)
    return MoodOut(
        user_id=row.get("user_id", ""),
        created_at=row.get("created_at", ""),
        mood=row.get("mood", 0),
        description=row.get("description"),
    )


def get_mood(user_id: str, created_at: str) -> Optional[MoodOut]:
    _parse_date(created_at)
    
    row = supabase.fetch_mood(user_id, created_at)
    if not row:
        return None
    return MoodOut(
        user_id=row.get("user_id", ""),
        created_at=row.get("created_at", ""),
        mood=row.get("mood", 0),
        description=row.get("description"),
    )


def list_moods(
    user_id: str, start_date: Optional[str] = None, end_date: Optional[str] = None
) -> list[MoodOut]:
    if start_date:
        _parse_date(start_date)
    if end_date:
        _parse_date(end_date)
    
    rows = supabase.list_moods(user_id, start_date, end_date)
    return [
        MoodOut(
            user_id=row.get("user_id", ""),
            created_at=row.get("created_at", ""),
            mood=row.get("mood", 0),
            description=row.get("description"),
        )
        for row in rows
    ]


def update_mood(
    user_id: str,
    created_at: str,
    mood: Optional[int] = None,
    description: Optional[str] = None,
) -> MoodOut:
    _parse_date(created_at)
    
    row = supabase.update_mood(user_id, created_at, mood, description)
    if not row:
        raise MoodNotFound()
    return MoodOut(
        user_id=row.get("user_id", ""),
        created_at=row.get("created_at", ""),
        mood=row.get("mood", 0),
        description=row.get("description"),
    )


def delete_mood(user_id: str, created_at: str) -> bool:
    return supabase.delete_mood(user_id, created_at)
