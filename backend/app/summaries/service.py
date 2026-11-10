from app.config import get_settings
from app.moods import service as mood_service

from app.summaries.provider import generate_summary
from app.summaries.schemas import MoodSummaryOut, MoodSummaryRequest


def create_weekly_summary(
    user_id: str,
    request: MoodSummaryRequest,
) -> MoodSummaryOut:
    period_start = request.period_start.isoformat()
    period_end = request.period_end.isoformat()

    moods = mood_service.list_moods(
        user_id=user_id,
        start_date=period_start,
        end_date=period_end,
    )

    mood_count = len(moods)

    if mood_count == 0:
        return MoodSummaryOut(
            status="insufficient_data",
            period_start=request.period_start,
            period_end=request.period_end,
            mood_count=0,
            overview=None,
        )

    # Only send dates and numeric mood scores to the AI provider.
    mood_payload = [
        {
            "date": mood.created_at,
            "mood": mood.mood,
        }
        for mood in moods
    ]

    settings = get_settings()

    try:
        overview = generate_summary(
            moods=mood_payload,
            period_start=period_start,
            period_end=period_end,
            api_key=settings.gemini_api_key,
            model=settings.gemini_model,
        )

        if not overview or not overview.strip():
            raise ValueError("Empty summary")

    except Exception:
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
        overview=overview.strip(),
    )