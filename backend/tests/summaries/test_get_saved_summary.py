from datetime import date

import pytest

from app.summaries import service


pytestmark = pytest.mark.local


def test_a_saved_row_is_returned_without_its_table_columns(monkeypatch):
    row = {
        "id": "summary-1",
        "mother_id": "mother-1",
        "period_start": "2026-11-09",
        "period_end": "2026-11-15",
        "audience": "mother",
        "status": "completed",
        "overview": "Minggu ini suasana hatimu cenderung stabil.",
        "limitations": ["Catatan mood tersedia pada 5 dari 7 hari."],
        "source_refs": [],
        "prompt_version": "weekly-summary-v2",
        "schema_version": "1",
        "created_at": "2026-11-14T10:00:00+00:00",
    }
    monkeypatch.setattr(
        service.summary_supabase,
        "get_summary",
        lambda **kwargs: row,
    )

    summary = service.get_weekly_summary(
        user_id="mother-1",
        period_start=date(2026, 11, 9),
    )

    assert summary is not None
    assert summary.overview == "Minggu ini suasana hatimu cenderung stabil."
    assert summary.limitations == ["Catatan mood tersedia pada 5 dari 7 hari."]
    assert "mother_id" not in summary.model_dump()