from typing import Optional

from pydantic import BaseModel, Field


class MoodCreate(BaseModel):

    created_at: Optional[str] = Field(
        default=None,
        description=(
            "Day the Mood belongs to, in YYYY-MM-DD (the caller's local "
            "calendar day). Omit for today. Past days may be backfilled; "
            "future days are rejected."
        ),
    )
    mood: int = Field(ge=1, le=5, description="Mood on 1–5 scale (1=very low, 5=very good).")
    description: Optional[str] = Field(
        default=None, max_length=500, description="Optional contextual note (max 500 chars)."
    )


class MoodUpdate(BaseModel):

    model_config = {"extra": "forbid"}

    mood: Optional[int] = Field(
        default=None, ge=1, le=5, description="Mood on 1–5 scale (1=very low, 5=very good)."
    )
    description: Optional[str] = Field(
        default=None, max_length=500, description="Optional contextual note (max 500 chars)."
    )


class MoodOut(BaseModel):

    id: str
    user_id: str
    created_at: str
    mood: int
    description: Optional[str]


class MoodListOut(BaseModel):

    moods: list[MoodOut]
    count: int
    offset: int
    limit: int
    total: int
