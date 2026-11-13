
import asyncio
import json
from datetime import date, timedelta
from functools import lru_cache

from app.ai import AIGateway, AIError, Turn
from app.ai.config import build_gateway
from app.journals import service as journal_service
from app.journals.extraction import extract_journal_themes
from app.journals.extraction_schemas import JournalExtractionInput
from app.moods import service as mood_service
from app.summaries import supabase as summary_supabase
from app.summaries.aggregation import build_weekly_summary_input
from app.summaries.prompts import SYSTEM_PROMPT, WEEKLY_SUMMARY_PROMPT
from app.summaries.schemas import (
    Audience,
    MoodSummaryAIOut,
    MoodSummaryOut,
    MoodSummaryRequest,
    SummarySourceRef,
    WeeklySummaryAIOut,
    WeeklySummaryResponse,
)


@lru_cache(maxsize=1)
def get_summary_gateway() -> AIGateway:
    return build_gateway()


async def create_weekly_summary(
    user_id: str,
    request: MoodSummaryRequest,
) -> MoodSummaryOut:
    """Create a weekly mood summary from the mother's mood records."""

    period_start = request.period_start.isoformat()
    period_end = request.period_end.isoformat()

    mood_result = await asyncio.to_thread(
        mood_service.list_moods,
        user_id=user_id,
        start_date=period_start,
        end_date=period_end,
    )

    moods = mood_result.moods
    mood_count = mood_result.count

    if mood_count == 0:
        return MoodSummaryOut(
            status="insufficient_data",
            period_start=request.period_start,
            period_end=request.period_end,
            mood_count=0,
            overview=None,
        )

    mood_payload = {
        "period_start": period_start,
        "period_end": period_end,
        "moods": [
            {"date": mood.created_at, "mood": mood.mood}
            for mood in moods
        ],
    }

    try:
        result = await get_summary_gateway().generate(
            system=SYSTEM_PROMPT,
            turns=[
                Turn(
                    role="user",
                    content=json.dumps(
                        mood_payload,
                        ensure_ascii=False,
                    ),
                )
            ],
            output=MoodSummaryAIOut,
        )
    except AIError:
        return MoodSummaryOut(
            status="unavailable",
            period_start=request.period_start,
            period_end=request.period_end,
            mood_count=mood_count,
            overview=None,
        )

    return MoodSummaryOut(
        status="complete",
        period_start=request.period_start,
        period_end=request.period_end,
        mood_count=mood_count,
        overview=result.overview,
    )


def _persist_weekly_summary(
    user_id: str,
    summary: WeeklySummaryResponse,
) -> dict:
    """Persist a weekly summary for the authenticated mother."""

    payload = summary.model_dump(mode="json")
    payload["mother_id"] = user_id

    return summary_supabase.save_summary(payload)


def get_weekly_summary(
    user_id: str,
    period_start: date,
) -> WeeklySummaryResponse | None:
    """Retrieve a persisted weekly summary for the authenticated mother."""

    if period_start.weekday() != 0:
        raise ValueError("period_start must be a Monday")

    row = summary_supabase.get_summary(
        mother_id=user_id,
        period_start=period_start.isoformat(),
        audience=Audience.MOTHER.value,
    )

    if row is None:
        return None

    return WeeklySummaryResponse.model_validate(row)


async def create_weekly_summary_v2(
    user_id: str,
    period_start: date,
) -> WeeklySummaryResponse:
    """Create and persist a source-aware weekly summary."""

    if period_start.weekday() != 0:
        raise ValueError("period_start must be a Monday")

    period_end = period_start + timedelta(days=6)
    start_date = period_start.isoformat()
    end_date = period_end.isoformat()

    # Retrieve the authenticated mother's own records.
    mood_result = await asyncio.to_thread(
        mood_service.list_moods,
        user_id=user_id,
        start_date=start_date,
        end_date=end_date,
    )

    journal_result = await asyncio.to_thread(
        journal_service.list_journals,
        user_id=user_id,
        start_date=start_date,
        end_date=end_date,
    )

    mood_entries = [
        {
            "id": mood.id,
            "created_at": mood.created_at,
            "mood": mood.mood,
        }
        for mood in mood_result.moods
    ]

    limitations = []
    summary_journal_items = []
    journal_source_refs = []

    # Extract themes from the mother's journals.
    if journal_result.journals:
        journal_inputs = [
            JournalExtractionInput(
                id=journal.id,
                title=journal.title,
                content=journal.content,
                date=date.fromisoformat(
                    journal.created_at[:10]
                ),
            )
            for journal in journal_result.journals
        ]

        extraction = await extract_journal_themes(journal_inputs)

        if extraction.processing_status == "failed":
            limitations.append(
                "Tema jurnal tidak dapat diproses saat ini."
            )

        elif not extraction.themes:
            limitations.append(
                "Tidak ada tema jurnal yang dapat diidentifikasi."
            )

        else:
            journals_by_id = {
                journal.id: journal
                for journal in journal_inputs
            }

            themes_by_journal = {}

            for theme in extraction.themes:
                themes_by_journal.setdefault(
                    theme.source_journal_id,
                    [],
                ).append(theme.label)

            for journal_id, themes in themes_by_journal.items():
                journal = journals_by_id[journal_id]

                # Send extracted themes only, never raw journal content.
                summary_journal_items.append(
                    {
                        "id": journal.id,
                        "created_at": journal.date.isoformat(),
                        "themes": themes,
                    }
                )

                journal_source_refs.append(
                    SummarySourceRef(
                        source_type="mother_journal",
                        source_id=journal.id,
                    )
                )

    summary_input = build_weekly_summary_input(
        period_start=period_start,
        audience=Audience.MOTHER,
        mood_entries=mood_entries,
        journal_items=summary_journal_items,
    )

    mood_source_refs = [
        SummarySourceRef(
            source_type="mother_mood",
            source_id=mood.id,
        )
        for mood in mood_result.moods
    ]

    source_refs = mood_source_refs + journal_source_refs

    if summary_input.coverage.mood_days < 7:
        limitations.append(
            "Catatan mood tersedia pada "
            f"{summary_input.coverage.mood_days} dari 7 hari."
        )

    # Do not call AI when there is no usable source.
    if not mood_entries and not summary_journal_items:
        limitations.append(
            "Tidak ada catatan mood atau tema jurnal "
            "yang dapat digunakan pada periode ini."
        )

        summary = WeeklySummaryResponse(
            period_start=period_start,
            period_end=end_date,
            audience=Audience.MOTHER,
            status="partial",
            overview=None,
            limitations=limitations,
            source_refs=source_refs,
            prompt_version="weekly-summary-v2",
        )

        _persist_weekly_summary(user_id, summary)
        return summary

    # Generate the weekly summary.
    try:
        result = await get_summary_gateway().generate(
            system=WEEKLY_SUMMARY_PROMPT,
            turns=[
                Turn(
                    role="user",
                    content=summary_input.model_dump_json(),
                )
            ],
            output=WeeklySummaryAIOut,
        )

    except AIError:
        summary = WeeklySummaryResponse(
            period_start=period_start,
            period_end=end_date,
            audience=Audience.MOTHER,
            status="partial",
            overview=None,
            limitations=limitations + [
                "Ringkasan AI tidak tersedia saat ini."
            ],
            source_refs=source_refs,
            prompt_version="weekly-summary-v2",
        )

        _persist_weekly_summary(user_id, summary)
        return summary

    limitations.extend(result.limitations)

    summary = WeeklySummaryResponse(
        period_start=period_start,
        period_end=end_date,
        audience=Audience.MOTHER,
        status="completed" if result.overview else "partial",
        overview=result.overview,
        limitations=limitations,
        source_refs=source_refs,
        prompt_version="weekly-summary-v2",
    )

    _persist_weekly_summary(user_id, summary)
    return summary
