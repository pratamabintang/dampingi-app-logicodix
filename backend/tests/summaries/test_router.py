
from datetime import date

import pytest

from fastapi.testclient import TestClient

from app.auth import service as auth_service
from app.summaries import router as summaries_router
from app.summaries.schemas import MoodSummaryOut


pytestmark = pytest.mark.local


@pytest.fixture
def summary_client(offline_env):
    """
    Create an offline test client with the mother's authentication mocked.
    This prevents requests from reaching the real Supabase service.
    """
    from app.main import app
    from app.auth.router import verified_session

    session = auth_service.Session(
        user_id="00000000-0000-4000-8000-000000000001",
        email="offline@gmail.com",
        token="offline-token",
    )

    app.dependency_overrides[verified_session] = lambda: session
    app.dependency_overrides[summaries_router.mother_only] = (
        lambda: session
    )

    with TestClient(app) as client:
        yield client, session

    app.dependency_overrides.clear()


def test_create_weekly_summary_success(summary_client, monkeypatch):
    client, session = summary_client

    async def mock_create_summary(user_id, period_start):
        assert user_id == session.user_id
        assert period_start == date(2026, 11, 9)

        from app.summaries.schemas import (
            Audience,
            SummarySourceRef,
            WeeklySummaryResponse,
        )

        return WeeklySummaryResponse(
            period_start=date(2026, 11, 9),
            period_end=date(2026, 11, 15),
            audience=Audience.MOTHER,
            status="completed",
            overview="Ringkasan mood mingguan.",
            limitations=["Catatan mood tersedia pada 3 dari 7 hari."],
            source_refs=[
                SummarySourceRef(
                    source_type="mother_mood",
                    source_id="mood-1",
                )
            ],
            prompt_version="weekly-summary-v2",
        )

    monkeypatch.setattr(
        "app.summaries.router.service.create_weekly_summary_v2",
        mock_create_summary,
    )

    response = client.post(
        "/summaries/weekly",
        json={"period_start": "2026-11-09"},
    )

    assert response.status_code == 200

    body = response.json()

    assert body["status"] == "completed"
    assert body["period_start"] == "2026-11-09"
    assert body["period_end"] == "2026-11-15"
    assert body["overview"] == "Ringkasan mood mingguan."
    assert body["source_refs"][0]["source_id"] == "mood-1"
    assert body["limitations"]

def test_create_weekly_summary_rejects_invalid_period(summary_client):
    client, _ = summary_client

    response = client.post(
        "/summaries/weekly",
        json={
            "period_start": "2026-11-10",
            "period_end": "2026-11-04",
        },
    )

    assert response.status_code == 422


def test_create_weekly_summary_rejects_extra_fields(summary_client):
    client, _ = summary_client

    response = client.post(
        "/summaries/weekly",
        json={
            "period_start": "2026-11-04",
            "period_end": "2026-11-10",
            "moods": [],
        },
    )

    assert response.status_code == 422


def test_create_weekly_summary_rejects_companion_role(
    offline_env, monkeypatch
):
    from app.main import app
    from app.auth.router import verified_session

    companion_session = auth_service.Session(
        user_id="00000000-0000-4000-8000-000000000002",
        email="companion@gmail.com",
        token="offline-token",
    )

    monkeypatch.setattr(
        "app.auth.guards.auth_supabase.fetch_profile",
        lambda user_id: {"role": "companion"},
    )

    app.dependency_overrides[verified_session] = lambda: companion_session

    try:
        with TestClient(app) as client:
            response = client.post(
                "/summaries/weekly",
                json={
                    "period_start": "2026-11-04",
                    "period_end": "2026-11-10",
                },
            )
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 403


def test_get_weekly_summary_success(summary_client, monkeypatch):
    client, session = summary_client

    from app.summaries.schemas import (
        Audience,
        SummarySourceRef,
        WeeklySummaryResponse,
    )

    expected = WeeklySummaryResponse(
        period_start=date(2026, 11, 9),
        period_end=date(2026, 11, 15),
        audience=Audience.MOTHER,
        status="completed",
        overview="Ringkasan tersimpan.",
        limitations=[],
        source_refs=[
            SummarySourceRef(
                source_type="mother_mood",
                source_id="mood-1",
            )
        ],
        prompt_version="weekly-summary-v2",
    )

    def mock_get_summary(user_id, period_start):
        assert user_id == session.user_id
        assert period_start == date(2026, 11, 9)
        return expected

    monkeypatch.setattr(
        "app.summaries.router.service.get_weekly_summary",
        mock_get_summary,
    )

    response = client.get(
        "/summaries/weekly",
        params={"period_start": "2026-11-09"},
    )

    assert response.status_code == 200
    assert response.json()["overview"] == "Ringkasan tersimpan."
    assert response.json()["status"] == "completed"


def test_get_weekly_summary_not_found(summary_client, monkeypatch):
    client, _ = summary_client

    monkeypatch.setattr(
        "app.summaries.router.service.get_weekly_summary",
        lambda user_id, period_start: None,
    )

    response = client.get(
        "/summaries/weekly",
        params={"period_start": "2026-11-09"},
    )

    assert response.status_code == 404


def test_get_weekly_summary_rejects_non_monday(
    summary_client,
    monkeypatch,
):
    client, _ = summary_client

    response = client.get(
        "/summaries/weekly",
        params={"period_start": "2026-11-10"},
    )

    assert response.status_code == 422
