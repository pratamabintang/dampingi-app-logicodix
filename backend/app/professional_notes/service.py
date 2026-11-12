from typing import Optional

from app.professional_notes import supabase
from app.professional_notes.schemas import (
    ProfessionalNoteListOut,
    ProfessionalNoteOut,
)
from app.shared.profile import active_profile
from app.supabase import SupabaseError


class ProfessionalNoteProfileNotFound(Exception):
    """The caller has no active Profile."""


class ProfessionalNoteConnectionNotFound(Exception):
    """No active Professional Connection of this caller has that id."""


class ProfessionalNoteNotFound(Exception):
    """No visible note has that id."""


class ProfessionalNoteConnectionEnded(Exception):
    """The note is readable, but its Connection has ended."""


_READ_ROLES = ("mother", "professional")


def _require_active_profile(user_id: str) -> dict:
    profile = active_profile(user_id)
    if profile is None:
        raise ProfessionalNoteProfileNotFound()
    return profile


def _reader_role(user_id: str) -> str:
    profile = active_profile(user_id)
    if profile is None or profile.get("role") not in _READ_ROLES:
        raise ProfessionalNoteProfileNotFound()
    return profile["role"]


def _to_out(row: dict, connection: dict) -> ProfessionalNoteOut:
    return ProfessionalNoteOut(
        id=row["id"],
        connection_id=row["connection_id"],
        professional_id=connection["counterpart_id"],
        mother_id=connection["mother_id"],
        content=row["content"],
        created_at=row["created_at"],
        updated_at=row["updated_at"],
    )


def _embedded_out(row: dict) -> ProfessionalNoteOut:
    return _to_out(row, row["connection"])


def create_note(
    user_id: str, connection_id: str, content: str
) -> ProfessionalNoteOut:
    _require_active_profile(user_id)

    connection = supabase.fetch_active_professional_connection(
        user_id, connection_id
    )
    if connection is None:
        raise ProfessionalNoteConnectionNotFound()

    row = supabase.create_note(connection_id, content)
    return _to_out(row, connection)


def get_note(user_id: str, note_id: str) -> ProfessionalNoteOut:
    role = _reader_role(user_id)
    row = supabase.fetch_note(user_id, role, note_id)
    if row is None:
        raise ProfessionalNoteNotFound()
    return _embedded_out(row)


def update_note(user_id: str, note_id: str, content: str) -> ProfessionalNoteOut:
    _require_active_profile(user_id)

    existing = supabase.fetch_note(user_id, "professional", note_id)
    if existing is None:
        raise ProfessionalNoteNotFound()
    if existing["connection"]["ended_at"] is not None:
        raise ProfessionalNoteConnectionEnded()

    row = supabase.update_note(note_id, content)
    if row is None:
        raise ProfessionalNoteNotFound()
    return _to_out(row, existing["connection"])


def delete_note(user_id: str, note_id: str) -> None:
    _require_active_profile(user_id)

    existing = supabase.fetch_note(user_id, "professional", note_id)
    if existing is None:
        raise ProfessionalNoteNotFound()
    if existing["connection"]["ended_at"] is not None:
        raise ProfessionalNoteConnectionEnded()

    if not supabase.soft_delete_note(note_id):
        raise ProfessionalNoteNotFound()


def list_notes(
    user_id: str,
    connection_id: Optional[str] = None,
    offset: Optional[int] = None,
    limit: Optional[int] = None,
) -> ProfessionalNoteListOut:
    role = _reader_role(user_id)

    if offset is None and limit is None:
        rows = supabase.list_notes_all(user_id, role, connection_id)
        return ProfessionalNoteListOut(
            notes=[_embedded_out(row) for row in rows],
            count=len(rows),
            offset=0,
            limit=len(rows),
            total=len(rows),
        )

    offset = offset or 0
    limit = limit or 20
    rows, total = supabase.list_notes(
        user_id, role, connection_id, offset, limit
    )
    return ProfessionalNoteListOut(
        notes=[_embedded_out(row) for row in rows],
        count=len(rows),
        offset=offset,
        limit=limit,
        total=total,
    )
