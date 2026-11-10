"""Alur chat: cek sesi -> ambil riwayat -> tanya AI -> simpan. Tidak tahu soal HTTP."""
import asyncio

from app.ai import AIGateway, Turn

from .prompts import get_prompt
from .schemas import (
    ChatMessageListOut,
    ChatMessageOut,
    ChatRequest,
    ChatResponse,
    ChatSessionListOut,
    ChatSessionOut,
)
from .store import ChatStore

HISTORY_LIMIT = 10        # pesan terakhir yang dikirim ke AI
HISTORY_MAX_CHARS = 6000  # dan total karakternya (hemat biaya, NFR minimasi data)
TITLE_MAX = 60
SESSIONS_LIMIT = 50
MESSAGES_LIMIT = 200


class SessionNotFound(Exception):
    pass


def trim_history(rows: list[dict], max_chars: int = HISTORY_MAX_CHARS) -> list[dict]:
    """Ambil pesan TERBARU sebanyak mungkin tanpa melewati max_chars."""
    kept, total = [], 0
    for row in reversed(rows):
        total += len(row["content"])
        if total > max_chars:
            break
        kept.append(row)
    return list(reversed(kept))


def make_title(message: str) -> str:
    title = " ".join(message.split())
    return title if len(title) <= TITLE_MAX else title[: TITLE_MAX - 1].rstrip() + "…"


class ChatService:
    def __init__(self, store: ChatStore, gateway: AIGateway):
        self.store = store
        self.gateway = gateway

    async def send(self, user_id: str, role: str, req: ChatRequest) -> ChatResponse:
        history: list[dict] = []
        session_id = str(req.session_id) if req.session_id else None

        if session_id:
            if await asyncio.to_thread(self.store.get_session, user_id, session_id) is None:
                raise SessionNotFound()  # tidak ada ATAU milik orang lain: jawabannya sama
            history = await asyncio.to_thread(self.store.recent_messages, user_id, session_id, HISTORY_LIMIT)

        _version, system = get_prompt(role)
        turns = [Turn(r["role"], r["content"]) for r in trim_history(history)]
        turns.append(Turn("user", req.message))

        # AI dulu, simpan belakangan: kalau AI gagal, tidak ada yang tersimpan
        # dan aplikasi cukup menyuruh pengguna kirim ulang.
        answer = await self.gateway.reply(system, turns)

        if not session_id:
            session = await asyncio.to_thread(self.store.create_session, user_id, make_title(req.message))
            session_id = session["id"]
        saved = await asyncio.to_thread(
            self.store.add_messages, user_id, session_id,
            [("user", req.message), ("assistant", answer.reply)],
        )
        return ChatResponse(
            session_id=session_id,
            user_message=ChatMessageOut.model_validate(saved[0]),
            reply=ChatMessageOut.model_validate(saved[1]),
            urgent=answer.urgent,
        )

    async def list_sessions(self, user_id: str) -> ChatSessionListOut:
        rows = await asyncio.to_thread(self.store.list_sessions, user_id, SESSIONS_LIMIT)
        sessions = [ChatSessionOut.model_validate(r) for r in rows]
        return ChatSessionListOut(sessions=sessions, count=len(sessions))

    async def list_messages(self, user_id: str, session_id: str) -> ChatMessageListOut:
        if await asyncio.to_thread(self.store.get_session, user_id, session_id) is None:
            raise SessionNotFound()
        rows = await asyncio.to_thread(self.store.recent_messages, user_id, session_id, MESSAGES_LIMIT)
        messages = [ChatMessageOut.model_validate(r) for r in rows]
        return ChatMessageListOut(messages=messages, count=len(messages))