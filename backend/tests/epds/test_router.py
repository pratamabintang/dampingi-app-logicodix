
import pytest
from fastapi.testclient import TestClient

from app.auth import service as auth_service
from app.epds import router as epds_router


pytestmark = pytest.mark.local


@pytest.fixture
def epds_client(offline_env):
    from app.main import app
    from app.auth.router import verified_session

    session = auth_service.Session(
        user_id="00000000-0000-4000-8000-000000000001",
        email="offline@gmail.com",
        token="offline-token",
    )

    app.dependency_overrides[verified_session] = lambda: session
    app.dependency_overrides[epds_router.mother_only] = (
        lambda: session
    )

    with TestClient(app) as client:
        yield client

    app.dependency_overrides.clear()


def valid_answers():
    return {
        "answers": [
            {"item_id": f"Q{i}", "option_index": 0}
            for i in range(1, 11)
        ]
    }


def test_evaluate_epds_success(epds_client):
    response = epds_client.post(
        "/epds/evaluate",
        json=valid_answers(),
    )

    assert response.status_code == 200

    body = response.json()

    assert body["evaluation_mode"] == "demo_only"
    assert body["instrument"] == "EPDS-10"
    assert body["total_score"] == 21
    assert body["follow_up_required"] is True
    assert "belum divalidasi" in body["disclaimer"]


def test_evaluate_epds_rejects_incomplete_answers(epds_client):
    payload = valid_answers()
    payload["answers"].pop()

    response = epds_client.post(
        "/epds/evaluate",
        json=payload,
    )

    assert response.status_code == 422


def test_evaluate_epds_rejects_companion_role(
    offline_env,
    monkeypatch,
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

    app.dependency_overrides[verified_session] = (
        lambda: companion_session
    )

    try:
        with TestClient(app) as client:
            response = client.post(
                "/epds/evaluate",
                json=valid_answers(),
            )
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 403
