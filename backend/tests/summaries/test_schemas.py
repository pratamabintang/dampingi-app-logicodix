import pytest
from datetime import date
from pydantic import ValidationError

from app.summaries.schemas import (
    MoodSummaryInput,
    MoodSummaryOut,
    MoodSummaryRequest,
)


pytestmark = pytest.mark.local


def test_mood_summary_input_accepts_valid_mood():
    item = MoodSummaryInput(date=date(2026, 11, 10), mood=4)

    assert item.mood == 4
    assert item.date == date(2026, 11, 10)


@pytest.mark.parametrize("mood", [0, 6, -1])
def test_mood_summary_input_rejects_invalid_mood(mood):
    with pytest.raises(ValidationError):
        MoodSummaryInput(date=date(2026, 11, 10), mood=mood)


def test_mood_summary_request_accepts_empty_moods():
    request = MoodSummaryRequest(
        period_start=date(2026, 11, 4),
        period_end=date(2026, 11, 10),
        moods=[],
    )

    assert request.moods == []


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


def test_mood_summary_out_rejects_unknown_status():
    with pytest.raises(ValidationError):
        MoodSummaryOut(
            status="failed",
            period_start=date(2026, 11, 4),
            period_end=date(2026, 11, 10),
            mood_count=0,
        )


def test_mood_summary_input_rejects_extra_fields():
    with pytest.raises(ValidationError):
        MoodSummaryInput(
            date=date(2026, 11, 10),
            mood=4,
            description="private information",
        )
