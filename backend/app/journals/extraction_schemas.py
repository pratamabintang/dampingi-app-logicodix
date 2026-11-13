
from datetime import date
from typing import Literal

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    field_validator,
    model_validator,
)


class JournalExtractionInput(BaseModel):
    """One permitted journal supplied for theme extraction."""

    model_config = ConfigDict(extra="forbid")

    id: str = Field(min_length=1)
    title: str = Field(min_length=1)
    content: str = Field(min_length=1)
    date: date

    @field_validator("id", "title", "content")
    @classmethod
    def value_not_blank(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Value must not be blank")
        return value


class JournalTheme(BaseModel):
    """AI-interpreted theme linked to its source journal."""

    model_config = ConfigDict(extra="forbid")

    label: str = Field(min_length=1)
    source_journal_id: str = Field(min_length=1)

    @field_validator("label", "source_journal_id")
    @classmethod
    def value_not_blank(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Value must not be blank")
        return value


class JournalExtractionAIOut(BaseModel):
    """Structured output requested from the AI."""

    model_config = ConfigDict(extra="forbid")

    themes: list[JournalTheme] = Field(default_factory=list)


class JournalExtractionOut(BaseModel):
    """Validated result of journal theme extraction."""

    model_config = ConfigDict(extra="forbid")

    themes: list[JournalTheme] = Field(default_factory=list)
    processing_status: Literal["completed", "failed"]

    @model_validator(mode="after")
    def failed_result_has_no_themes(self):
        if self.processing_status == "failed" and self.themes:
            raise ValueError(
                "Failed extraction must not contain themes"
            )
        return self
