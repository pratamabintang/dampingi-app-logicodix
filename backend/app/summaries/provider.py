import json
from google import genai
from google.genai import types
from app.summaries.prompts import SYSTEM_PROMPT

def generate_summary(
    *,
    moods: list[dict],
    period_start: str,
    period_end: str,
    api_key: str | None,
    model: str,
) -> str:
    if not api_key:
        raise RuntimeError("Gemini API key is not configured")

    client = genai.Client(api_key=api_key)

    payload = {
        "period_start": period_start,
        "period_end": period_end,
        "moods": moods,
    }

    response = client.models.generate_content(
        model=model,
        contents=(
            f"{SYSTEM_PROMPT}\n\n"
            "Summarize the following mood records:\n"
            f"{json.dumps(payload, ensure_ascii=False)}"
        ),
        config=types.GenerateContentConfig(
            temperature=0.2,
        ),
    )

    if not response.text or not response.text.strip():
        raise ValueError("Gemini returned an empty response")

    return response.text.strip()