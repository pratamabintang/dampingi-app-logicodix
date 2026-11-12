from datetime import date
from typing import Literal, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query

from app.auth import service as auth_service
from app.auth.guards import require_role
from app.observations import service
from app.observations.schemas import (
    ObservationCreate,
    ObservationListOut,
    ObservationOut,
    ObservationSubmit,
)

router = APIRouter(tags=["observations"])

companion_only = require_role("companion")


def _handle_observation_errors(func, *args):
    try:
        return func(*args)
    except service.ObservationCompanionNotFound:
        raise HTTPException(
            status_code=404,
            detail="User profile not found or has been deleted",
        )
    except service.ObservationMotherNotFound:
        raise HTTPException(
            status_code=404,
            detail="Mother not found or not connected",
        )
    except service.ObservationNotFound:
        raise HTTPException(
            status_code=404,
            detail="Observation not found",
        )
    except service.ObservationAlreadyCompleted:
        raise HTTPException(
            status_code=409,
            detail="This Observation has already been completed",
        )
    except service.ObservationDuplicate as exc:
        raise HTTPException(
            status_code=409,
            detail=(
                "An Observation already exists for "
                f"{exc.day} on this Connection"
            ),
        )
    except service.ObservationFutureDay:
        raise HTTPException(
            status_code=400,
            detail="An Observation cannot be completed for a future Day",
        )
    except service.ObservationInvalidAnswers:
        raise HTTPException(
            status_code=422,
            detail=(
                "Answers must cover every stored question exactly once "
                "with an option belonging to it"
            ),
        )


@router.post(
    "/observations",
    status_code=201,
    response_model=ObservationOut,
    summary="Create a draft Observation",
    description=(
        "A Companion creates a draft Observation about a Mother with whom "
        "they have an active Connection. The server assigns stable question "
        "and option IDs. Answers and the Day are supplied at submission."
    ),
)
def create_observation(
    payload: ObservationCreate,
    session: auth_service.Session = Depends(companion_only),
) -> ObservationOut:
    return _handle_observation_errors(
        service.create_observation,
        session.user_id,
        str(payload.mother_id),
        payload.questions,
    )


@router.get(
    "/observations",
    response_model=ObservationListOut,
    summary="List my Observations with optional filters and pagination",
    description=(
        "Every Observation this Companion authored, newest first. Filters "
        "combine: connection_id, day (YYYY-MM-DD), and status (draft or "
        "completed). Observations from ended Connections remain in history. "
        "offset and limit enable pagination (default: no pagination, return "
        "all); when provided, limit is capped at 100."
    ),
)
def list_observations(
    session: auth_service.Session = Depends(companion_only),
    connection_id: Optional[UUID] = Query(
        None, description="Only Observations belonging to this Connection"
    ),
    day: Optional[date] = Query(
        None, description="Only Observations completed for this Day"
    ),
    status: Optional[Literal["draft", "completed"]] = Query(
        None, description="Only drafts or only completed Observations"
    ),
    offset: Optional[int] = Query(
        None, ge=0, description="Number of results to skip (enables pagination)"
    ),
    limit: Optional[int] = Query(
        None, ge=1, le=100, description="Number of results to return (max 100)"
    ),
) -> ObservationListOut:
    return _handle_observation_errors(
        service.list_observations,
        session.user_id,
        str(connection_id) if connection_id is not None else None,
        day,
        status,
        offset,
        limit,
    )


@router.patch(
    "/observations/{observation_id}",
    response_model=ObservationOut,
    summary="Complete a draft Observation",
    description=(
        "Submit every answer plus the Day, completing the Observation once. "
        "The server stamps completed_at. A completed Observation cannot be "
        "edited; another author's Observation is reported as not found."
    ),
)
def submit_observation(
    observation_id: UUID,
    payload: ObservationSubmit,
    session: auth_service.Session = Depends(companion_only),
) -> ObservationOut:
    return _handle_observation_errors(
        service.submit_observation,
        session.user_id,
        str(observation_id),
        payload.answers,
        payload.day,
    )


@router.get(
    "/observations/{observation_id}",
    response_model=ObservationOut,
    summary="Read an authored Observation",
    description=(
        "Returns the author's Observation with its stored question set and "
        "answers. Another author's Observation is reported as not found: its "
        "existence is never confirmed."
    ),
)
def get_observation(
    observation_id: UUID,
    session: auth_service.Session = Depends(companion_only),
) -> ObservationOut:
    return _handle_observation_errors(
        service.get_observation,
        session.user_id,
        str(observation_id),
    )
