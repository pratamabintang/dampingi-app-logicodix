import asyncio
import json
from functools import lru_cache
from app.ai import AIGateway, AIError, Turn
from app.ai.config import build_gateway
from app.moods import service as mood_service
from app.summaries.prompts import SYSTEM_PROMPT
from app.summaries.schemas import (
    MoodSummaryAIOut,
    MoodSummaryOut,
    MoodSummaryRequest,
)

@lru_cache(maxsize=1)
def get_summary_gateway() -> AIGateway:
    return build_gateway()

async def create_weekly_summary(
    user_id: str,
    request: MoodSummaryRequest,
) -> MoodSummaryOut:
    """Create a weekly mood summary from the authenticated mother's mood records."""

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
                    content=json.dumps(mood_payload, ensure_ascii=False),
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
