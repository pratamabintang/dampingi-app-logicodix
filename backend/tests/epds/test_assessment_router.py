
import pytest
from fastapi.testclient import TestClient

from app.auth import service as auth_service
from app.epds import assessment_router, assessment_service


pytestmark = pytest.mark.local

MOTHER_ID = "00000000-0000-4000-8000-000000000001"
OTHER_ID = "00000000-0000-4000-8000-000000000002"


@pytest.fixture
def assessment_client(offline_env):
    from app.main import app

    session = auth_service.Session(
        user_id=MOTHER_ID,
        email="offline@gmail.com",
        token="offline-token",
    )

    app.dependency_overrides[assessment_router.mother_only] = (
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


def sample_assessment():
    return {
        "id": "00000000-0000-4000-8000-000000000010",
        "mother_id": MOTHER_ID,
        "instrument": "EPDS-10",
        "instrument_version": "demo-v1",
        "evaluation_mode": "demo_only",
        "answers": [
            {"item_id": f"Q{i}", "option_index": 0}
            for i in range(1, 11)
        ],
        "total_score": 21,
        "follow_up_required": True,
        "item10_positive": False,
        "immediate_review_required": False,
        "rules_version": "demo-v1",
        "disclaimer": "Simulasi demo, belum divalidasi.",
        "created_at": "2026-11-14T00:00:00+00:00",
    }


def test_submit_assessment_success(
    assessment_client,
    monkeypatch,
):
    monkeypatch.setattr(
        assessment_service,
        "submit_assessment",
        lambda mother_id, payload: {
            "assessment": sample_assessment(),
            "alerts": [],
        },
    )

    response = assessment_client.post(
        "/v1/me/epds-assessments",
        json=valid_answers(),
    )

    assert response.status_code == 201
    assert response.json()["assessment"]["evaluation_mode"] == "demo_only"


def test_get_assessment_history_success(
    assessment_client,
    monkeypatch,
):
    monkeypatch.setattr(
        assessment_service,
        "get_assessment_history",
        lambda **kwargs: {
            "items": [sample_assessment()],
            "total": 1,
            "offset": 0,
            "limit": 20,
        },
    )

    response = assessment_client.get(
        f"/v1/mothers/{MOTHER_ID}/epds-assessments"
    )

    assert response.status_code == 200
    assert response.json()["total"] == 1


def test_get_assessment_history_forbidden(
    assessment_client,
):
    response = assessment_client.get(
        f"/v1/mothers/{OTHER_ID}/epds-assessments"
    )

    assert response.status_code == 403


def test_get_alerts_success(
    assessment_client,
    monkeypatch,
):
    monkeypatch.setattr(
        assessment_service,
        "get_mother_alerts",
        lambda **kwargs: {
            "items": [],
            "total": 0,
            "offset": 0,
            "limit": 20,
        },
    )

    response = assessment_client.get(
        f"/v1/mothers/{MOTHER_ID}/alerts"
    )

    assert response.status_code == 200
    assert response.json()["items"] == []


def test_get_alerts_forbidden(assessment_client):
    response = assessment_client.get(
        f"/v1/mothers/{OTHER_ID}/alerts"
    )

    assert response.status_code == 403
