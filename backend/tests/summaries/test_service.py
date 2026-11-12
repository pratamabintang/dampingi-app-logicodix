import asyncio
import json
from datetime import date
from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest

from app.ai import AIBusy
from app.moods.schemas import MoodOut, MoodListOut
from app.summaries.schemas import MoodSummaryAIOut, MoodSummaryRequest

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


@pytest.fixture
def mock_gateway():
    return SimpleNamespace(
        generate=AsyncMock(
            return_value=MoodSummaryAIOut(
                overview="Ringkasan mood mingguan."
            )
        )
    )


def test_returns_insufficient_data_when_no_moods(
    monkeypatch, summary_request, mock_gateway
):
    from app.summaries import service

    monkeypatch.setattr(
        service.mood_service,
        "list_moods",
        lambda **kwargs: MoodListOut(
            moods=[],
            count=0,
            offset=0,
            limit=0,
            total=0,
        ),
    )
    monkeypatch.setattr(
        service,
        "get_summary_gateway",
        lambda: mock_gateway,
    )

    result = asyncio.run(
        service.create_weekly_summary("user-123", summary_request)
    )

    assert result.status == "insufficient_data"
    assert result.mood_count == 0
    assert result.overview is None
    mock_gateway.generate.assert_not_awaited()


def test_returns_complete_summary(
    monkeypatch, summary_request, mock_moods, mock_gateway
):
    from app.summaries import service

    monkeypatch.setattr(
        service.mood_service,
        "list_moods",
        lambda **kwargs: mock_moods,
    )
    monkeypatch.setattr(
        service,
        "get_summary_gateway",
        lambda: mock_gateway,
    )

    result = asyncio.run(
        service.create_weekly_summary("user-123", summary_request)
    )

    assert result.status == "complete"
    assert result.mood_count == 2
    assert result.overview == "Ringkasan mood mingguan."

    mock_gateway.generate.assert_awaited_once()

    call = mock_gateway.generate.call_args.kwargs

    assert call["output"] is MoodSummaryAIOut
    assert call["turns"][0].role == "user"

    payload = json.loads(call["turns"][0].content)

    assert payload == {
        "period_start": "2026-11-04",
        "period_end": "2026-11-10",
        "moods": [
            {"date": "2026-11-09", "mood": 4},
            {"date": "2026-11-08", "mood": 3},
        ],
    }


def test_returns_unavailable_when_ai_fails(
    monkeypatch, summary_request, mock_moods, mock_gateway
):
    from app.summaries import service

    mock_gateway.generate.side_effect = AIBusy()

    monkeypatch.setattr(
        service.mood_service,
        "list_moods",
        lambda **kwargs: mock_moods,
    )
    monkeypatch.setattr(
        service,
        "get_summary_gateway",
        lambda: mock_gateway,
    )

    result = asyncio.run(
        service.create_weekly_summary("user-123", summary_request)
    )

    assert result.status == "unavailable"
    assert result.mood_count == 2
    assert result.overview is None


def test_does_not_send_private_descriptions_to_ai(
    monkeypatch, summary_request, mock_moods, mock_gateway
):
    from app.summaries import service

    monkeypatch.setattr(
        service.mood_service,
        "list_moods",
        lambda **kwargs: mock_moods,
    )
    monkeypatch.setattr(
        service,
        "get_summary_gateway",
        lambda: mock_gateway,
    )

    asyncio.run(
        service.create_weekly_summary("user-123", summary_request)
    )

    sent_payload = json.loads(
        mock_gateway.generate.call_args.kwargs["turns"][0].content
    )

    assert all(
        "description" not in mood
        for mood in sent_payload["moods"]
    )
    assert "Private note" not in str(sent_payload)
    assert "Another private note" not in str(sent_payload)