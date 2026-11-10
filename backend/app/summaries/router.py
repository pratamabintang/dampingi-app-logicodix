from fastapi import APIRouter, Depends, HTTPException

from app.auth import service as auth_service
from app.auth.guards import require_role
from app.moods import service as mood_service
from app.moods import supabase as mood_supabase
from app.summaries import service
from app.summaries.schemas import MoodSummaryOut, MoodSummaryRequest


router = APIRouter(tags=["summaries"])

mother_only = require_role("mother")


@router.post(
    "/summaries/weekly",
    response_model=MoodSummaryOut,
    summary="Generate a weekly mood summary",
    description=(
        "Generate a weekly summary based on the authenticated mother's "
        "mood records. Only mood dates and numeric scores are sent to AI."
    ),
)
def create_weekly_summary(
    payload: MoodSummaryRequest,
    session: auth_service.Session = Depends(mother_only),
) -> MoodSummaryOut:
    try:
        return service.create_weekly_summary(
            user_id=session.user_id,
            request=payload,
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