
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query

from app.auth import service as auth_service
from app.auth.guards import require_role
from app.epds import assessment_service
from app.epds.weekly import weekly_status
from app.epds.schemas import EPDSEvaluateRequest
from app.epds.assessment_schemas import (
    EPDSAssessmentSubmitOut,
    EPDSAssessmentListOut,
    EPDSAlertListOut,
)
from app.supabase import SupabaseError


router = APIRouter(prefix="/v1", tags=["epds-assessments"])

mother_only = require_role("mother")


@router.post(
    "/me/epds-assessments",
    response_model=EPDSAssessmentSubmitOut,
    status_code=201,
    summary="Submit an EPDS demo assessment",
    description=(
        "Submits and stores a deterministic demo-only assessment. "
        "This endpoint is not approved for clinical screening."
    ),
)
def submit_epds_assessment(
    payload: EPDSEvaluateRequest,
    session: auth_service.Session = Depends(mother_only),
):
    try:
        return assessment_service.submit_assessment(
            session.user_id,
            payload,
        )
    except SupabaseError as exc:
        if exc.error_code == "23505":
            raise HTTPException(status_code=409, detail="EPDS dapat diisi lagi 7 hari setelah pengisian terakhir.") from exc
        if exc.error_code == "P0002":
            raise HTTPException(
                status_code=403,
                detail="EPDS pertama dapat diisi 7 hari setelah daftar.",
            ) from exc
        raise HTTPException(
            status_code=502,
            detail="Unable to save EPDS demo assessment",
        ) from exc


@router.get("/me/epds-status", summary="Get the current EPDS eligibility and next available time")
def get_weekly_epds_status(session: auth_service.Session = Depends(mother_only)):
    try:
        return weekly_status(session.user_id)
    except SupabaseError as exc:
        raise HTTPException(status_code=502, detail="Status EPDS belum dapat dimuat.") from exc


@router.get(
    "/mothers/{mother_id}/epds-assessments",
    response_model=EPDSAssessmentListOut,
    summary="Get EPDS assessment history",
)
def get_epds_assessment_history(
    mother_id: UUID,
    session: auth_service.Session = Depends(mother_only),
    offset: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
):
    if str(mother_id) != session.user_id:
        raise HTTPException(
            status_code=403,
            detail="You can only access your own assessment history",
        )

    try:
        return assessment_service.get_assessment_history(
            mother_id=session.user_id,
            offset=offset,
            limit=limit,
        )
    except SupabaseError as exc:
        raise HTTPException(
            status_code=502,
            detail="Unable to retrieve assessment history",
        ) from exc


@router.get(
    "/mothers/{mother_id}/alerts",
    response_model=EPDSAlertListOut,
    summary="Get demo alerts for a mother",
    description=(
        "Only the mother who owns the alerts can access them. "
        "These are demo-only alerts, not clinical notifications."
    ),
)
def get_epds_alerts(
    mother_id: UUID,
    session: auth_service.Session = Depends(mother_only),
    offset: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
):
    if str(mother_id) != session.user_id:
        raise HTTPException(
            status_code=403,
            detail="You can only access your own alerts",
        )

    try:
        return assessment_service.get_mother_alerts(
            mother_id=session.user_id,
            offset=offset,
            limit=limit,
        )
    except SupabaseError as exc:
        raise HTTPException(
            status_code=502,
            detail="Unable to retrieve alerts",
        ) from exc
