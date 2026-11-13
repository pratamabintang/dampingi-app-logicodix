from datetime import date, datetime, timedelta, timezone, tzinfo
from typing import Optional
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

# The day default when no usable Profile timezone is stored. Jakarta is the
# product's home zone and the same default `profiles.timezone` carries in the
# database: fixed UTC+7, no DST.
DEFAULT_ZONE = "Asia/Jakarta"

# Ultimate fallback for a host with no tz database at all (Windows, slim
# images). Jakarta has no DST, so a fixed offset is exact, not an
# approximation.
_JAKARTA = timezone(timedelta(hours=7), DEFAULT_ZONE)


def _default_zone() -> tzinfo:
    try:
        return ZoneInfo(DEFAULT_ZONE)
    except (ZoneInfoNotFoundError, ValueError, TypeError):
        return _JAKARTA


def zone_of(profile: Optional[dict]) -> tzinfo:
    name = (profile or {}).get("timezone") or DEFAULT_ZONE
    try:
        return ZoneInfo(name)
    except (ZoneInfoNotFoundError, ValueError, TypeError):
        return _default_zone()


def today_for(profile: Optional[dict]) -> date:
    return datetime.now(zone_of(profile)).date()


def parse_day(date_str: str) -> date:
    parsed = datetime.strptime(date_str, "%Y-%m-%d").date()
    if parsed.isoformat() != date_str:
        raise ValueError(f"Not a strict YYYY-MM-DD date: {date_str!r}")
    return parsed
