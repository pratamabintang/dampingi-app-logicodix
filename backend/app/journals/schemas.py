from typing import Optional

from pydantic import BaseModel, Field

TITLE_MAX = 255
CONTENT_MAX = 10_000


class JournalCreate(BaseModel):

    model_config = {"extra": "forbid"}

    title: str = Field(
        min_length=1,
        max_length=TITLE_MAX,
        description="Title of the Journal (1-255 chars).",
    )
    content: str = Field(
        min_length=1,
        max_length=CONTENT_MAX,
        description="Body of the Journal (1-10000 chars).",
    )
    created_at: Optional[str] = Field(
        default=None,
        description=(
            "Day the Journal belongs to, in YYYY-MM-DD (the Author's local "
            "calendar day). Omit for today. Past days may be backfilled; "
            "future days are rejected."
        ),
    )


class JournalOut(BaseModel):

    id: str
    user_id: str
    created_at: str
    title: str
    content: str


class JournalUpdate(BaseModel):

    model_config = {"extra": "forbid"}

    title: Optional[str] = Field(
        default=None,
        min_length=1,
        max_length=TITLE_MAX,
        description="New title (1-255 chars). Omit to leave it unchanged.",
    )
    content: Optional[str] = Field(
        default=None,
        min_length=1,
        max_length=CONTENT_MAX,
        description="New content (1-10000 chars). Omit to leave it unchanged.",
    )
    created_at: Optional[str] = Field(
        default=None,
        description=(
            "Ignored. A Journal's day is fixed when it is written; the day "
            "in the URL is the one that is edited."
        ),
    )


class JournalListOut(BaseModel):

    journals: list[JournalOut]
    count: int
    offset: int
    limit: int
    total: int
