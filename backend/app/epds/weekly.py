"""Calendar-week EPDS lookup; scoring remains in app.epds.service."""
from datetime import date, datetime, time, timedelta, timezone

from app.auth import supabase as auth_supabase
from app.shared.day import zone_of
from app.epds import supabase


def week_start(day: date) -> date:
    return day - timedelta(days=day.weekday())


def assessment_for_week(mother_id: str, start: date, profile=None) -> dict | None:
    if start.weekday() != 0:
        raise ValueError("period_start must be a Monday")
    if profile is None:
        profile = auth_supabase.fetch_profile(mother_id)
    zone = zone_of(profile)
    start_at = datetime.combine(start, time.min, zone).astimezone(timezone.utc)
    end_at = datetime.combine(start + timedelta(days=7), time.min, zone).astimezone(timezone.utc)
    return supabase.latest_between(mother_id, start_at.isoformat(), end_at.isoformat())


def weekly_status(mother_id: str) -> dict:
    profile = auth_supabase.fetch_profile(mother_id)
    zone = zone_of(profile)
    now = datetime.now(timezone.utc)
    registered_at = datetime.fromisoformat(supabase.registration_time(mother_id).replace("Z", "+00:00"))
    if registered_at.tzinfo is None:
        raise ValueError("Registration timestamp must include timezone")
    rows, _ = supabase.list_assessments(mother_id, limit=1)
    latest = rows[0] if rows else None
    next_at = registered_at + timedelta(days=7)
    if latest is not None:
        last_at = datetime.fromisoformat(latest["created_at"].replace("Z", "+00:00"))
        if last_at.tzinfo is None:
            raise ValueError("Assessment timestamp must include timezone")
        next_at = max(next_at, last_at + timedelta(days=7))
    allowed = now >= next_at
    return {
        "schedule": "rolling_7_days",
        "timezone": str(zone),
        "filled": latest is not None and not allowed,
        "can_submit": allowed,
        "assessment_id": latest["id"] if latest else None,
        "next_available_at": next_at.isoformat(),
        "next_available_date": next_at.astimezone(zone).date().isoformat(),
    }
