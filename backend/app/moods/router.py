from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, Response

from app.auth.guards import require_role
from app.auth import service as auth_service
from app.moods import service
from app.moods.schemas import (
    MoodCreate,
    MoodListOut,
    MoodOut,
    MoodUpdate,
)

router = APIRouter(tags=["moods"])

mother_only = require_role("mother")


def _handle_mood_errors(func, *args):
    try:
        return func(*args)
    except service.InvalidDate as exc:
        raise HTTPException(
            status_code=400,
            detail=str(exc),
        )
    except service.MoodFutureDate:
        raise HTTPException(
            status_code=400,
            detail="Mood entries cannot be created or updated for future dates",
        )
    except service.ProfileNotFound:
        raise HTTPException(
            status_code=404,
            detail="User profile not found or has been deleted",
        )
    except service.MoodDuplicate as exc:
        raise HTTPException(
            status_code=409,
            detail=f"A mood already exists for {exc.created_at}",
        )
    except service.MoodNotFound:
        raise HTTPException(status_code=404, detail="Mood entry not found")


@router.post(
    "/moods",
    status_code=201,
    response_model=MoodOut,
    summary="Create a mood entry for a day",
    description=(
        "One entry per user per day (the caller's local calendar day). "
        "Omit created_at for today; past days may be backfilled, future "
        "days are rejected."
    ),
)
def create_mood(
    payload: MoodCreate,
    session: auth_service.Session = Depends(mother_only),
) -> MoodOut:
    return _handle_mood_errors(
        service.create_mood,
        session.user_id,
        payload.created_at,
        payload.mood,
        payload.description,
    )


@router.get(
    "/moods/{id}",
    response_model=MoodOut,
    summary="Get a mood entry by id",
)
def get_mood(
    id: UUID,
    session: auth_service.Session = Depends(mother_only),
) -> MoodOut:
    mood = _handle_mood_errors(
        service.get_mood,
        session.user_id,
        str(id),
    )
    if mood is None:
        raise HTTPException(status_code=404, detail="Mood entry not found")
    return mood


@router.get(
    "/moods",
    response_model=MoodListOut,
    summary="List mood entries with optional date range and pagination",
    description=(
        "Query parameters start_date and end_date are YYYY-MM-DD dates (optional). "
        "Results are ordered newest first. offset and limit enable pagination "
        "(default: no pagination, return all). When provided, limit is capped at 100."
    ),
)
def list_moods(
    session: auth_service.Session = Depends(mother_only),
    start_date: Optional[str] = Query(None, description="Start date (YYYY-MM-DD)"),
    end_date: Optional[str] = Query(None, description="End date (YYYY-MM-DD)"),
    offset: Optional[int] = Query(None, ge=0, description="Number of results to skip (enables pagination)"),
    limit: Optional[int] = Query(None, ge=1, le=100, description="Number of results to return (max 100)"),
) -> MoodListOut:
    result = _handle_mood_errors(
        service.list_moods,
        session.user_id,
        start_date,
        end_date,
        offset,
        limit,
    )
    return result


@router.patch(
    "/moods/{id}",
    response_model=MoodOut,
    summary="Update the mood value and/or description for an entry by id",
    description=(
        "Update mood, description, or both. The date (created_at) is immutable. "
        "The entry must exist. At least one field must be provided."
    ),
)
def update_mood(
    id: UUID,
    payload: MoodUpdate,
    session: auth_service.Session = Depends(mother_only),
) -> MoodOut:
    return _handle_mood_errors(
        service.update_mood,
        session.user_id,
        str(id),
        payload.mood,
        payload.description,
    )


@router.delete(
    "/moods/{id}",
    status_code=204,
    summary="Delete a mood entry by id",
    description="Idempotent: deleting a non-existent entry returns 204.",
)
def delete_mood(
    id: UUID,
    session: auth_service.Session = Depends(mother_only),
):
    _handle_mood_errors(
        service.delete_mood,
        session.user_id,
        str(id),
    )
    return Response(status_code=204)
