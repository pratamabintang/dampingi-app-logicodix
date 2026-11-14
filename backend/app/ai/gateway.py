import asyncio
import logging
from dataclasses import dataclass
from typing import Any, Literal, Protocol, TypeVar

from pydantic import BaseModel, ConfigDict, ValidationError, field_validator

from .errors import AIBadOutput, AIError, AITimeout, AIUnavailable

logger = logging.getLogger(__name__)

T = TypeVar("T", bound=BaseModel)


@dataclass(frozen=True)
class Turn:
    """Satu pesan dalam riwayat percakapan yang dikirim ke AI."""

    role: Literal["user", "assistant"]
    content: str


class AIReply(BaseModel):
    """Bentuk jawaban chatbot yang WAJIB dipenuhi. Selain ini dianggap gagal."""

    model_config = ConfigDict(extra="forbid")

    reply: str
    urgent: bool  # True = pesan pengguna menunjukkan tanda bahaya -> aplikasi tampilkan kontak darurat

    @field_validator("reply")
    @classmethod
    def reply_not_blank(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("jawaban kosong")
        return value


# Skema yang sama, dalam format JSON Schema untuk dikirim ke Gemini (structured output).
REPLY_JSON_SCHEMA: dict[str, Any] = {
    "type": "object",
    "properties": {
        "reply": {"type": "string"},
        "urgent": {"type": "boolean"},
    },
    "required": ["reply", "urgent"],
    "additionalProperties": False,
}


def _strip_titles(node: Any) -> Any:
    if isinstance(node, dict):
        return {k: _strip_titles(v) for k, v in node.items() if k != "title"}
    if isinstance(node, list):
        return [_strip_titles(v) for v in node]
    return node


def json_schema_for(output: type[BaseModel]) -> dict[str, Any]:
    """JSON Schema dari model Pydantic, tanpa `title` (tidak berguna untuk model AI)."""
    return _strip_titles(output.model_json_schema())


class AIProvider(Protocol):
    """Colokan provider. Mengembalikan teks JSON mentah yang mengikuti `schema`."""

    async def complete(self, system: str, turns: list[Turn], schema: dict[str, Any]) -> str: ...


class AIGateway:
    def __init__(self, provider: AIProvider, timeout_s: float = 20.0):
        self.provider = provider
        self.timeout_s = timeout_s

    async def generate(
        self,
        system: str,
        turns: list[Turn],
        output: type[T],
        schema: dict[str, Any] | None = None,
    ) -> T:
        """Panggil AI dan kembalikan jawaban sebagai objek `output` yang sudah divalidasi.

        `schema` default-nya diturunkan dari `output`; isi sendiri kalau perlu skema khusus.
        """
        schema = schema if schema is not None else json_schema_for(output)
        try:
            raw = await asyncio.wait_for(self.provider.complete(system, turns, schema), self.timeout_s)
        except asyncio.TimeoutError as exc:
            # Pakai asyncio.TimeoutError, bukan TimeoutError: di Python 3.10 keduanya berbeda
            # dan wait_for melempar versi asyncio. Sejak 3.11 keduanya kelas yang sama.
            raise AITimeout() from exc
        except AIError:
            raise
        except Exception as exc:
            # Catat jenis error saja: pesan error bisa memuat isi request.
            logger.warning("AI provider gagal: %s", type(exc).__name__)
            raise AIUnavailable() from exc

        try:
            return output.model_validate_json(raw)
        except ValidationError as exc:
            errors = [
                {
                    "loc": error["loc"],
                    "type": error["type"],
                }
                for error in exc.errors(include_input=False)
            ]
            logger.warning(
                "AI output tidak sesuai schema %s: %s",
                output.__name__,
                errors,
            )
            raise AIBadOutput() from exc

    async def reply(self, system: str, turns: list[Turn]) -> AIReply:
        """Khusus chat. Perilakunya sama persis seperti sebelum `generate` ada."""
        return await self.generate(system, turns, AIReply, REPLY_JSON_SCHEMA)