import asyncio
import json

from google import genai
from google.genai import types

from .errors import AIBadOutput
from .gateway import REPLY_JSON_SCHEMA, Turn


class FakeProvider:
    """Mengembalikan jawaban yang sudah ditentukan. `calls` mencatat apa yang dikirim."""

    def __init__(
        self,
        reply: str = "Terima kasih sudah bercerita. Aku di sini untuk menemanimu.",
        *,
        urgent: bool = False,
        raw: str | None = None,
        error: Exception | None = None,
        delay: float = 0.0,
    ):
        self.reply = reply
        self.urgent = urgent
        self.raw = raw
        self.error = error
        self.delay = delay
        self.calls: list[tuple[str, list[Turn]]] = []

    async def complete(self, system: str, turns: list[Turn]) -> str:
        self.calls.append((system, list(turns)))
        if self.delay:
            await asyncio.sleep(self.delay)
        if self.error:
            raise self.error
        if self.raw is not None:
            return self.raw
        return json.dumps({"reply": self.reply, "urgent": self.urgent})


def _to_content(turn: Turn) -> types.Content:
    # Gemini menamai jawaban AI "model", bukan "assistant".
    role = "model" if turn.role == "assistant" else "user"
    return types.Content(role=role, parts=[types.Part(text=turn.content)])


class GeminiProvider:
    """Memakai SDK google-genai (sama dengan fitur ringkasan mingguan D)."""

    def __init__(self, client: genai.Client, model: str, temperature: float = 0.4):
        self.client = client
        self.model = model
        self.temperature = temperature

    async def complete(self, system: str, turns: list[Turn]) -> str:
        config = types.GenerateContentConfig(
            system_instruction=system,               # instruksi terpisah dari riwayat
            response_mime_type="application/json",   # paksa jawaban JSON...
            response_json_schema=REPLY_JSON_SCHEMA,  # ...dengan bentuk {reply, urgent}
            temperature=self.temperature,
        )
        resp = await self.client.aio.models.generate_content(
            model=self.model, contents=[_to_content(t) for t in turns], config=config
        )
        text = resp.text
        if not text:  # misalnya diblokir filter keamanan Gemini
            raise AIBadOutput()
        return text