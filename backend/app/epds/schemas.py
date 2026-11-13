
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator


EPDS_ITEM_IDS = tuple(f"Q{i}" for i in range(1, 11))


class EPDSAnswer(BaseModel):
    model_config = ConfigDict(extra="forbid")

    item_id: Literal[
        "Q1", "Q2", "Q3", "Q4", "Q5",
        "Q6", "Q7", "Q8", "Q9", "Q10",
    ]
    option_index: int = Field(ge=0, le=3)


class EPDSEvaluateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    answers: list[EPDSAnswer] = Field(
        min_length=10,
        max_length=10,
    )

    @model_validator(mode="after")
    def validate_answers(self):
        submitted_ids = [answer.item_id for answer in self.answers]

        if len(set(submitted_ids)) != 10:
            raise ValueError("Each EPDS item must appear exactly once")

        if set(submitted_ids) != set(EPDS_ITEM_IDS):
            raise ValueError("All EPDS items Q1-Q10 are required")

        return self


class EPDSEvaluateResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    evaluation_mode: Literal["demo_only"] = "demo_only"
    instrument: Literal["EPDS-10"] = "EPDS-10"
    rules_version: str
    total_score: int = Field(ge=0, le=30)
    follow_up_required: bool
    item10_positive: bool
    immediate_review_required: bool
    disclaimer: str
