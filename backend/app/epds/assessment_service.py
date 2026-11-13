
from datetime import datetime, timezone

from app.epds.schemas import EPDSEvaluateRequest
from app.epds.service import evaluate_epds
from app.epds import supabase


def submit_assessment(
    mother_id: str,
    request: EPDSEvaluateRequest,
) -> dict:
    """
    Evaluate and persist an EPDS demo assessment.

    All evaluation rules are deterministic and independent
    of the AI service.
    """
    result = evaluate_epds(request)

    assessment_payload = {
        "mother_id": mother_id,
        "instrument": result.instrument,
        "instrument_version": "demo-v1",
        "evaluation_mode": result.evaluation_mode,
        "answers": [
            answer.model_dump(mode="json")
            for answer in request.answers
        ],
        "total_score": result.total_score,
        "follow_up_required": result.follow_up_required,
        "item10_positive": result.item10_positive,
        "immediate_review_required": (
            result.immediate_review_required
        ),
        "rules_version": result.rules_version,
        "disclaimer": result.disclaimer,
    }

    assessment = supabase.create_assessment(
        assessment_payload
    )

    alerts = []

    if result.immediate_review_required:
        alerts.append({
            "mother_id": mother_id,
            "assessment_id": assessment["id"],
            "alert_type": "demo_immediate_review",
            "evaluation_mode": "demo_only",
            "message": (
                "Simulasi demo: jawaban pada item terakhir "
                "memerlukan perhatian dalam demonstrasi. "
                "Hasil ini bukan penilaian risiko klinis."
            ),
        })

    if result.follow_up_required:
        alerts.append({
            "mother_id": mother_id,
            "assessment_id": assessment["id"],
            "alert_type": "demo_follow_up",
            "evaluation_mode": "demo_only",
            "message": (
                "Simulasi demo: hasil memicu tindak lanjut "
                "berdasarkan aturan demonstrasi. "
                "Hasil ini bukan penilaian klinis."
            ),
        })

    created_alerts = []

    for alert_payload in alerts:
        created_alerts.append(
            supabase.create_alert(alert_payload)
        )

    return {
        "assessment": assessment,
        "alerts": created_alerts,
    }


def get_assessment_history(
    mother_id: str,
    offset: int = 0,
    limit: int = 20,
) -> dict:
    assessments, total = supabase.list_assessments(
        mother_id=mother_id,
        offset=offset,
        limit=limit,
    )

    return {
        "items": assessments,
        "total": total,
        "offset": offset,
        "limit": limit,
    }


def get_mother_alerts(
    mother_id: str,
    offset: int = 0,
    limit: int = 20,
) -> dict:
    alerts, total = supabase.list_alerts(
        mother_id=mother_id,
        offset=offset,
        limit=limit,
    )

    return {
        "items": alerts,
        "total": total,
        "offset": offset,
        "limit": limit,
    }


def mark_mother_alert_read(
    mother_id: str,
    alert_id: str,
) -> dict | None:
    read_at = datetime.now(timezone.utc).isoformat()

    return supabase.mark_alert_read(
        mother_id=mother_id,
        alert_id=alert_id,
        read_at=read_at,
    )
