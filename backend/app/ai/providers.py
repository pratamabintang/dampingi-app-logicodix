import asyncio
import json
import logging
from typing import Any

from google import genai
from google.genai import errors as genai_errors
from google.genai import types

from .errors import AIBadOutput, AIBusy, AITimeout, AIUnavailable
from .gateway import Turn

logger = logging.getLogger(__name__)


class FakeProvider:
    """Mengembalikan jawaban yang sudah ditentukan. `calls` mencatat apa yang dikirim."""

    def __init__(
        self,
        reply: str = "Terima kasih sudah bercerita. Aku di sini untuk menemanimu.",
        *,
        urgent: bool = False,
        raw: str | None = None,
        response: dict | None = None,
        error: Exception | None = None,
        delay: float = 0.0,
    ):
        self.reply = reply
        self.urgent = urgent
        self.raw = raw
        self.response = response  # jawaban untuk skema selain chat, mis. {"overview": "..."}
        self.error = error
        self.delay = delay
        self.calls: list[tuple[str, list[Turn]]] = []
        self.schemas: list[dict[str, Any]] = []

    async def complete(self, system: str, turns: list[Turn], schema: dict[str, Any]) -> str:
        self.calls.append((system, list(turns)))
        self.schemas.append(schema)
        if self.delay:
            await asyncio.sleep(self.delay)
        if self.error:
            raise self.error
        if self.raw is not None:
            return self.raw
        if self.response is not None:
            return json.dumps(self.response)
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

    async def complete(self, system: str, turns: list[Turn], schema: dict[str, Any]) -> str:
        config = types.GenerateContentConfig(
            system_instruction=system,               # instruksi terpisah dari riwayat
            response_mime_type="application/json",   # paksa jawaban JSON...
            response_json_schema=schema,             # ...dengan bentuk yang diminta pemanggil
            temperature=self.temperature,
        )
        try:
            resp = await self.client.aio.models.generate_content(
                model=self.model, contents=[_to_content(t) for t in turns], config=config
            )
        except genai_errors.APIError as exc:
            # Catat kode dan status saja. Pesan error Google bisa memuat isi request.
            logger.warning("Gemini menolak permintaan: %s %s", exc.code, exc.status)
            if exc.code == 429:  # kuota / rate limit Gemini habis
                raise AIBusy() from exc
            if exc.code == 504:  # DEADLINE_EXCEEDED: Gemini kehabisan waktu di sisinya
                raise AITimeout() from exc
            raise AIUnavailable() from exc
        text = resp.text
        if not text:  # misalnya diblokir filter keamanan Gemini
            raise AIBadOutput()
        return text