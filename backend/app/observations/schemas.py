from datetime import date
from typing import Annotated, Literal, Optional
from uuid import UUID

from pydantic import BaseModel, Field, StringConstraints

QUESTION_MIN = 1
QUESTION_MAX = 50
OPTION_MIN = 2
OPTION_MAX = 10
PROMPT_MAX = 1_000
OPTION_LABEL_MAX = 500

Prompt = Annotated[
    str,
    StringConstraints(
        strip_whitespace=True,
        min_length=1,
        max_length=PROMPT_MAX,
    ),
]
OptionLabel = Annotated[
    str,
    StringConstraints(
        strip_whitespace=True,
        min_length=1,
        max_length=OPTION_LABEL_MAX,
    ),
]


class ObservationOptionCreate(BaseModel):

    model_config = {"extra": "forbid"}

    label: OptionLabel = Field(
        description="Option label (1-500 chars after trimming)."
    )


class ObservationQuestionCreate(BaseModel):

    model_config = {"extra": "forbid"}

    prompt: Prompt = Field(
        description="Question text (1-1000 chars after trimming)."
    )
    options: list[ObservationOptionCreate] = Field(
        min_length=OPTION_MIN,
        max_length=OPTION_MAX,
        description="Answer options (2-10).",
    )


class ObservationCreate(BaseModel):

    model_config = {"extra": "forbid"}

    mother_id: UUID = Field(description="The Mother this Observation is about.")
    questions: list[ObservationQuestionCreate] = Field(
        min_length=QUESTION_MIN,
        max_length=QUESTION_MAX,
        description="Question set (1-50 questions).",
    )


class ObservationAnswerIn(BaseModel):

    model_config = {"extra": "forbid"}

    question_id: str = Field(
        min_length=1,
        max_length=64,
        description="Stored question ID (e.g. q1).",
    )
    option_id: str = Field(
        min_length=1,
        max_length=64,
        description="Stored option ID belonging to that question (e.g. q1o1).",
    )


class ObservationSubmit(BaseModel):

    model_config = {"extra": "forbid"}

    answers: list[ObservationAnswerIn] = Field(
        min_length=QUESTION_MIN,
        max_length=QUESTION_MAX,
        description="One answer per stored question.",
    )
    day: date = Field(
        description=(
            "The Day the Observation belongs to, in the Mother's local "
            "calendar. Past days may be backfilled; future days are rejected."
        )
    )


class ObservationOptionOut(BaseModel):

    id: str
    label: str


class ObservationQuestionOut(BaseModel):

    id: str
    prompt: str
    options: list[ObservationOptionOut]


class ObservationAnswerOut(BaseModel):

    question_id: str
    option_id: str


class ObservationOut(BaseModel):

    id: str
    connection_id: str
    companion_id: str
    mother_id: str
    questions: list[ObservationQuestionOut]
    answers: Optional[list[ObservationAnswerOut]]
    day: Optional[str]
    completed_at: Optional[str]
    created_at: str
    status: Literal["draft", "completed"]


class ObservationListOut(BaseModel):

    observations: list[ObservationOut]
    count: int
    offset: int
    limit: int
    total: int
