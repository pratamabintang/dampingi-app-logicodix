from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, Response

from app.auth import service as auth_service
from app.auth.guards import require_any_role, require_role
from app.professional_notes import service
from app.professional_notes.schemas import (
    ProfessionalNoteCreate,
    ProfessionalNoteListOut,
    ProfessionalNoteOut,
    ProfessionalNoteUpdate,
)

router = APIRouter(tags=["professional-notes"])

professional_only = require_role("professional")
mother_or_professional = require_any_role("mother", "professional")


def _handle_note_errors(func, *args):
    try:
        return func(*args)
    except service.ProfessionalNoteProfileNotFound:
        raise HTTPException(
            status_code=404,
            detail="User profile not found or has been deleted",
        )
    except service.ProfessionalNoteConnectionNotFound:
        raise HTTPException(
            status_code=404,
            detail="Connection not found or not active",
        )
    except service.ProfessionalNoteNotFound:
        raise HTTPException(
            status_code=404,
            detail="Professional note not found",
        )
    except service.ProfessionalNoteConnectionEnded:
        raise HTTPException(
            status_code=409,
            detail=(
                "This Connection has ended; Professional notes are read-only"
            ),
        )


@router.post(
    "/professional-notes",
    status_code=201,
    response_model=ProfessionalNoteOut,
    summary="Write a Professional note",
    description=(
        "A Professional writes a note on an active Connection they own. "
        "Another Professional's Connection, an ended Connection, and an "
        "unknown id all answer 404."
    ),
)
def create_note(
    payload: ProfessionalNoteCreate,
    session: auth_service.Session = Depends(professional_only),
) -> ProfessionalNoteOut:
    return _handle_note_errors(
        service.create_note,
        session.user_id,
        str(payload.connection_id),
        payload.content,
    )


@router.get(
    "/professional-notes",
    response_model=ProfessionalNoteListOut,
    summary="List visible Professional notes",
    description=(
        "A Mother sees notes on every Connection where she is the Mother, "
        "including ended Connections. A Professional sees notes on their own "
        "Connections. Soft-deleted notes are invisible. Newest first; "
        "offset and limit enable pagination (default: no pagination, return "
        "all); when provided, limit is capped at 100."
    ),
)
def list_notes(
    session: auth_service.Session = Depends(mother_or_professional),
    connection_id: Optional[UUID] = Query(
        None, description="Only notes belonging to this Connection"
    ),
    offset: Optional[int] = Query(
        None, ge=0, description="Number of results to skip (enables pagination)"
    ),
    limit: Optional[int] = Query(
        None, ge=1, le=100, description="Number of results to return (max 100)"
    ),
) -> ProfessionalNoteListOut:
    return _handle_note_errors(
        service.list_notes,
        session.user_id,
        str(connection_id) if connection_id is not None else None,
        offset,
        limit,
    )


@router.get(
    "/professional-notes/{note_id}",
    response_model=ProfessionalNoteOut,
    summary="Read a Professional note",
    description=(
        "Readable by the Mother and the Professional on the note's Connection, "
        "including after the Connection ends. Another party's note and a "
        "soft-deleted note are reported as not found."
    ),
)
def get_note(
    note_id: UUID,
    session: auth_service.Session = Depends(mother_or_professional),
) -> ProfessionalNoteOut:
    return _handle_note_errors(
        service.get_note,
        session.user_id,
        str(note_id),
    )


@router.patch(
    "/professional-notes/{note_id}",
    response_model=ProfessionalNoteOut,
    summary="Edit a Professional note",
    description=(
        "Only the Professional who wrote the note may edit it, and only while "
        "the Connection is active. The Connection and identity are fixed; "
        "an edit after the Connection ends answers 409."
    ),
)
def update_note(
    note_id: UUID,
    payload: ProfessionalNoteUpdate,
    session: auth_service.Session = Depends(professional_only),
) -> ProfessionalNoteOut:
    return _handle_note_errors(
        service.update_note,
        session.user_id,
        str(note_id),
        payload.content,
    )


@router.delete(
    "/professional-notes/{note_id}",
    status_code=204,
    summary="Delete a Professional note",
    description=(
        "Soft-deletes the note, only while the Connection is active. The row "
        "is retained but becomes invisible to everyone. An edit or delete "
        "after the Connection ends answers 409."
    ),
)
def delete_note(
    note_id: UUID,
    session: auth_service.Session = Depends(professional_only),
) -> Response:
    _handle_note_errors(
        service.delete_note,
        session.user_id,
        str(note_id),
    )
    return Response(status_code=204)
