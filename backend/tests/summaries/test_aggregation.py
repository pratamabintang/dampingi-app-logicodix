from datetime import date, datetime
import pytest

from app.summaries.aggregation import (
    aggregate_weekly_data,
    get_week_period,
)


def test_get_week_period_returns_monday_to_sunday():
    start, end = get_week_period(date(2026, 11, 13))

    assert start == date(2026, 11, 9)
    assert end == date(2026, 11, 15)


def test_aggregate_weekly_data_filters_entries_outside_period():
    result = aggregate_weekly_data(
        date(2026, 11, 9),
        [
            {"id": "1", "created_at": "2026-11-08", "mood": 3},
            {"id": "2", "created_at": "2026-11-09", "mood": 4},
            {"id": "3", "created_at": "2026-11-15", "mood": 5},
            {"id": "4", "created_at": "2026-11-16", "mood": 2},
        ],
    )

    assert [item["id"] for item in result["mood_entries"]] == ["2", "3"]
    assert result["mood_days"] == 2


def test_aggregate_weekly_data_counts_unique_mood_days():
    result = aggregate_weekly_data(
        date(2026, 11, 9),
        [
            {"id": "1", "created_at": "2026-11-09", "mood": 3},
            {"id": "2", "created_at": "2026-11-09", "mood": 4},
            {"id": "3", "created_at": "2026-11-10", "mood": 5},
        ],
    )

    assert len(result["mood_entries"]) == 3
    assert result["mood_days"] == 2


def test_aggregate_weekly_data_excludes_private_description():
    result = aggregate_weekly_data(
        date(2026, 11, 9),
        [
            {
                "id": "1",
                "created_at": "2026-11-09",
                "mood": 4,
                "description": "Private journal-like note",
            },
        ],
    )

    assert result["mood_entries"] == [
        {
            "id": "1",
            "created_at": "2026-11-09",
            "mood": 4,
        }
    ]


def test_aggregate_weekly_data_returns_empty_result():
    result = aggregate_weekly_data(date(2026, 11, 9), [])

    assert result["period_start"] == date(2026, 11, 9)
    assert result["period_end"] == date(2026, 11, 15)
    assert result["expected_days"] == 7
    assert result["mood_entries"] == []
    assert result["mood_days"] == 0


def test_aggregate_weekly_data_rejects_non_monday():
    with pytest.raises(ValueError, match="Monday"):
        aggregate_weekly_data(date(2026, 11, 10), [])


def test_aggregate_weekly_data_rejects_invalid_date():
    with pytest.raises(ValueError, match="Invalid date format"):
        aggregate_weekly_data(
            date(2026, 11, 9),
            [{"id": "1", "created_at": "not-a-date", "mood": 3}],
        )


def test_aggregate_weekly_data_rejects_missing_created_at():
    with pytest.raises(ValueError, match="created_at"):
        aggregate_weekly_data(
            date(2026, 11, 9),
            [{"id": "1", "mood": 3}],
        )


def test_aggregate_weekly_data_rejects_missing_id():
    with pytest.raises(ValueError, match="id"):
        aggregate_weekly_data(
            date(2026, 11, 9),
            [{"created_at": "2026-11-09", "mood": 3}],
        )


def test_aggregate_weekly_data_rejects_missing_mood():
    with pytest.raises(ValueError, match="mood"):
        aggregate_weekly_data(
            date(2026, 11, 9),
            [{"id": "1", "created_at": "2026-11-09"}],
        )


def test_aggregate_weekly_data_accepts_datetime_value():
    result = aggregate_weekly_data(
        date(2026, 11, 9),
        [
            {
                "id": "1",
                "created_at": datetime(2026, 11, 9, 10, 30),
                "mood": 4,
            },
        ],
    )

    assert result["mood_entries"][0]["created_at"] == "2026-11-09"

def test_aggregate_weekly_data_filters_journals_by_period():
    result = aggregate_weekly_data(
        date(2026, 11, 9),
        [],
        journal_items=[
            {
                "id": "j1",
                "created_at": "2026-11-08",
                "title": "Outside",
                "content": "Not included",
            },
            {
                "id": "j2",
                "created_at": "2026-11-10",
                "title": "Inside",
                "content": "Permitted journal",
            },
        ],
    )

    assert len(result["journal_items"]) == 1
    assert result["journal_items"][0]["id"] == "j2"
    assert result["journal_items"][0]["date"] == "2026-11-10"


def test_aggregate_weekly_data_includes_only_completed_observations():
    result = aggregate_weekly_data(
        date(2026, 11, 9),
        [],
        companion_observations=[
            {
                "id": "o1",
                "status": "completed",
                "day": "2026-11-10",
                "answers": {"mood": "good"},
            },
            {
                "id": "o2",
                "status": "draft",
                "day": "2026-11-11",
                "answers": {},
            },
            {
                "id": "o3",
                "status": "completed",
                "day": "2026-11-16",
                "answers": {},
            },
        ],
    )

    assert len(result["companion_observations"]) == 1
    assert result["companion_observations"][0]["id"] == "o1"
    assert result["companion_observations"][0]["date"] == "2026-11-10"
    assert result["companion_observation_days"] == 1


def test_build_weekly_summary_input_builds_coverage_and_sources():
    from app.summaries.aggregation import build_weekly_summary_input
    from app.summaries.schemas import Audience

    result = build_weekly_summary_input(
        period_start=date(2026, 11, 9),
        audience=Audience.MOTHER,
        mood_entries=[
            {
                "id": "m1",
                "created_at": "2026-11-09",
                "mood": 4,
            },
            {
                "id": "m2",
                "created_at": "2026-11-09",
                "mood": 3,
            },
        ],
        journal_items=[
            {
                "id": "j1",
                "created_at": "2026-11-10",
                "title": "Journal",
                "content": "Permitted content",
            },
        ],
        companion_observations=[
            {
                "id": "o1",
                "status": "completed",
                "day": "2026-11-11",
                "answers": {"condition": "good"},
            },
        ],
    )

    assert result.period_start == date(2026, 11, 9)
    assert result.period_end == date(2026, 11, 15)
    assert result.coverage.mood_days == 1
    assert result.coverage.expected_days == 7
    assert result.coverage.companion_observation_days == 1
    assert result.coverage.epds_available is False
    assert len(result.mother_mood_entries) == 2
    assert result.mother_mood_entries[0].date == date(2026, 11, 9)
    assert len(result.permitted_journal_items) == 1
    assert len(result.permitted_companion_observations) == 1

def test_aggregate_weekly_data_rejects_null_mood():
    with pytest.raises(ValueError, match="Mood must be an integer"):
        aggregate_weekly_data(
            date(2026, 11, 9),
            [{"id": "m1", "created_at": "2026-11-09", "mood": None}],
        )


def test_aggregate_weekly_data_empty_moods_have_zero_coverage():
    result = aggregate_weekly_data(date(2026, 11, 9), [])

    assert result["mood_entries"] == []
    assert result["mood_days"] == 0


def test_aggregate_weekly_data_keeps_mother_and_companion_sources_separate():
    result = aggregate_weekly_data(
        date(2026, 11, 9),
        [{"id": "m1", "created_at": "2026-11-09", "mood": 4}],
        companion_observations=[
            {
                "id": "o1",
                "status": "completed",
                "day": "2026-11-10",
                "answers": {"condition": "good"},
            }
        ],
    )

    assert [item["id"] for item in result["mood_entries"]] == ["m1"]
    assert [item["id"] for item in result["companion_observations"]] == ["o1"]
