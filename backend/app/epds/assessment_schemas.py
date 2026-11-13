
from pydantic import BaseModel, ConfigDict, Field
from typing import Literal


class EPDSAssessmentOut(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id: str
    mother_id: str
    instrument: str
    instrument_version: str
    evaluation_mode: Literal["demo_only"]
    answers: list[dict]
    total_score: int = Field(ge=0, le=30)
    follow_up_required: bool
    item10_positive: bool
    immediate_review_required: bool
    rules_version: str
    disclaimer: str
    created_at: str


class EPDSAssessmentListOut(BaseModel):
    model_config = ConfigDict(extra="forbid")

    items: list[EPDSAssessmentOut]
    total: int
    offset: int
    limit: int


class EPDSAlertOut(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id: str
    mother_id: str
    assessment_id: str | None
    alert_type: Literal[
        "demo_follow_up",
        "demo_immediate_review",
    ]
    evaluation_mode: Literal["demo_only"]
    message: str
    created_at: str
    read_at: str | None


class EPDSAlertListOut(BaseModel):
    model_config = ConfigDict(extra="forbid")

    items: list[EPDSAlertOut]
    total: int
    offset: int
    limit: int


class EPDSAssessmentSubmitOut(BaseModel):
    model_config = ConfigDict(extra="forbid")

    assessment: EPDSAssessmentOut
    alerts: list[EPDSAlertOut]
