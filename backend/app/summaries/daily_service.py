
import asyncio
import json
import logging
from datetime import date, datetime, time, timedelta, timezone

from app.ai import AIError, Turn
from app.chat.store import SupabaseChatStore
from app.journals import service as journal_service
from app.journals.extraction import extract_journal_themes
from app.journals.extraction_schemas import JournalExtractionInput
from app.moods import service as mood_service
from app.shared.day import today_for, zone_of
from app.shared.profile import active_profile
from app.summaries import daily_supabase
from app.summaries.daily_prompts import (
    DAILY_SUMMARY_PROMPT,
    SYSTEM_PROMPT,
)
from app.summaries.daily_schemas import (
    DailySourceRef,
    DailySummaryAIOut,
    DailySummaryResponse,
)
from app.summaries.service import get_summary_gateway

logger = logging.getLogger(__name__)

PROMPT_VERSION = "daily-summary-v1"


async def create_daily_summary(
    user_id: str,
    summary_date: date | None = None,
    chat_store=None,
) -> DailySummaryResponse:
    profile = await asyncio.to_thread(active_profile, user_id)

    if not profile:
        raise ValueError("Active mother profile not found")

    if summary_date is None:
        summary_date = today_for(profile)

    day = summary_date.isoformat()

    # Rentang satu hari berdasarkan timezone ibu.
    zone = zone_of(profile)
    local_start = datetime.combine(
        summary_date, time.min, tzinfo=zone
    )
    local_end = datetime.combine(
        summary_date + timedelta(days=1),
        time.min,
        tzinfo=zone,
    )

    start_utc = local_start.astimezone(timezone.utc)
    end_utc = local_end.astimezone(timezone.utc)

    # Ambil mood dan jurnal milik ibu pada tanggal tersebut.
    mood_result, journal_result = await asyncio.gather(
        asyncio.to_thread(
            mood_service.list_moods,
            user_id=user_id,
            start_date=day,
            end_date=day,
        ),
        asyncio.to_thread(
            journal_service.list_journals,
            user_id=user_id,
            start_date=day,
            end_date=day,
        ),
    )

    # Ambil seluruh percakapan ibu pada hari lokal tersebut.
    store = chat_store or SupabaseChatStore()
    messages = await asyncio.to_thread(
        store.messages_between,
        user_id,
        start_utc,
        end_utc,
    )

    mood_items = [
        {
            "id": mood.id,
            "mood": mood.mood,
            "description": mood.description,
        }
        for mood in mood_result.moods
    ]

    source_refs = [
        DailySourceRef(
            source_type="mother_mood",
            source_id=mood.id,
        )
        for mood in mood_result.moods
    ]

    limitations = []
    journal_items = []

    # Ekstrak tema jurnal. Konten mentah tidak dikirim
    # ke AI penyusun ringkasan akhir.
    if journal_result.journals:
        journal_inputs = [
            JournalExtractionInput(
                id=journal.id,
                title=journal.title,
                content=journal.content,
                date=date.fromisoformat(journal.created_at[:10]),
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
            themes_by_id = {}

            for theme in extraction.themes:
                themes_by_id.setdefault(
                    theme.source_journal_id, []
                ).append(theme.label)

            journals_by_id = {
                journal.id: journal
                for journal in journal_inputs
            }

            for journal_id, themes in themes_by_id.items():
                journal = journals_by_id.get(journal_id)

                if not journal:
                    continue

                journal_items.append({
                    "id": journal_id,
                    "date": journal.date.isoformat(),
                    "themes": themes,
                })

                source_refs.append(
                    DailySourceRef(
                        source_type="mother_journal",
                        source_id=journal_id,
                    )
                )

    # Pesan assistant hanya konteks percakapan.
    # Source refs chat hanya menunjuk pesan ibu.
    chat_items = [
        {
            "role": message["role"],
            "content": message["content"],
        }
        for message in messages
        if message["role"] in ("user", "assistant")
    ]

    user_messages = [
        message for message in messages
        if message["role"] == "user"
    ]

    source_refs.extend(
        DailySourceRef(
            source_type="mother_chat_message",
            source_id=message["id"],
        )
        for message in user_messages
    )

    # Tidak memanggil AI jika tidak ada sumber yang dapat digunakan.
    if not mood_items and not journal_items and not user_messages:
        limitations.append(
            "Belum ada data mood, tema jurnal, atau percakapan "
            "yang dapat digunakan pada tanggal ini."
        )

        summary = DailySummaryResponse(
            summary_date=summary_date,
            status="partial",
            overview=None,
            limitations=limitations,
            source_refs=source_refs,
            prompt_version=PROMPT_VERSION,
        )

        daily_supabase.save_daily_summary({
            **summary.model_dump(mode="json"),
            "mother_id": user_id,
        })
        return summary

    payload = {
        "summary_date": day,
        "moods": mood_items,
        "journal_themes": journal_items,
        "chat_messages": chat_items,
    }

    try:
        result = await get_summary_gateway().generate(
            system=SYSTEM_PROMPT,
            turns=[
                Turn(
                    role="user",
                    content=(
                        DAILY_SUMMARY_PROMPT
                        + "\n\n"
                        + json.dumps(payload, ensure_ascii=False)
                    ),
                )
            ],
            output=DailySummaryAIOut,
        )
    except AIError as exc:
        logger.warning(
            "Daily summary AI gagal: %s",
            type(exc).__name__,
        )

        summary = DailySummaryResponse(
            summary_date=summary_date,
            status="partial",
            overview=None,
            limitations=limitations + [
                "Ringkasan AI tidak tersedia saat ini."
            ],
            source_refs=source_refs,
            prompt_version=PROMPT_VERSION,
        )
    else:
        limitations.extend(result.limitations)

        summary = DailySummaryResponse(
            summary_date=summary_date,
            status="completed" if result.overview else "partial",
            overview=result.overview,
            limitations=limitations,
            source_refs=source_refs,
            prompt_version=PROMPT_VERSION,
        )

    daily_supabase.save_daily_summary({
        **summary.model_dump(mode="json"),
        "mother_id": user_id,
    })

    return summary


def get_daily_summary(user_id, summary_date):
    row = daily_supabase.get_daily_summary(
        mother_id=user_id,
        summary_date=summary_date.isoformat(),
    )
    if row is None:
        return None

    response_fields = DailySummaryResponse.model_fields
    return DailySummaryResponse.model_validate({
        key: value
        for key, value in row.items()
        if key in response_fields
    })

async def refresh_daily_summary_background(user_id, summary_date):
    try:
        await create_daily_summary(
            user_id=user_id,
            summary_date=date.fromisoformat(summary_date),
        )
    except Exception:
        logger.exception("Gagal memperbarui Daily Summary secara background.")