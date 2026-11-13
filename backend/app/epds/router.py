
from fastapi import APIRouter, Depends

from app.auth.guards import require_role
from app.auth import service as auth_service
from app.epds.schemas import (
    EPDSEvaluateRequest,
    EPDSEvaluateResponse,
)
from app.epds.service import evaluate_epds

router = APIRouter(tags=["epds"])

mother_only = require_role("mother")


@router.post(
    "/epds/evaluate",
    response_model=EPDSEvaluateResponse,
    summary="Evaluate EPDS demo responses",
    description=(
        "Calculates a deterministic EPDS demo score. "
        "This endpoint is for demonstration only and is not "
        "validated or approved for clinical use."
    ),
)
def evaluate(
    payload: EPDSEvaluateRequest,
    session: auth_service.Session = Depends(mother_only),
) -> EPDSEvaluateResponse:
    return evaluate_epds(payload)
