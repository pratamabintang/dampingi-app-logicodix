
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

    async def mock_create_summary(user_id, request):
        assert user_id == session.user_id
        assert request.period_start == date(2026, 11, 4)
        assert request.period_end == date(2026, 11, 10)

        return MoodSummaryOut(
            status="complete",
            period_start=request.period_start,
            period_end=request.period_end,
            mood_count=3,
            overview="Ringkasan mood mingguan.",
        )

    monkeypatch.setattr(
        "app.summaries.router.service.create_weekly_summary",
        mock_create_summary,
    )

    response = client.post(
        "/summaries/weekly",
        json={
            "period_start": "2026-11-04",
            "period_end": "2026-11-10",
        },
    )

    assert response.status_code == 200

    body = response.json()

    assert body["status"] == "complete"
    assert body["period_start"] == "2026-11-04"
    assert body["period_end"] == "2026-11-10"
    assert body["mood_count"] == 3
    assert body["overview"] == "Ringkasan mood mingguan."


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
