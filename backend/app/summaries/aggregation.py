from datetime import date, datetime, timedelta
from typing import Any

from .schemas import Audience, Coverage, MoodEntry, WeeklySummaryInput


def get_week_period(reference_date: date) -> tuple[date, date]:
    """Return the Monday-to-Sunday period containing reference_date."""
    period_start = reference_date - timedelta(days=reference_date.weekday())
    return period_start, period_start + timedelta(days=6)


def _parse_date(value: Any) -> date:
    """Parse a date, datetime, or ISO YYYY-MM-DD string."""
    if isinstance(value, datetime):
        return value.date()
    if isinstance(value, date):
        return value
    if isinstance(value, str):
        try:
            parsed = date.fromisoformat(value)
        except ValueError as exc:
            raise ValueError(f"Invalid date format: {value}") from exc
        if parsed.isoformat() != value:
            raise ValueError(f"Date must use YYYY-MM-DD format: {value}")
        return parsed
    raise ValueError("Date must be a date or YYYY-MM-DD string")


def _filter_moods(
    items: list[dict[str, Any]],
    period_start: date,
    period_end: date,
) -> list[dict[str, Any]]:
    filtered = []

    for item in items:
        if "created_at" not in item:
            raise ValueError("Every mood entry must contain 'created_at'")
        if not item.get("id"):
            raise ValueError("Every mood entry must contain a valid 'id'")
        if "mood" not in item:
            raise ValueError("Every mood entry must contain 'mood'")

        mood = item["mood"]
        if type(mood) is not int or not 1 <= mood <= 5:
            raise ValueError("Mood must be an integer between 1 and 5")

        item_date = _parse_date(item["created_at"])

        if period_start <= item_date <= period_end:
            filtered.append({
                "id": item["id"],
                "created_at": item_date.isoformat(),
                "mood": mood,
            })

    return filtered


def _filter_journals(
    items: list[dict[str, Any]],
    period_start: date,
    period_end: date,
) -> list[dict[str, Any]]:
    filtered = []

    for item in items:
        if "created_at" not in item:
            raise ValueError("Every journal must contain 'created_at'")
        if not item.get("id"):
            raise ValueError("Every journal must contain a valid 'id'")

        item_date = _parse_date(item["created_at"])

        if period_start <= item_date <= period_end:
            normalized = {
                key: value
                for key, value in item.items()
                if key != "created_at"
            }
            normalized["date"] = item_date.isoformat()
            filtered.append(normalized)

    return filtered


def _filter_observations(
    items: list[dict[str, Any]],
    period_start: date,
    period_end: date,
) -> list[dict[str, Any]]:
    filtered = []

    for item in items:
        if item.get("status") != "completed":
            continue

        if not item.get("id"):
            raise ValueError(
                "Every completed observation must contain a valid 'id'"
            )

        observation_day = item.get("day")
        if observation_day is None:
            continue

        item_date = _parse_date(observation_day)

        if period_start <= item_date <= period_end:
            normalized = {
                key: value
                for key, value in item.items()
                if key != "day"
            }
            normalized["date"] = item_date.isoformat()
            filtered.append(normalized)

    return filtered


def aggregate_weekly_data(
    period_start: date,
    mood_entries: list[dict[str, Any]],
    journal_items: list[dict[str, Any]] | None = None,
    companion_observations: list[dict[str, Any]] | None = None,
) -> dict[str, Any]:
    """Filter and aggregate weekly mood, journal, and observation data."""
    if period_start.weekday() != 0:
        raise ValueError("period_start must be a Monday")

    period_end = period_start + timedelta(days=6)

    filtered_moods = _filter_moods(
        mood_entries, period_start, period_end
    )
    filtered_journals = _filter_journals(
        journal_items or [], period_start, period_end
    )
    filtered_observations = _filter_observations(
        companion_observations or [], period_start, period_end
    )

    mood_days = len({
        _parse_date(item["created_at"]) for item in filtered_moods
    })
    observation_days = len({
        _parse_date(item["date"]) for item in filtered_observations
    })

    return {
        "period_start": period_start,
        "period_end": period_end,
        "expected_days": 7,
        "mood_entries": filtered_moods,
        "journal_items": filtered_journals,
        "companion_observations": filtered_observations,
        "mood_days": mood_days,
        "companion_observation_days": observation_days,
    }


def build_weekly_summary_input(
    period_start: date,
    audience: Audience,
    mood_entries: list[dict[str, Any]],
    journal_items: list[dict[str, Any]] | None = None,
    companion_observations: list[dict[str, Any]] | None = None,
    epds_available: bool = False,
) -> WeeklySummaryInput:
    """Build the validated input for weekly summary generation."""
    aggregated = aggregate_weekly_data(
        period_start=period_start,
        mood_entries=mood_entries,
        journal_items=journal_items,
        companion_observations=companion_observations,
    )

    return WeeklySummaryInput(
        period_start=aggregated["period_start"],
        period_end=aggregated["period_end"],
        audience=audience,
        coverage=Coverage(
            mood_days=aggregated["mood_days"],
            expected_days=aggregated["expected_days"],
            companion_observation_days=aggregated[
                "companion_observation_days"
            ],
            epds_available=epds_available,
        ),
        mother_mood_entries=[
            MoodEntry(
                date=_parse_date(item["created_at"]),
                mood=item["mood"],
            )
            for item in aggregated["mood_entries"]
        ],
        permitted_journal_items=aggregated["journal_items"],
        permitted_companion_observations=aggregated[
            "companion_observations"
        ],
    )
