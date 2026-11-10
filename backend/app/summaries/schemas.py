from datetime import date
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class MoodSummaryInput(BaseModel):
    """Privacy-minimized mood data sent to the summary provider."""

    model_config = ConfigDict(extra="forbid")

    date: date
    mood: int = Field(ge=1, le=5)


class MoodSummaryRequest(BaseModel):
    """Input used by the weekly summary service."""

    model_config = ConfigDict(extra="forbid")

    period_start: date
    period_end: date
    moods: list[MoodSummaryInput]


class MoodSummaryOut(BaseModel):
    """Public response for a weekly mood summary."""

    model_config = ConfigDict(extra="forbid")

    status: Literal["complete", "insufficient_data", "unavailable"]
    period_start: date
    period_end: date
    mood_count: int = Field(ge=0)
    overview: str | None = None
