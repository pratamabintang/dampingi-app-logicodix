from datetime import date, timedelta

from app.connections import supabase as connections_supabase
from app.epds import supabase as epds_supabase
from app.journals import supabase as journals_supabase
from app.moods import supabase as moods_supabase
from app.patient_summaries.schemas import (
    PatientEPDSOut,
    PatientJournalOut,
    PatientMoodOut,
    PatientSummaryOut,
    SharingPermissionsOut,
)


class PatientSummaryConnectionNotFound(Exception):
    pass


def get_sharing_permissions(
    mother_id: str, connection_id: str
) -> SharingPermissionsOut:
    connection = connections_supabase.fetch_professional_connection_for_mother(
        mother_id, connection_id
    )
    if connection is None:
        raise PatientSummaryConnectionNotFound()
    return _permissions(connection)


def update_sharing_permissions(
    mother_id: str,
    connection_id: str,
    changes: dict[str, bool],
) -> SharingPermissionsOut:
    connection = connections_supabase.update_professional_sharing_permissions(
        mother_id, connection_id, changes
    )
    if connection is None:
        raise PatientSummaryConnectionNotFound()
    return _permissions(connection)


def get_patient_summary(
    professional_id: str,
    connection_id: str,
    period_start: date,
) -> PatientSummaryOut:
    if period_start.weekday() != 0:
        raise ValueError("period_start must be a Monday")

    connection = connections_supabase.fetch_active_professional_connection(
        professional_id, connection_id
    )
    if connection is None:
        raise PatientSummaryConnectionNotFound()

    period_end = period_start + timedelta(days=6)
    start = period_start.isoformat()
    end = period_end.isoformat()
    permissions = _permissions(connection)
    mother_id = connection["mother_id"]

    moods: list[PatientMoodOut] = []
    if permissions.weekly_summary:
        rows, _ = moods_supabase.list_moods_all(mother_id, start, end)
        moods = [
            PatientMoodOut(date=_row_date(row["created_at"]), mood=row["mood"])
            for row in rows
        ]

    journals: list[PatientJournalOut] = []
    if permissions.journal:
        rows, _ = journals_supabase.list_journals_all(
            mother_id, start, end
        )
        journals = [
            PatientJournalOut(
                id=row["id"],
                created_at=_row_date(row["created_at"]),
                title=row["title"],
                content=row["content"],
            )
            for row in rows
        ]

    epds: list[PatientEPDSOut] = []
    if permissions.epds:
        rows, _ = epds_supabase.list_assessments(
            mother_id=mother_id,
            offset=0,
            limit=100,
            start_date=start,
            end_date=(period_end + timedelta(days=1)).isoformat(),
        )
        epds = [
            PatientEPDSOut(
                date=_row_date(row["created_at"]),
                total_score=row["total_score"],
                follow_up_required=row["follow_up_required"],
                immediate_review_required=row["immediate_review_required"],
                disclaimer=row["disclaimer"],
            )
            for row in rows
        ]

    mother = connection.get("mother")
    mother_name = mother.get("name") if isinstance(mother, dict) else None
    return PatientSummaryOut(
        connection_id=connection_id,
        mother_name=mother_name or "Pasien",
        period_start=period_start,
        period_end=period_end,
        permissions=permissions,
        moods=moods,
        journals=journals,
        epds=epds,
    )


def _permissions(connection: dict) -> SharingPermissionsOut:
    return SharingPermissionsOut(
        connection_id=connection["id"],
        weekly_summary=connection["share_weekly_summary"],
        epds=connection["share_epds"],
        journal=connection["share_journal"],
    )


def _row_date(value: str) -> date:
    return date.fromisoformat(value[:10])
