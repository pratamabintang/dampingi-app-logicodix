from datetime import date
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query

from app.auth import service as auth_service
from app.auth.guards import require_role
from app.patient_summaries import service
from app.patient_summaries.schemas import (
    PatientSummaryOut,
    SharingPermissionsOut,
    SharingPermissionsUpdate,
)
from app.supabase import SupabaseError

router = APIRouter(tags=["patient-summaries"])

mother_only = require_role("mother")
professional_only = require_role("professional")


def _connection_not_found() -> HTTPException:
    return HTTPException(
        status_code=404,
        detail="Active professional connection not found",
    )


@router.get(
    "/connections/{connection_id}/sharing-permissions",
    response_model=SharingPermissionsOut,
    summary="Get sharing permissions for a professional connection",
)
def get_sharing_permissions(
    connection_id: UUID,
    session: auth_service.Session = Depends(mother_only),
) -> SharingPermissionsOut:
    try:
        return service.get_sharing_permissions(
            session.user_id, str(connection_id)
        )
    except service.PatientSummaryConnectionNotFound:
        raise _connection_not_found()
    except SupabaseError as exc:
        raise HTTPException(status_code=503, detail=exc.message) from exc


@router.patch(
    "/connections/{connection_id}/sharing-permissions",
    response_model=SharingPermissionsOut,
    summary="Update sharing permissions for a professional connection",
)
def update_sharing_permissions(
    connection_id: UUID,
    payload: SharingPermissionsUpdate,
    session: auth_service.Session = Depends(mother_only),
) -> SharingPermissionsOut:
    try:
        return service.update_sharing_permissions(
            session.user_id,
            str(connection_id),
            payload.changes(),
        )
    except service.PatientSummaryConnectionNotFound:
        raise _connection_not_found()
    except SupabaseError as exc:
        raise HTTPException(status_code=503, detail=exc.message) from exc


@router.get(
    "/connections/{connection_id}/patient-summary",
    response_model=PatientSummaryOut,
    summary="Get consented weekly data for a connected mother",
)
def get_patient_summary(
    connection_id: UUID,
    period_start: date = Query(
        ...,
        description="Monday date in YYYY-MM-DD format",
    ),
    session: auth_service.Session = Depends(professional_only),
) -> PatientSummaryOut:
    try:
        return service.get_patient_summary(
            session.user_id, str(connection_id), period_start
        )
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except service.PatientSummaryConnectionNotFound:
        raise _connection_not_found()
    except SupabaseError as exc:
        raise HTTPException(status_code=503, detail=exc.message) from exc
