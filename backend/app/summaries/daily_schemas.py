
from datetime import date
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class DailySourceRef(BaseModel):
    model_config = ConfigDict(extra="forbid")

    source_type: Literal[
        "mother_mood",
        "mother_journal",
        "mother_chat_message",
    ]
    source_id: str = Field(min_length=1)


class DailySummaryAIOut(BaseModel):
    model_config = ConfigDict(extra="forbid")

    overview: str | None = None
    limitations: list[str] = Field(default_factory=list)


class DailySummaryResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    summary_date: date
    status: Literal["completed", "partial"]
    overview: str | None = None
    limitations: list[str] = Field(default_factory=list)
    source_refs: list[DailySourceRef] = Field(default_factory=list)
    prompt_version: str = "daily-summary-v1"
    schema_version: str = "1"
