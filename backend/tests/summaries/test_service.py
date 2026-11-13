
import asyncio
import json
from datetime import date
from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest

from app.ai import AIBusy
from app.ai.errors import AITimeout, AIUnavailable, AIBadOutput
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


@pytest.fixture
def mock_empty_journals():
    return SimpleNamespace(journals=[])

@pytest.fixture(autouse=True)
def mock_summary_persistence(monkeypatch):
    from app.summaries import service

    monkeypatch.setattr(
        service,
        "_persist_weekly_summary",
        lambda user_id, summary: None,
    )


# ============================================================
# V1 - WEEKLY MOOD SUMMARY
# ============================================================


def test_returns_insufficient_data_when_no_moods(
    monkeypatch,
    summary_request,
    mock_gateway,
):
    from app.summaries import service

    monkeypatch.setattr(
        service,
        "_persist_weekly_summary",
        lambda user_id, summary: None,
    )

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
        service.create_weekly_summary(
            "user-123",
            summary_request,
        )
    )

    assert result.status == "insufficient_data"
    assert result.mood_count == 0
    assert result.overview is None

    mock_gateway.generate.assert_not_awaited()


def test_returns_complete_summary(
    monkeypatch,
    summary_request,
    mock_moods,
    mock_gateway,
):
    from app.summaries import service

    captured_kwargs = {}

    def mock_list_moods(**kwargs):
        captured_kwargs.update(kwargs)
        return mock_moods

    monkeypatch.setattr(
        service.mood_service,
        "list_moods",
        mock_list_moods,
    )

    monkeypatch.setattr(
        service,
        "get_summary_gateway",
        lambda: mock_gateway,
    )

    result = asyncio.run(
        service.create_weekly_summary(
            "user-123",
            summary_request,
        )
    )

    assert captured_kwargs == {
        "user_id": "user-123",
        "start_date": "2026-11-04",
        "end_date": "2026-11-10",
    }

    assert result.status == "complete"
    assert result.mood_count == 2
    assert result.overview == "Ringkasan mood mingguan."

    mock_gateway.generate.assert_awaited_once()

    call = mock_gateway.generate.call_args.kwargs

    assert call["output"] is MoodSummaryAIOut
    assert call["turns"][0].role == "user"

    payload = json.loads(
        call["turns"][0].content
    )

    assert payload == {
        "period_start": "2026-11-04",
        "period_end": "2026-11-10",
        "moods": [
            {"date": "2026-11-09", "mood": 4},
            {"date": "2026-11-08", "mood": 3},
        ],
    }


def test_returns_unavailable_when_ai_fails(
    monkeypatch,
    summary_request,
    mock_moods,
    mock_gateway,
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
        service.create_weekly_summary(
            "user-123",
            summary_request,
        )
    )

    assert result.status == "unavailable"
    assert result.mood_count == 2
    assert result.overview is None


def test_does_not_send_private_descriptions_to_ai(
    monkeypatch,
    summary_request,
    mock_moods,
    mock_gateway,
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
        service.create_weekly_summary(
            "user-123",
            summary_request,
        )
    )

    sent_payload = json.loads(
        mock_gateway.generate.call_args.kwargs[
            "turns"
        ][0].content
    )

    assert all(
        "description" not in mood
        for mood in sent_payload["moods"]
    )

    assert "Private note" not in str(sent_payload)
    assert "Another private note" not in str(sent_payload)


@pytest.mark.parametrize(
    "error_type",
    [AITimeout, AIUnavailable, AIBadOutput],
)
def test_returns_unavailable_for_all_ai_errors(
    error_type,
    monkeypatch,
    summary_request,
    mock_moods,
    mock_gateway,
):
    from app.summaries import service

    mock_gateway.generate.side_effect = error_type()

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
        service.create_weekly_summary(
            "user-123",
            summary_request,
        )
    )

    assert result.status == "unavailable"
    assert result.mood_count == 2
    assert result.overview is None


def test_propagates_mood_service_errors(
    monkeypatch,
    summary_request,
):
    from app.summaries import service

    def raise_mood_error(**kwargs):
        raise RuntimeError("Mood service failed")

    monkeypatch.setattr(
        service.mood_service,
        "list_moods",
        raise_mood_error,
    )

    with pytest.raises(
        RuntimeError,
        match="Mood service failed",
    ):
        asyncio.run(
            service.create_weekly_summary(
                "user-123",
                summary_request,
            )
        )


# ============================================================
# V2 - SOURCE-AWARE WEEKLY SUMMARY
# ============================================================


def test_weekly_summary_v2_returns_sources_and_limitations(
    monkeypatch,
    mock_empty_journals,
):
    from types import SimpleNamespace

    from app.moods.schemas import MoodOut, MoodListOut
    from app.summaries import service
    from app.summaries.schemas import WeeklySummaryAIOut

    moods = MoodListOut(
        moods=[
            MoodOut(
                id="mood-1",
                user_id="user-123",
                created_at="2026-11-09",
                mood=4,
                description="Catatan privat",
            ),
            MoodOut(
                id="mood-2",
                user_id="user-123",
                created_at="2026-11-10",
                mood=3,
                description="Catatan privat lainnya",
            ),
        ],
        count=2,
        offset=0,
        limit=2,
        total=2,
    )

    gateway = SimpleNamespace(
        generate=AsyncMock(
            return_value=WeeklySummaryAIOut(
                overview="Mood tercatat pada dua hari.",
                limitations=[
                    "Data hanya tersedia sebagian minggu."
                ],
            )
        )
    )

    monkeypatch.setattr(
        service.mood_service,
        "list_moods",
        lambda **kwargs: moods,
    )

    monkeypatch.setattr(
        service.journal_service,
        "list_journals",
        lambda **kwargs: mock_empty_journals,
    )

    monkeypatch.setattr(
        service,
        "get_summary_gateway",
        lambda: gateway,
    )

    result = asyncio.run(
        service.create_weekly_summary_v2(
            "user-123",
            date(2026, 11, 9),
        )
    )

    assert result.status == "completed"
    assert result.overview == "Mood tercatat pada dua hari."

    assert len(result.source_refs) == 2

    assert {
        ref.source_id for ref in result.source_refs
    } == {"mood-1", "mood-2"}

    assert any(
        "2 dari 7 hari" in item
        for item in result.limitations
    )

    payload = json.loads(
        gateway.generate.call_args.kwargs[
            "turns"
        ][0].content
    )

    assert "Catatan privat" not in str(payload)
    assert "description" not in str(payload)


def test_weekly_summary_v2_returns_partial_when_no_moods(
    monkeypatch,
    mock_empty_journals,
):
    from app.moods.schemas import MoodListOut
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
        service.journal_service,
        "list_journals",
        lambda **kwargs: mock_empty_journals,
    )

    gateway = SimpleNamespace(
        generate=AsyncMock()
    )

    monkeypatch.setattr(
        service,
        "get_summary_gateway",
        lambda: gateway,
    )

    result = asyncio.run(
        service.create_weekly_summary_v2(
            "user-123",
            date(2026, 11, 9),
        )
    )

    assert result.status == "partial"
    assert result.overview is None
    assert result.source_refs == []
    assert result.limitations

    gateway.generate.assert_not_awaited()


def test_weekly_summary_v2_returns_partial_when_ai_fails(
    monkeypatch,
    mock_empty_journals,
):
    from app.ai import AIUnavailable
    from app.moods.schemas import MoodOut, MoodListOut
    from app.summaries import service

    moods = MoodListOut(
        moods=[
            MoodOut(
                id="mood-1",
                user_id="user-123",
                created_at="2026-11-09",
                mood=4,
                description=None,
            ),
        ],
        count=1,
        offset=0,
        limit=1,
        total=1,
    )

    gateway = SimpleNamespace(
        generate=AsyncMock(
            side_effect=AIUnavailable()
        )
    )

    monkeypatch.setattr(
        service.mood_service,
        "list_moods",
        lambda **kwargs: moods,
    )

    monkeypatch.setattr(
        service.journal_service,
        "list_journals",
        lambda **kwargs: mock_empty_journals,
    )

    monkeypatch.setattr(
        service,
        "get_summary_gateway",
        lambda: gateway,
    )

    result = asyncio.run(
        service.create_weekly_summary_v2(
            "user-123",
            date(2026, 11, 9),
        )
    )

    assert result.status == "partial"
    assert result.overview is None
    assert result.source_refs[0].source_id == "mood-1"

    assert any(
        "tidak tersedia" in item.lower()
        for item in result.limitations
    )


def test_weekly_summary_v2_rejects_non_monday():
    from app.summaries import service

    with pytest.raises(
        ValueError,
        match="must be a Monday",
    ):
        asyncio.run(
            service.create_weekly_summary_v2(
                "user-123",
                date(2026, 11, 10),
            )
        )


def test_weekly_summary_v2_works_with_fake_provider(
    monkeypatch,
    mock_empty_journals,
):
    from app.ai import AIGateway
    from app.ai.providers import FakeProvider
    from app.moods.schemas import MoodOut, MoodListOut
    from app.summaries import service

    provider = FakeProvider(
        response={
            "overview": (
                "Mood tercatat stabil pada periode ini."
            ),
            "limitations": [],
        }
    )

    gateway = AIGateway(provider=provider)

    monkeypatch.setattr(
        service.mood_service,
        "list_moods",
        lambda **kwargs: MoodListOut(
            moods=[
                MoodOut(
                    id="mood-fake-1",
                    user_id="user-123",
                    created_at="2026-11-09",
                    mood=4,
                    description=None,
                )
            ],
            count=1,
            offset=0,
            limit=1,
            total=1,
        ),
    )

    monkeypatch.setattr(
        service.journal_service,
        "list_journals",
        lambda **kwargs: mock_empty_journals,
    )

    monkeypatch.setattr(
        service,
        "get_summary_gateway",
        lambda: gateway,
    )

    result = asyncio.run(
        service.create_weekly_summary_v2(
            "user-123",
            date(2026, 11, 9),
        )
    )

    assert result.status == "completed"

    assert (
        result.overview
        == "Mood tercatat stabil pada periode ini."
    )

    assert result.source_refs[0].source_id == "mood-fake-1"

    assert len(provider.calls) == 1


def test_weekly_summary_v2_extracts_journal_themes_without_raw_content(
    monkeypatch,
):
    from datetime import date
    from types import SimpleNamespace

    from app.moods.schemas import MoodListOut
    from app.summaries import service
    from app.summaries.schemas import WeeklySummaryAIOut

    journal = SimpleNamespace(
        id="journal-1",
        user_id="user-123",
        created_at="2026-11-09",
        title="Pengalaman minggu ini",
        content="Saya merasa kewalahan dan sulit tidur.",
    )

    extraction_result = SimpleNamespace(
        processing_status="completed",
        themes=[
            SimpleNamespace(
                label="Merasa kewalahan",
                source_journal_id="journal-1",
            ),
            SimpleNamespace(
                label="Kesulitan tidur",
                source_journal_id="journal-1",
            ),
        ],
    )

    extraction_mock = AsyncMock(
        return_value=extraction_result
    )

    gateway = SimpleNamespace(
        generate=AsyncMock(
            return_value=WeeklySummaryAIOut(
                overview="Terdapat tema kewalahan dan kesulitan tidur.",
                limitations=[],
            )
        )
    )

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
        service.journal_service,
        "list_journals",
        lambda **kwargs: SimpleNamespace(
            journals=[journal]
        ),
    )

    monkeypatch.setattr(
        service,
        "extract_journal_themes",
        extraction_mock,
    )

    monkeypatch.setattr(
        service,
        "get_summary_gateway",
        lambda: gateway,
    )

    result = asyncio.run(
        service.create_weekly_summary_v2(
            "user-123",
            date(2026, 11, 9),
        )
    )

    assert result.status == "completed"
    assert result.overview == (
        "Terdapat tema kewalahan dan kesulitan tidur."
    )

    assert any(
        ref.source_type == "mother_journal"
        and ref.source_id == "journal-1"
        for ref in result.source_refs
    )

    extraction_mock.assert_awaited_once()

    extraction_input = extraction_mock.call_args.args[0]

    assert extraction_input[0].id == "journal-1"
    assert extraction_input[0].content == (
        "Saya merasa kewalahan dan sulit tidur."
    )

    summary_payload = json.loads(
        gateway.generate.call_args.kwargs[
            "turns"
        ][0].content
    )

    assert "Saya merasa kewalahan dan sulit tidur." not in str(
        summary_payload
    )

    assert "Merasa kewalahan" in str(summary_payload)
    assert "Kesulitan tidur" in str(summary_payload)


def test_weekly_summary_v2_returns_partial_when_journal_extraction_fails(
    monkeypatch,
):
    from datetime import date
    from types import SimpleNamespace

    from app.moods.schemas import MoodOut, MoodListOut
    from app.summaries import service
    from app.summaries.schemas import WeeklySummaryAIOut

    journal = SimpleNamespace(
        id="journal-1",
        user_id="user-123",
        created_at="2026-11-09",
        title="Pengalaman minggu ini",
        content="Catatan pribadi ibu.",
    )

    gateway = SimpleNamespace(
        generate=AsyncMock(
            return_value=WeeklySummaryAIOut(
                overview="Ringkasan berdasarkan catatan mood.",
                limitations=[],
            )
        )
    )

    monkeypatch.setattr(
        service.mood_service,
        "list_moods",
        lambda **kwargs: MoodListOut(
            moods=[
                MoodOut(
                    id="mood-1",
                    user_id="user-123",
                    created_at="2026-11-09",
                    mood=3,
                    description=None,
                )
            ],
            count=1,
            offset=0,
            limit=1,
            total=1,
        ),
    )

    monkeypatch.setattr(
        service.journal_service,
        "list_journals",
        lambda **kwargs: SimpleNamespace(
            journals=[journal]
        ),
    )

    monkeypatch.setattr(
        service,
        "extract_journal_themes",
        AsyncMock(
            return_value=SimpleNamespace(
                processing_status="failed",
                themes=[],
            )
        ),
    )

    monkeypatch.setattr(
        service,
        "get_summary_gateway",
        lambda: gateway,
    )

    result = asyncio.run(
        service.create_weekly_summary_v2(
            "user-123",
            date(2026, 11, 9),
        )
    )

    assert result.status == "completed"
    assert result.overview == (
        "Ringkasan berdasarkan catatan mood."
    )

    assert any(
        "Tema jurnal tidak dapat diproses" in item
        for item in result.limitations
    )

    assert not any(
        ref.source_type == "mother_journal"
        for ref in result.source_refs
    )

    payload = json.loads(
        gateway.generate.call_args.kwargs[
            "turns"
        ][0].content
    )

    assert "Catatan pribadi ibu." not in str(payload)


def test_weekly_summary_v2_supports_journal_only_summary(
    monkeypatch,
):
    from datetime import date
    from types import SimpleNamespace

    from app.moods.schemas import MoodListOut
    from app.summaries import service
    from app.summaries.schemas import WeeklySummaryAIOut

    journal = SimpleNamespace(
        id="journal-only-1",
        user_id="user-123",
        created_at="2026-11-09",
        title="Catatan ibu",
        content="Saya merasa cemas menghadapi hari esok.",
    )

    gateway = SimpleNamespace(
        generate=AsyncMock(
            return_value=WeeklySummaryAIOut(
                overview="Jurnal menunjukkan tema kecemasan.",
                limitations=[],
            )
        )
    )

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
        service.journal_service,
        "list_journals",
        lambda **kwargs: SimpleNamespace(
            journals=[journal]
        ),
    )

    monkeypatch.setattr(
        service,
        "extract_journal_themes",
        AsyncMock(
            return_value=SimpleNamespace(
                processing_status="completed",
                themes=[
                    SimpleNamespace(
                        label="Kecemasan menghadapi hari esok",
                        source_journal_id="journal-only-1",
                    )
                ],
            )
        ),
    )

    monkeypatch.setattr(
        service,
        "get_summary_gateway",
        lambda: gateway,
    )

    result = asyncio.run(
        service.create_weekly_summary_v2(
            "user-123",
            date(2026, 11, 9),
        )
    )

    assert result.status == "completed"
    assert result.overview == (
        "Jurnal menunjukkan tema kecemasan."
    )

    assert any(
        ref.source_type == "mother_journal"
        and ref.source_id == "journal-only-1"
        for ref in result.source_refs
    )

    gateway.generate.assert_awaited_once()
