import asyncio
import json
from datetime import date
from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest

from app.summaries import service
from app.summaries.schemas import WeeklySummaryResponse, Audience

pytestmark = pytest.mark.local

EPDS = {
    "id": "assessment-A", "total_score": 12, "evaluation_mode": "demo_only",
    "follow_up_required": True, "immediate_review_required": False,
    "disclaimer": "Simulasi demo.", "created_at": "2026-11-15T03:00:00Z",
    "answers": [{"private": "must not be forwarded"}],
}


def test_only_stored_score_and_metadata_not_raw_answers():
    parsed = service._summary_epds(EPDS)
    assert parsed.total_score == 12
    assert "answers" not in parsed.model_dump()


def test_saved_summary_reads_epds_for_same_mother_and_period(monkeypatch):
    row = WeeklySummaryResponse(
        period_start=date(2026, 11, 9), period_end=date(2026, 11, 15),
        audience=Audience.MOTHER, status="partial", overview=None,
        prompt_version="old",
    ).model_dump(mode="json")
    monkeypatch.setattr(service.summary_supabase, "get_summary", lambda **kwargs: row)
    calls = []
    def fetch(mother_id, period_start):
        calls.append((mother_id, period_start))
        return EPDS
    monkeypatch.setattr(service, "assessment_for_week", fetch)
    result = service.get_weekly_summary("mother-A", date(2026, 11, 9))
    assert result.epds_assessment.total_score == 12
    assert calls == [("mother-A", date(2026, 11, 9))]


def test_missing_epds_remains_null(monkeypatch):
    row = WeeklySummaryResponse(
        period_start=date(2026, 11, 9), period_end=date(2026, 11, 15),
        audience=Audience.MOTHER, status="partial", overview=None,
        prompt_version="old",
    ).model_dump(mode="json")
    monkeypatch.setattr(service.summary_supabase, "get_summary", lambda **kwargs: row)
    assert service.get_weekly_summary("mother-A", date(2026, 11, 9)).epds_assessment is None


def test_epds_is_not_written_as_unknown_database_column(monkeypatch):
    summary = WeeklySummaryResponse(
        period_start=date(2026, 11, 9), period_end=date(2026, 11, 15),
        audience=Audience.MOTHER, status="partial", overview=None,
        prompt_version="new", epds_assessment=service._summary_epds(EPDS),
    )
    payloads = []
    monkeypatch.setattr(service.summary_supabase, "save_summary", lambda payload: payloads.append(payload))
    service._persist_weekly_summary("mother-A", summary)
    assert "epds_assessment" not in payloads[0]
    assert payloads[0]["mother_id"] == "mother-A"


def test_epds_only_week_reaches_ai_with_exact_stored_score(monkeypatch):
    monkeypatch.setattr(service, "assessment_for_week", lambda *args: EPDS)
    monkeypatch.setattr(service.mood_service, "list_moods", lambda **kwargs: SimpleNamespace(moods=[]))
    monkeypatch.setattr(service.journal_service, "list_journals", lambda **kwargs: SimpleNamespace(journals=[]))
    gateway = SimpleNamespace(generate=AsyncMock(return_value=SimpleNamespace(
        overview="Tersedia hasil EPDS simulasi demo.", limitations=[])))
    monkeypatch.setattr(service, "get_summary_gateway", lambda: gateway)
    monkeypatch.setattr(service, "_persist_weekly_summary", lambda *args: None)
    result = asyncio.run(service.create_weekly_summary_v2("mother-A", date(2026, 11, 9)))
    sent = json.loads(gateway.generate.call_args.kwargs["turns"][0].content)
    assert sent["coverage"]["epds_available"] is True
    assert sent["epds_assessment"]["total_score"] == 12
    assert "answers" not in sent["epds_assessment"]
    assert result.epds_assessment.total_score == 12
    assert any(ref.source_type == "epds_assessment" for ref in result.source_refs)
