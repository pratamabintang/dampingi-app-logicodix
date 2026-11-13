
from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query

from app.auth import service as auth_service
from app.auth.guards import require_role
from app.moods import service as mood_service
from app.moods import supabase as mood_supabase
from app.summaries import service
from app.summaries import supabase as summary_supabase
from app.summaries.schemas import (
    WeeklySummaryRequest,
    WeeklySummaryResponse,
)


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
    except (mood_supabase.SupabaseError, summary_supabase.SupabaseError) as exc:
        raise HTTPException(
            status_code=503,
            detail=exc.message,
        )


@router.get(
    "/summaries/weekly",
    response_model=WeeklySummaryResponse,
    summary="Get a saved weekly summary",
    description=(
        "Retrieve the authenticated mother's saved weekly summary "
        "for a Monday-Sunday period."
    ),
)
async def get_weekly_summary(
    period_start: date = Query(
        ...,
        description="Monday date in YYYY-MM-DD format",
    ),
    session: auth_service.Session = Depends(mother_only),
) -> WeeklySummaryResponse:
    try:
        summary = service.get_weekly_summary(
            user_id=session.user_id,
            period_start=period_start,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=422,
            detail=str(exc),
        )
    except summary_supabase.SupabaseError as exc:
        raise HTTPException(
            status_code=503,
            detail=exc.message,
        )

    if summary is None:
        raise HTTPException(
            status_code=404,
            detail="Weekly summary not found",
        )

    return summary
