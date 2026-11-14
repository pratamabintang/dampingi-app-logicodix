import asyncio
import json
import logging
from typing import Any

import httpx
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


def _with_schema(system: str, schema: dict[str, Any]) -> str:
    """Skema JSON dititipkan di instruksi sistem.

    Protokol OpenAI tidak punya parameter skema yang seragam antar gateway, jadi
    bentuk jawaban diminta lewat prompt; validasinya tetap di AIGateway.
    """
    return (
        f"{system}\n\n"
        "Balas HANYA JSON yang memenuhi skema berikut, tanpa penjelasan dan tanpa pagar kode:\n"
        f"{json.dumps(schema, ensure_ascii=False, separators=(',', ':'))}"
    )


def _first_content(payload: Any) -> str:
    try:
        content = payload["choices"][0]["message"]["content"]
    except (KeyError, IndexError, TypeError) as exc:
        raise AIBadOutput() from exc
    if isinstance(content, list):  # sebagian gateway mengirim potongan
        content = "".join(part.get("text", "") for part in content if isinstance(part, dict))
    if not isinstance(content, str) or not content.strip():
        raise AIBadOutput()
    return content


class OpenAICompatProvider:
    """Provider pihak ketiga yang bicara protokol OpenAI `/chat/completions`.

    Cukup OpenAI-compatible: base URL, kunci, dan nama model datang dari .env.
    """

    def __init__(self, client: httpx.AsyncClient, model: str, temperature: float = 0.4):
        self.client = client
        self.model = model
        self.temperature = temperature

    async def complete(self, system: str, turns: list[Turn], schema: dict[str, Any]) -> str:
        body = {
            "model": self.model,
            "messages": [
                {"role": "system", "content": _with_schema(system, schema)},
                *({"role": turn.role, "content": turn.content} for turn in turns),
            ],
            "response_format": {"type": "json_object"},  # tanpa ini jawaban dibungkus ```json
            "temperature": self.temperature,
        }
        try:
            resp = await self.client.post("chat/completions", json=body)
            resp.raise_for_status()
        except httpx.TimeoutException as exc:
            raise AITimeout() from exc
        except httpx.HTTPStatusError as exc:
            # Catat kode saja. Pesan error gateway bisa memuat isi request.
            logger.warning("Provider AI menolak permintaan: %s", exc.response.status_code)
            if exc.response.status_code == 429:  # kuota / rate limit habis
                raise AIBusy() from exc
            if exc.response.status_code == 504:  # gateway kehabisan waktu di sisinya
                raise AITimeout() from exc
            raise AIUnavailable() from exc
        except httpx.HTTPError as exc:
            logger.warning("Provider AI tidak bisa dihubungi: %s", type(exc).__name__)
            raise AIUnavailable() from exc
        try:
            payload = resp.json()
        except ValueError as exc:  # gateway membalas bukan JSON
            raise AIBadOutput() from exc
        return _first_content(payload)