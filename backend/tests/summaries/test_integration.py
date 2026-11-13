from datetime import date
import pytest
from fastapi.testclient import TestClient
from app.auth import service as auth_service
from app.summaries import router as summaries_router
from app.summaries.schemas import MoodSummaryOut

pytestmark = pytest.mark.local

@pytest.fixture
def integration_client(offline_env):
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



def test_weekly_summary_response_contains_only_summary_fields(
    integration_client, monkeypatch
):
    from app.summaries.schemas import (
        Audience,
        SummarySourceRef,
        WeeklySummaryResponse,
    )

    client, session = integration_client

    async def mock_create_summary(user_id, period_start):
        assert user_id == session.user_id
        assert period_start == date(2026, 11, 9)

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
    assert body["audience"] == "mother"
    assert body["overview"] == "Ringkasan mood mingguan."
    assert body["limitations"]
    assert body["source_refs"][0]["source_id"] == "mood-1"

    assert "epds_score" not in body
    assert "risk_flag" not in body
