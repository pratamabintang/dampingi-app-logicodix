from datetime import date

import pytest
from pydantic import ValidationError

from app.summaries.schemas import (
    MoodSummaryOut,
    MoodSummaryRequest,
)


pytestmark = pytest.mark.local


def test_mood_summary_request_accepts_valid_period():
    request = MoodSummaryRequest(
        period_start=date(2026, 11, 4),
        period_end=date(2026, 11, 10),
    )

    assert request.period_start == date(2026, 11, 4)
    assert request.period_end == date(2026, 11, 10)


def test_mood_summary_request_rejects_invalid_period():
    with pytest.raises(ValidationError):
        MoodSummaryRequest(
            period_start=date(2026, 11, 10),
            period_end=date(2026, 11, 4),
        )


def test_mood_summary_request_rejects_extra_moods_field():
    with pytest.raises(ValidationError):
        MoodSummaryRequest(
            period_start=date(2026, 11, 4),
            period_end=date(2026, 11, 10),
            moods=[],
        )


def test_mood_summary_out_accepts_complete_summary():
    result = MoodSummaryOut(
        status="complete",
        period_start=date(2026, 11, 4),
        period_end=date(2026, 11, 10),
        mood_count=2,
        overview="Mood entries show varied experiences.",
    )

    assert result.status == "complete"
    assert result.mood_count == 2


def test_mood_summary_out_accepts_insufficient_data():
    result = MoodSummaryOut(
        status="insufficient_data",
        period_start=date(2026, 11, 4),
        period_end=date(2026, 11, 10),
        mood_count=0,
        overview=None,
    )

    assert result.overview is None


def test_mood_summary_out_accepts_unavailable_status():
    result = MoodSummaryOut(
        status="unavailable",
        period_start=date(2026, 11, 4),
        period_end=date(2026, 11, 10),
        mood_count=2,
        overview=None,
    )

    assert result.status == "unavailable"


def test_mood_summary_out_rejects_unknown_status():
    with pytest.raises(ValidationError):
        MoodSummaryOut(
            status="failed",
            period_start=date(2026, 11, 4),
            period_end=date(2026, 11, 10),
            mood_count=0,
        )


def test_mood_summary_out_rejects_negative_mood_count():
    with pytest.raises(ValidationError):
        MoodSummaryOut(
            status="complete",
            period_start=date(2026, 11, 4),
            period_end=date(2026, 11, 10),
            mood_count=-1,
        )


def test_mood_summary_out_rejects_extra_fields():
    with pytest.raises(ValidationError):
        MoodSummaryOut(
            status="complete",
            period_start=date(2026, 11, 4),
            period_end=date(2026, 11, 10),
            mood_count=2,
            overview="Summary",
            private_data="should not be accepted",
        )


def test_mood_summary_out_rejects_reversed_period():
    with pytest.raises(ValidationError):
        MoodSummaryOut(
            status="complete",
            period_start=date(2026, 11, 10),
            period_end=date(2026, 11, 4),
            mood_count=2,
            overview="Summary",
        )


def test_mood_summary_out_rejects_complete_without_moods():
    with pytest.raises(ValidationError):
        MoodSummaryOut(
            status="complete",
            period_start=date(2026, 11, 4),
            period_end=date(2026, 11, 10),
            mood_count=0,
            overview="Summary",
        )


def test_mood_summary_out_rejects_complete_with_blank_overview():
    with pytest.raises(ValidationError):
        MoodSummaryOut(
            status="complete",
            period_start=date(2026, 11, 4),
            period_end=date(2026, 11, 10),
            mood_count=2,
            overview="   ",
        )


def test_mood_summary_out_rejects_insufficient_data_with_moods():
    with pytest.raises(ValidationError):
        MoodSummaryOut(
            status="insufficient_data",
            period_start=date(2026, 11, 4),
            period_end=date(2026, 11, 10),
            mood_count=1,
            overview=None,
        )


def test_mood_summary_out_rejects_unavailable_without_moods():
    with pytest.raises(ValidationError):
        MoodSummaryOut(
            status="unavailable",
            period_start=date(2026, 11, 4),
            period_end=date(2026, 11, 10),
            mood_count=0,
            overview=None,
        )
