from datetime import date

import pytest

from app.patient_summaries import service


def _connection(
    *,
    weekly_summary: bool = False,
    epds: bool = False,
    journal: bool = False,
) -> dict:
    return {
        "id": "connection-1",
        "mother_id": "mother-1",
        "counterpart_id": "professional-1",
        "share_weekly_summary": weekly_summary,
        "share_epds": epds,
        "share_journal": journal,
        "mother": {"name": "Ibu Demo"},
    }


def test_patient_summary_does_not_read_unshared_categories(monkeypatch):
    monkeypatch.setattr(
        "app.patient_summaries.service.connections_supabase."
        "fetch_active_professional_connection",
        lambda professional_id, connection_id: _connection(),
    )

    def forbidden(*args, **kwargs):
        raise AssertionError("unshared patient data must not be queried")

    monkeypatch.setattr(
        "app.patient_summaries.service.moods_supabase.list_moods_all",
        forbidden,
    )
    monkeypatch.setattr(
        "app.patient_summaries.service.journals_supabase.list_journals_all",
        forbidden,
    )
    monkeypatch.setattr(
        "app.patient_summaries.service.epds_supabase.list_assessments",
        forbidden,
    )

    summary = service.get_patient_summary(
        "professional-1", "connection-1", date(2026, 11, 9)
    )

    assert summary.mother_name == "Ibu Demo"
    assert summary.permissions.weekly_summary is False
    assert summary.moods == []
    assert summary.journals == []
    assert summary.epds == []


def test_patient_summary_returns_only_consented_fields(monkeypatch):
    connection = _connection(weekly_summary=True, epds=True, journal=True)
    monkeypatch.setattr(
        "app.patient_summaries.service.connections_supabase."
        "fetch_active_professional_connection",
        lambda professional_id, connection_id: connection,
    )
    monkeypatch.setattr(
        "app.patient_summaries.service.moods_supabase.list_moods_all",
        lambda mother_id, start, end: (
            [
                {
                    "id": "mood-id",
                    "created_at": "2026-11-10",
                    "mood": 4,
                    "description": "private description",
                }
            ],
            1,
        ),
    )
    monkeypatch.setattr(
        "app.patient_summaries.service.journals_supabase.list_journals_all",
        lambda mother_id, start, end: (
            [
                {
                    "id": "journal-id",
                    "created_at": "2026-11-11",
                    "title": "Catatan ibu",
                    "content": "Cerita yang dibagikan",
                }
            ],
            1,
        ),
    )
    monkeypatch.setattr(
        "app.patient_summaries.service.epds_supabase.list_assessments",
        lambda **kwargs: (
            [
                {
                    "created_at": "2026-11-12T10:00:00Z",
                    "total_score": 8,
                    "follow_up_required": False,
                    "immediate_review_required": False,
                    "disclaimer": "Demo saja.",
                    "answers": [{"answer": "must not be returned"}],
                }
            ],
            1,
        ),
    )

    summary = service.get_patient_summary(
        "professional-1", "connection-1", date(2026, 11, 9)
    )
    body = summary.model_dump(mode="json")

    assert body["moods"] == [{"date": "2026-11-10", "mood": 4}]
    assert body["journals"] == [
        {
            "id": "journal-id",
            "created_at": "2026-11-11",
            "title": "Catatan ibu",
            "content": "Cerita yang dibagikan",
        }
    ]
    assert body["epds"] == [
        {
            "date": "2026-11-12",
            "total_score": 8,
            "follow_up_required": False,
            "immediate_review_required": False,
            "disclaimer": "Demo saja.",
        }
    ]
    assert "private description" not in str(body)
    assert "answers" not in str(body)


def test_patient_summary_requires_active_professional_connection(monkeypatch):
    monkeypatch.setattr(
        "app.patient_summaries.service.connections_supabase."
        "fetch_active_professional_connection",
        lambda professional_id, connection_id: None,
    )

    with pytest.raises(service.PatientSummaryConnectionNotFound):
        service.get_patient_summary(
            "professional-1", "another-connection", date(2026, 11, 9)
        )


def test_patient_summary_requires_monday_start():
    with pytest.raises(ValueError, match="Monday"):
        service.get_patient_summary(
            "professional-1", "connection-1", date(2026, 11, 10)
        )
