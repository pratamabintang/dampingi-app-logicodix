from datetime import date, datetime, timezone, tzinfo
from typing import Optional
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError


def zone_of(profile: Optional[dict]) -> tzinfo:
    name = (profile or {}).get("timezone")
    if not name:
        return timezone.utc
    try:
        return ZoneInfo(name)
    except (ZoneInfoNotFoundError, ValueError, TypeError):
        return timezone.utc


def today_for(profile: Optional[dict]) -> date:
    return datetime.now(zone_of(profile)).date()


def parse_day(date_str: str) -> date:
    parsed = datetime.strptime(date_str, "%Y-%m-%d").date()
    if parsed.isoformat() != date_str:
        raise ValueError(f"Not a strict YYYY-MM-DD date: {date_str!r}")
    return parsed
