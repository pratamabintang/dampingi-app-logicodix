import asyncio
import logging
from dataclasses import dataclass
from typing import Literal, Protocol

from pydantic import BaseModel, ConfigDict, ValidationError, field_validator

from .errors import AIBadOutput, AIError, AITimeout, AIUnavailable

logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class Turn:
    """Satu pesan dalam riwayat percakapan yang dikirim ke AI."""

    role: Literal["user", "assistant"]
    content: str


class AIReply(BaseModel):
    """Bentuk jawaban AI yang WAJIB dipenuhi. Selain ini dianggap gagal."""

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


# Skema yang sama, dalam format JSON Schema untuk dikirim ke OpenAI (structured output).
REPLY_JSON_SCHEMA: dict[str, object] = {
    "type": "object",
    "properties": {
        "reply": {"type": "string"},
        "urgent": {"type": "boolean"},
    },
    "required": ["reply", "urgent"],
    "additionalProperties": False,
}


class AIProvider(Protocol):
    """Colokan provider. Mengembalikan teks JSON mentah."""

    async def complete(self, system: str, turns: list[Turn]) -> str: ...


class AIGateway:
    def __init__(self, provider: AIProvider, timeout_s: float = 20.0):
        self.provider = provider
        self.timeout_s = timeout_s

    async def reply(self, system: str, turns: list[Turn]) -> AIReply:
        try:
            raw = await asyncio.wait_for(self.provider.complete(system, turns), self.timeout_s)
        except TimeoutError as exc:
            raise AITimeout() from exc
        except AIError:
            raise
        except Exception as exc:
            # Catat jenis error saja: pesan error bisa memuat isi request.
            logger.warning("AI provider gagal: %s", type(exc).__name__)
            raise AIUnavailable() from exc

        try:
            return AIReply.model_validate_json(raw)
        except ValidationError as exc:
            raise AIBadOutput() from exc