from datetime import date
from types import SimpleNamespace
from unittest.mock import patch

import pytest

from app.summaries.schemas import MoodSummaryRequest
from app.summaries.service import create_weekly_summary
from app.moods.schemas import MoodOut, MoodListOut

pytestmark = pytest.mark.local

@pytest.fixture
def summary_request():
    return MoodSummaryRequest(
        period_start=date(2026, 11, 4),
        period_end=date(2026, 11, 10),
    )


@pytest.fixture
def mock_moods():
    moods = [
        MoodOut(
            id="mood-1",
            user_id="user-123",
            created_at="2026-11-09",
            mood=4,
            description="Private note",
        ),
        MoodOut(
            id="mood-2",
            user_id="user-123",
            created_at="2026-11-08",
            mood=3,
            description="Another private note",
        ),
    ]

    return MoodListOut(
        moods=moods,
        count=2,
        offset=0,
        limit=2,
        total=2,
    )


@patch("app.summaries.service.mood_service.list_moods")
def test_returns_insufficient_data_when_no_moods(mock_list, summary_request):
    mock_list.return_value = MoodListOut(
        moods=[],
        count=0,
        offset=0,
        limit=0,
        total=0,
    )

    with patch("app.summaries.service.generate_summary") as mock_ai:
        result = create_weekly_summary("user-123", summary_request)

    assert result.status == "insufficient_data"
    assert result.mood_count == 0
    assert result.overview is None
    mock_ai.assert_not_called()


@patch("app.summaries.service.get_settings")
@patch("app.summaries.service.generate_summary")
@patch("app.summaries.service.mood_service.list_moods")
def test_returns_complete_summary(mock_list, mock_ai, mock_settings, summary_request, mock_moods):
    mock_list.return_value = mock_moods
    mock_ai.return_value = "Ringkasan mood mingguan."
    mock_settings.return_value = SimpleNamespace(
        gemini_api_key="fake-test-key",
        gemini_model="gemini-3.1-flash-lite",
    )

    result = create_weekly_summary("user-123", summary_request)

    assert result.status == "complete"
    assert result.mood_count == 2
    assert result.overview == "Ringkasan mood mingguan."

    mock_ai.assert_called_once_with(
        moods=[
            {"date": "2026-11-09", "mood": 4},
            {"date": "2026-11-08", "mood": 3},
        ],
        period_start="2026-11-04",
        period_end="2026-11-10",
        api_key="fake-test-key",
        model="gemini-3.1-flash-lite",
    )


@patch("app.summaries.service.get_settings")
@patch("app.summaries.service.generate_summary")
@patch("app.summaries.service.mood_service.list_moods")
def test_returns_unavailable_when_ai_fails(
    mock_list, mock_ai, mock_settings, summary_request, mock_moods
):
    mock_list.return_value = mock_moods
    mock_ai.side_effect = RuntimeError("Gemini unavailable")
    mock_settings.return_value = SimpleNamespace(
        gemini_api_key="fake-test-key",
        gemini_model="gemini-3.1-flash-lite",
    )

    result = create_weekly_summary("user-123", summary_request)

    assert result.status == "unavailable"
    assert result.mood_count == 2
    assert result.overview is None


@patch("app.summaries.service.get_settings")
@patch("app.summaries.service.generate_summary")
@patch("app.summaries.service.mood_service.list_moods")
def test_does_not_send_private_descriptions_to_ai(
    mock_list, mock_ai, mock_settings, summary_request, mock_moods
):
    mock_list.return_value = mock_moods
    mock_ai.return_value = "Ringkasan."
    mock_settings.return_value = SimpleNamespace(
        gemini_api_key="fake-test-key",
        gemini_model="gemini-3.1-flash-lite",
    )

    create_weekly_summary("user-123", summary_request)

    sent_moods = mock_ai.call_args.kwargs["moods"]

    assert all("description" not in mood for mood in sent_moods)