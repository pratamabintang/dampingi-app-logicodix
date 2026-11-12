from typing import Annotated, Optional
from uuid import UUID

from pydantic import BaseModel, Field, StringConstraints

CONTENT_MAX = 10_000

Content = Annotated[
    str,
    StringConstraints(
        strip_whitespace=True,
        min_length=1,
        max_length=CONTENT_MAX,
    ),
]


class ProfessionalNoteCreate(BaseModel):
    model_config = {"extra": "forbid"}

    connection_id: UUID = Field(
        description="The Professional's active Connection the note belongs to."
    )
    content: Content = Field(
        description="Note body (1-10000 chars after trimming)."
    )


class ProfessionalNoteUpdate(BaseModel):
    model_config = {"extra": "forbid"}

    content: Content = Field(
        description="New note body (1-10000 chars after trimming)."
    )


class ProfessionalNoteOut(BaseModel):
    id: str
    connection_id: str
    professional_id: str
    mother_id: str
    content: str
    created_at: str
    updated_at: str


class ProfessionalNoteListOut(BaseModel):
    notes: list[ProfessionalNoteOut]
    count: int
    offset: int
    limit: int
    total: int
