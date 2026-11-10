from datetime import datetime
from typing import Literal, Optional
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator

MAX_MESSAGE_CHARS = 2000


class ChatRequest(BaseModel):
    """Pesan dari pengguna. Tanpa session_id = mulai percakapan baru."""

    model_config = ConfigDict(extra="forbid")

    message: str = Field(min_length=1, max_length=MAX_MESSAGE_CHARS)
    session_id: Optional[UUID] = None

    @field_validator("message")
    @classmethod
    def strip_and_require_text(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Pesan tidak boleh kosong.")
        return value


class ChatMessageOut(BaseModel):
    id: UUID
    role: Literal["user", "assistant"]
    content: str
    created_at: datetime


class ChatResponse(BaseModel):
    session_id: UUID
    user_message: ChatMessageOut
    reply: ChatMessageOut
    urgent: bool = False  # True = tampilkan kontak darurat di aplikasi
    context_used: list[Literal["mood_7d"]] = []  # data apa yang ikut dipakai AI (transparansi)


class ChatSessionOut(BaseModel):
    id: UUID
    title: str
    created_at: datetime
    updated_at: datetime


class ChatSessionListOut(BaseModel):
    sessions: list[ChatSessionOut]
    count: int


class ChatMessageListOut(BaseModel):
    messages: list[ChatMessageOut]
    count: int