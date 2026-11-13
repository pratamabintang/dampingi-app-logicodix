
from types import SimpleNamespace

import pytest

from app.epds import assessment_service
from app.epds.schemas import EPDSEvaluateRequest


pytestmark = pytest.mark.local

MOTHER_ID = "00000000-0000-4000-8000-000000000001"


def valid_request():
    return EPDSEvaluateRequest.model_validate({
        "answers": [
            {"item_id": f"Q{i}", "option_index": 0}
            for i in range(1, 11)
        ]
    })


def demo_result(
    follow_up_required=True,
    immediate_review_required=False,
):
    return SimpleNamespace(
        instrument="EPDS-10",
        evaluation_mode="demo_only",
        total_score=21,
        follow_up_required=follow_up_required,
        item10_positive=immediate_review_required,
        immediate_review_required=immediate_review_required,
        rules_version="demo-v1",
        disclaimer="Simulasi demo, belum divalidasi.",
    )


def test_submit_creates_assessment_and_follow_up_alert(monkeypatch):
    monkeypatch.setattr(
        assessment_service,
        "evaluate_epds",
        lambda request: demo_result(),
    )

    monkeypatch.setattr(
        assessment_service.supabase,
        "create_assessment",
        lambda payload: {
            "id": "assessment-1",
            **payload,
        },
    )

    created_alerts = []

    def fake_create_alert(payload):
        created_alerts.append(payload)
        return {"id": "alert-1", **payload}

    monkeypatch.setattr(
        assessment_service.supabase,
        "create_alert",
        fake_create_alert,
    )

    result = assessment_service.submit_assessment(
        MOTHER_ID,
        valid_request(),
    )

    assert result["assessment"]["evaluation_mode"] == "demo_only"
    assert len(result["alerts"]) == 1
    assert created_alerts[0]["alert_type"] == "demo_follow_up"


def test_submit_creates_immediate_review_alert(monkeypatch):
    monkeypatch.setattr(
        assessment_service,
        "evaluate_epds",
        lambda request: demo_result(
            follow_up_required=False,
            immediate_review_required=True,
        ),
    )

    monkeypatch.setattr(
        assessment_service.supabase,
        "create_assessment",
        lambda payload: {"id": "assessment-2", **payload},
    )

    created_alerts = []

    monkeypatch.setattr(
        assessment_service.supabase,
        "create_alert",
        lambda payload: created_alerts.append(payload) or {
            "id": "alert-2",
            **payload,
        },
    )

    result = assessment_service.submit_assessment(
        MOTHER_ID,
        valid_request(),
    )

    assert len(result["alerts"]) == 1
    assert created_alerts[0]["alert_type"] == "demo_immediate_review"


def test_submit_without_trigger_creates_no_alert(monkeypatch):
    monkeypatch.setattr(
        assessment_service,
        "evaluate_epds",
        lambda request: demo_result(
            follow_up_required=False,
            immediate_review_required=False,
        ),
    )

    monkeypatch.setattr(
        assessment_service.supabase,
        "create_assessment",
        lambda payload: {"id": "assessment-3", **payload},
    )

    def unexpected_alert(_):
        pytest.fail("Alert should not be created")

    monkeypatch.setattr(
        assessment_service.supabase,
        "create_alert",
        unexpected_alert,
    )

    result = assessment_service.submit_assessment(
        MOTHER_ID,
        valid_request(),
    )

    assert result["alerts"] == []
