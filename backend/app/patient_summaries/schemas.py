from datetime import date

from pydantic import BaseModel, ConfigDict, Field, model_validator


class SharingPermissionsOut(BaseModel):
    connection_id: str
    weekly_summary: bool
    epds: bool
    journal: bool


class SharingPermissionsUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    weekly_summary: bool | None = None
    epds: bool | None = None
    journal: bool | None = None

    @model_validator(mode="after")
    def require_at_least_one_permission(self):
        fields = self.model_fields_set
        if not fields or any(getattr(self, field) is None for field in fields):
            raise ValueError("Provide at least one boolean permission")
        return self

    def changes(self) -> dict[str, bool]:
        return {
            f"share_{field}": getattr(self, field)
            for field in self.model_fields_set
        }


class PatientMoodOut(BaseModel):
    date: date
    mood: int = Field(ge=1, le=5)


class PatientJournalOut(BaseModel):
    id: str
    created_at: date
    title: str
    content: str


class PatientEPDSOut(BaseModel):
    date: date
    total_score: int = Field(ge=0, le=30)
    follow_up_required: bool
    immediate_review_required: bool
    disclaimer: str


class PatientSummaryOut(BaseModel):
    connection_id: str
    mother_name: str
    period_start: date
    period_end: date
    permissions: SharingPermissionsOut
    moods: list[PatientMoodOut]
    journals: list[PatientJournalOut]
    epds: list[PatientEPDSOut]
