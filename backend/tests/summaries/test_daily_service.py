
import json
from datetime import date, datetime, timezone
from types import SimpleNamespace
from unittest.mock import AsyncMock, Mock

import pytest

from app.ai import AIError
from app.journals.extraction_schemas import (
    JournalTheme,
    JournalExtractionOut,
)
from app.summaries.daily_schemas import DailySummaryAIOut
from app.summaries import daily_service


USER_ID = "mother-123"
SUMMARY_DATE = date(2026, 11, 14)


class FakeChatStore:
    def __init__(self, messages=None):
        self.messages = messages or []
        self.calls = []

    def messages_between(self, user_id, start, end):
        self.calls.append((user_id, start, end))
        return self.messages


@pytest.fixture
def setup_daily(monkeypatch):
    profile = {
        "user_id": USER_ID,
        "role": "mother",
        "timezone": "Asia/Jakarta",
    }

    monkeypatch.setattr(
        daily_service,
        "active_profile",
        Mock(return_value=profile),
    )

    monkeypatch.setattr(
        daily_service.mood_service,
        "list_moods",
        Mock(return_value=SimpleNamespace(moods=[])),
    )

    monkeypatch.setattr(
        daily_service.journal_service,
        "list_journals",
        Mock(return_value=SimpleNamespace(journals=[])),
    )

    monkeypatch.setattr(
        daily_service,
        "extract_journal_themes",
        AsyncMock(
            return_value=JournalExtractionOut(
                themes=[],
                processing_status="completed",
            )
        ),
    )

    save_mock = Mock()
    monkeypatch.setattr(
        daily_service.daily_supabase,
        "save_daily_summary",
        save_mock,
    )

    gateway = SimpleNamespace(
        generate=AsyncMock(
            return_value=DailySummaryAIOut(
                overview="Ibu menjalani hari dengan beberapa aktivitas.",
                limitations=[],
            )
        )
    )

    monkeypatch.setattr(
        daily_service,
        "get_summary_gateway",
        Mock(return_value=gateway),
    )

    return SimpleNamespace(
        gateway=gateway,
        save=save_mock,
    )


@pytest.mark.asyncio
async def test_create_daily_summary_with_all_sources(
    setup_daily,
    monkeypatch,
):
    journal = SimpleNamespace(
        id="journal-1",
        title="Hari ini",
        content="Ibu merasa lelah setelah mengurus bayi.",
        created_at="2026-11-14T08:00:00+07:00",
    )

    mood = SimpleNamespace(
        id="mood-1",
        mood="sad",
        description="Merasa lelah",
    )

    monkeypatch.setattr(
        daily_service.mood_service,
        "list_moods",
        Mock(return_value=SimpleNamespace(moods=[mood])),
    )

    monkeypatch.setattr(
        daily_service.journal_service,
        "list_journals",
        Mock(return_value=SimpleNamespace(journals=[journal])),
    )

    extraction = JournalExtractionOut(
        themes=[
            JournalTheme(
                label="Kelelahan mengurus bayi",
                source_journal_id="journal-1",
            )
        ],
        processing_status="completed",
    )

    extractor = AsyncMock(return_value=extraction)
    monkeypatch.setattr(
        daily_service,
        "extract_journal_themes",
        extractor,
    )

    chat_store = FakeChatStore([
        {
            "id": "chat-1",
            "role": "user",
            "content": "Hari ini saya cukup lelah.",
        },
        {
            "id": "chat-2",
            "role": "assistant",
            "content": "Apa yang membuat ibu merasa lelah?",
        },
    ])

    result = await daily_service.create_daily_summary(
        user_id=USER_ID,
        summary_date=SUMMARY_DATE,
        chat_store=chat_store,
    )

    assert result.status == "completed"
    assert result.overview is not None

    assert {
        (ref.source_type, ref.source_id)
        for ref in result.source_refs
    } == {
        ("mother_mood", "mood-1"),
        ("mother_journal", "journal-1"),
        ("mother_chat_message", "chat-1"),
    }

    # Seluruh sumber harus diambil menggunakan ID ibu.
    assert chat_store.calls[0][0] == USER_ID

    # Batas hari mengikuti timezone Asia/Jakarta.
    _, start, end = chat_store.calls[0]

    assert start == datetime(
        2026, 11, 13, 17, 0, tzinfo=timezone.utc
    )
    assert end == datetime(
        2026, 11, 14, 17, 0, tzinfo=timezone.utc
    )

    # Jurnal diekstrak terlebih dahulu.
    extractor.assert_awaited_once()

    extraction_input = extractor.await_args.args[0]
    assert extraction_input[0].content == journal.content

    # AI ringkasan menerima tema, bukan jurnal mentah.
    gateway_call = setup_daily.gateway.generate.await_args
    prompt_content = gateway_call.kwargs["turns"][0].content

    assert "Kelelahan mengurus bayi" in prompt_content
    assert journal.content not in prompt_content

    payload_start = prompt_content.index('{"summary_date":')
    payload_text = prompt_content[payload_start:]
    payload = json.loads(payload_text)

    assert payload["summary_date"] == SUMMARY_DATE.isoformat()
    assert payload["moods"][0]["id"] == "mood-1"
    assert payload["journal_themes"][0]["id"] == "journal-1"
    assert len(payload["chat_messages"]) == 2

    setup_daily.save.assert_called_once()

    saved_payload = setup_daily.save.call_args.args[0]
    assert saved_payload["mother_id"] == USER_ID
    assert saved_payload["status"] == "completed"


@pytest.mark.asyncio
async def test_create_daily_summary_without_sources(
    setup_daily,
):
    chat_store = FakeChatStore([])

    result = await daily_service.create_daily_summary(
        user_id=USER_ID,
        summary_date=SUMMARY_DATE,
        chat_store=chat_store,
    )

    assert result.status == "partial"
    assert result.overview is None
    assert result.source_refs == []
    assert result.limitations

    # AI tidak perlu dipanggil jika tidak ada sumber.
    setup_daily.gateway.generate.assert_not_awaited()

    # Summary kosong tetap disimpan.
    setup_daily.save.assert_called_once()

    saved_payload = setup_daily.save.call_args.args[0]
    assert saved_payload["status"] == "partial"
    assert saved_payload["mother_id"] == USER_ID


@pytest.mark.asyncio
async def test_create_daily_summary_when_ai_fails(
    setup_daily,
):
    setup_daily.gateway.generate.side_effect = AIError(
        "AI provider unavailable"
    )

    mood = SimpleNamespace(
        id="mood-1",
        mood="happy",
        description="Merasa senang",
    )

    setup_daily_profile = daily_service.mood_service

    original_list_moods = setup_daily_profile.list_moods
    setup_daily_profile.list_moods = Mock(
        return_value=SimpleNamespace(moods=[mood])
    )

    try:
        result = await daily_service.create_daily_summary(
            user_id=USER_ID,
            summary_date=SUMMARY_DATE,
            chat_store=FakeChatStore([]),
        )
    finally:
        setup_daily_profile.list_moods = original_list_moods

    assert result.status == "partial"
    assert result.overview is None
    assert result.source_refs[0].source_id == "mood-1"
    assert any(
        "tidak tersedia" in limitation.lower()
        for limitation in result.limitations
    )

    # Kegagalan AI tidak menghalangi penyimpanan hasil partial.
    setup_daily.save.assert_called_once()


@pytest.mark.asyncio
async def test_create_daily_summary_uses_requested_user_id(
    setup_daily,
):
    chat_store = FakeChatStore([])

    await daily_service.create_daily_summary(
        user_id="another-mother-456",
        summary_date=SUMMARY_DATE,
        chat_store=chat_store,
    )

    assert chat_store.calls[0][0] == "another-mother-456"


@pytest.mark.asyncio
async def test_daily_summary_continues_when_journal_extraction_fails(
    setup_daily,
    monkeypatch,
):
    journal = SimpleNamespace(
        id="journal-1",
        title="Hari ini",
        content="Ibu merasa lelah.",
        created_at="2026-11-14T08:00:00+07:00",
    )

    mood = SimpleNamespace(
        id="mood-1",
        mood="sad",
        description="Merasa lelah",
    )

    monkeypatch.setattr(
        daily_service.mood_service,
        "list_moods",
        Mock(return_value=SimpleNamespace(moods=[mood])),
    )

    monkeypatch.setattr(
        daily_service.journal_service,
        "list_journals",
        Mock(return_value=SimpleNamespace(journals=[journal])),
    )

    monkeypatch.setattr(
        daily_service,
        "extract_journal_themes",
        AsyncMock(
            return_value=JournalExtractionOut(
                themes=[],
                processing_status="failed",
            )
        ),
    )

    chat_store = FakeChatStore([
        {
            "id": "chat-1",
            "role": "user",
            "content": "Saya merasa lelah hari ini.",
        }
    ])

    result = await daily_service.create_daily_summary(
        user_id=USER_ID,
        summary_date=SUMMARY_DATE,
        chat_store=chat_store,
    )

    assert result.status == "completed"
    assert result.overview is not None

    assert {
        (ref.source_type, ref.source_id)
        for ref in result.source_refs
    } == {
        ("mother_mood", "mood-1"),
        ("mother_chat_message", "chat-1"),
    }

    assert any(
        "jurnal tidak dapat diproses" in limitation.lower()
        for limitation in result.limitations
    )

    setup_daily.gateway.generate.assert_awaited_once()
    setup_daily.save.assert_called_once()
