
from typing import Optional
from uuid import UUID

from fastapi import (
    APIRouter,
    BackgroundTasks,
    Depends,
    HTTPException,
    Query,
    Response,
)

from app.auth import service as auth_service
from app.auth.guards import require_any_role
from app.journals import service
from app.journals.schemas import (
    JournalCreate,
    JournalListOut,
    JournalOut,
    JournalUpdate,
)

router = APIRouter(tags=["journals"])

mother_or_companion = require_any_role("mother", "companion")


def _is_mother(session: auth_service.Session) -> bool:
    profile = auth_service.active_profile(session.user_id)
    return profile.get("role") == "mother"


async def _refresh_daily_summary_background(user_id, summary_date):
    from app.summaries.daily_service import refresh_daily_summary_background

    await refresh_daily_summary_background(user_id, summary_date)

def _handle_journal_errors(func, *args):
    try:
        return func(*args)
    except service.JournalInvalidDate as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    except service.JournalFutureDate:
        raise HTTPException(
            status_code=400,
            detail="A Journal cannot be written for a future date",
        )
    except service.JournalDuplicate as exc:
        raise HTTPException(
            status_code=409,
            detail=f"A journal already exists for {exc.created_at}",
        )
    except service.JournalProfileNotFound:
        raise HTTPException(
            status_code=404,
            detail="User profile not found or has been deleted",
        )
    except service.JournalNotFound:
        raise HTTPException(status_code=404, detail="Journal not found")
    except service.JournalNothingToUpdate:
        raise HTTPException(
            status_code=400,
            detail="Provide a title, a content, or both to edit a Journal",
        )


@router.post(
    "/journals",
    status_code=201,
    response_model=JournalOut,
    summary="Write a Journal",
    description=(
        "One Journal per Author per day. The day defaults to today in the "
        "Author's own timezone; a past day may be backfilled, a future day "
        "is rejected. Only Mothers and Companions may write Journals."
    ),
)
def create_journal(
    payload: JournalCreate,
    background_tasks: BackgroundTasks,
    session: auth_service.Session = Depends(mother_or_companion),
) -> JournalOut:
    journal = _handle_journal_errors(
        service.create_journal,
        session.user_id,
        payload.title,
        payload.content,
        payload.created_at,
    )

    if _is_mother(session):
        background_tasks.add_task(
            _refresh_daily_summary_background,
            session.user_id,
            journal.created_at[:10],
        )

    return journal


@router.get(
    "/journals",
    response_model=JournalListOut,
    summary="List my Journals with optional date range and pagination",
    description=(
        "Every Journal this Author has written, newest first. "
        "Optional start_date and end_date filter by YYYY-MM-DD date range. "
        "offset and limit enable pagination (default: no pagination, return all). "
        "When provided, limit is capped at 100."
    ),
)
def list_journals(
    session: auth_service.Session = Depends(mother_or_companion),
    start_date: Optional[str] = Query(
        None, description="Start date (YYYY-MM-DD)"
    ),
    end_date: Optional[str] = Query(
        None, description="End date (YYYY-MM-DD)"
    ),
    offset: Optional[int] = Query(
        None, ge=0, description="Number of results to skip (enables pagination)"
    ),
    limit: Optional[int] = Query(
        None, ge=1, le=100, description="Number of results to return (max 100)"
    ),
) -> JournalListOut:
    return _handle_journal_errors(
        service.list_journals,
        session.user_id,
        start_date,
        end_date,
        offset,
        limit,
    )


@router.patch(
    "/journals/{id}",
    response_model=JournalOut,
    summary="Edit a Journal by id",
    description=(
        "Change the title, the content, or both. The day and the id are fixed "
        "when a Journal is written: a `created_at` in the payload is ignored, "
        "and the Journal never moves. An id with no Journal for this Author is "
        "reported as not found, so another Author's Journal stays invisible."
    ),
)
def update_journal(
    id: UUID,
    payload: JournalUpdate,
    background_tasks: BackgroundTasks,
    session: auth_service.Session = Depends(mother_or_companion),
) -> JournalOut:
    journal = _handle_journal_errors(
        service.update_journal,
        session.user_id,
        str(id),
        payload.title,
        payload.content,
    )

    if _is_mother(session):
        background_tasks.add_task(
            _refresh_daily_summary_background,
            session.user_id,
            journal.created_at[:10],
        )

    return journal


@router.delete(
    "/journals/{id}",
    status_code=204,
    summary="Delete a Journal by id",
    description=(
        "Removes this Author's Journal. Not idempotent: an id with no Journal "
        "for this Author is reported as not found, so a delete confirms "
        "nothing about another Author's Journals."
    ),
)
def delete_journal(
    id: UUID,
    background_tasks: BackgroundTasks,
    session: auth_service.Session = Depends(mother_or_companion),
) -> Response:
    existing_journal = _handle_journal_errors(
        service.get_journal,
        session.user_id,
        str(id),
    )

    _handle_journal_errors(
        service.delete_journal,
        session.user_id,
        str(id),
    )

    if _is_mother(session):
        background_tasks.add_task(
            _refresh_daily_summary_background,
            session.user_id,
            existing_journal.created_at[:10],
        )

    return Response(status_code=204)


@router.get(
    "/journals/{id}",
    response_model=JournalOut,
    summary="Read a Journal by id",
    description=(
        "Returns this Author's Journal. Another Author's Journal is reported "
        "as not found: its existence is never confirmed."
    ),
)
def get_journal(
    id: UUID,
    session: auth_service.Session = Depends(mother_or_companion),
) -> JournalOut:
    return _handle_journal_errors(
        service.get_journal,
        session.user_id,
        str(id),
    )
