from fastapi import APIRouter, Depends, HTTPException

from app.auth import service as auth_service
from app.auth.guards import require_role
from app.moods import service as mood_service
from app.moods import supabase as mood_supabase
from app.summaries import service
from app.summaries.schemas import WeeklySummaryRequest, WeeklySummaryResponse


router = APIRouter(tags=["summaries"])

mother_only = require_role("mother")


@router.post(
    "/summaries/weekly",
    response_model=WeeklySummaryResponse,
    summary="Generate a weekly mood summary",
    description=(
        "Generate a Monday-Sunday summary for the authenticated mother. "
        "The response includes source references and data limitations."
    ),
)
async def create_weekly_summary(
    payload: WeeklySummaryRequest,
    session: auth_service.Session = Depends(mother_only),
) -> WeeklySummaryResponse:
    try:
        return await service.create_weekly_summary_v2(
            user_id=session.user_id,
            period_start=payload.period_start,
        )
    except mood_service.ProfileNotFound:
        raise HTTPException(
            status_code=404,
            detail="User profile not found or has been deleted",
        )
    except mood_supabase.SupabaseError as exc:
        raise HTTPException(
            status_code=503,
            detail=exc.message,
        )