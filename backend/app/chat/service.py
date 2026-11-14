
import asyncio
import logging
from datetime import datetime, timedelta, timezone
from typing import Callable

from app.ai import AIGateway, Turn
from app.summaries.daily_service import create_daily_summary

from .context import MOOD_CONTEXT, MoodSource, mother_moods
from .prompts import build_system_prompt
from .schemas import (
    ChatMessageListOut,
    ChatMessageOut,
    ChatRequest,
    ChatResponse,
    ChatSessionListOut,
    ChatSessionOut,
)
from .store import ChatStore

HISTORY_LIMIT = 10
HISTORY_MAX_CHARS = 6000
TITLE_MAX = 60
SESSIONS_LIMIT = 50
MESSAGES_LIMIT = 200

logger = logging.getLogger(__name__)


class SessionNotFound(Exception):
    pass


class DailyLimitReached(Exception):
    def __init__(self, limit: int):
        super().__init__(limit)
        self.limit = limit


class StillAnswering(Exception):
    """Pesan sebelumnya dari pengguna yang sama masih diproses."""


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


def trim_history(
    rows: list[dict],
    max_chars: int = HISTORY_MAX_CHARS,
) -> list[dict]:
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
    return (
        title
        if len(title) <= TITLE_MAX
        else title[: TITLE_MAX - 1].rstrip() + "…"
    )


class ChatService:
    def __init__(
        self,
        store: ChatStore,
        gateway: AIGateway,
        moods: MoodSource | None = None,
        daily_limit: int | None = None,
        now: Callable[[], datetime] = _utc_now,
    ):
        self.store = store
        self.gateway = gateway
        self.moods = moods
        self.daily_limit = daily_limit
        self.now = now
        self._busy: set[str] = set()

    async def send(
        self,
        user_id: str,
        role: str,
        req: ChatRequest,
    ) -> ChatResponse:
        if user_id in self._busy:
            raise StillAnswering()

        self._busy.add(user_id)

        try:
            await self._check_daily_limit(user_id)
            return await self._send(user_id, role, req)
        finally:
            self._busy.discard(user_id)

    async def _check_daily_limit(self, user_id: str) -> None:
        if self.daily_limit is None:
            return

        since = self.now() - timedelta(hours=24)

        used = await asyncio.to_thread(
            self.store.count_user_messages_since,
            user_id,
            since,
        )

        if used >= self.daily_limit:
            raise DailyLimitReached(self.daily_limit)

    async def _send(
        self,
        user_id: str,
        role: str,
        req: ChatRequest,
    ) -> ChatResponse:
        history: list[dict] = []
        session_id = str(req.session_id) if req.session_id else None

        if session_id:
            if await asyncio.to_thread(
                self.store.get_session,
                user_id,
                session_id,
            ) is None:
                raise SessionNotFound()

            history = await asyncio.to_thread(
                self.store.recent_messages,
                user_id,
                session_id,
                HISTORY_LIMIT,
            )

        # Mood terbaru langsung digunakan sebagai konteks chatbot.
        moods = await mother_moods(self.moods, user_id, role)
        _version, system = build_system_prompt(role, moods)

        turns = [
            Turn(r["role"], r["content"])
            for r in trim_history(history)
        ]
        turns.append(Turn("user", req.message))

        # AI dulu, simpan belakangan.
        answer = await self.gateway.reply(system, turns)

        if not session_id:
            session = await asyncio.to_thread(
                self.store.create_session,
                user_id,
                make_title(req.message),
            )
            session_id = session["id"]

        saved = await asyncio.to_thread(
            self.store.add_messages,
            user_id,
            session_id,
            [
                ("user", req.message),
                ("assistant", answer.reply),
            ],
        )

        # Perbarui Daily Summary setelah kedua pesan berhasil tersimpan.
        # Hanya percakapan ibu yang menjadi sumber Daily Summary.
        # Kegagalan summary tidak menggagalkan respons chatbot.
        if role == "mother":
            try:
                await create_daily_summary(
                    user_id=user_id,
                    chat_store=self.store,
                )
            except Exception:
                logger.exception(
                    "Gagal memperbarui Daily Summary setelah chat."
                )

        return ChatResponse(
            session_id=session_id,
            user_message=ChatMessageOut.model_validate(saved[0]),
            reply=ChatMessageOut.model_validate(saved[1]),
            urgent=answer.urgent,
            context_used=[MOOD_CONTEXT] if moods else [],
        )

    async def list_sessions(
        self,
        user_id: str,
    ) -> ChatSessionListOut:
        rows = await asyncio.to_thread(
            self.store.list_sessions,
            user_id,
            SESSIONS_LIMIT,
        )

        sessions = [
            ChatSessionOut.model_validate(r)
            for r in rows
        ]

        return ChatSessionListOut(
            sessions=sessions,
            count=len(sessions),
        )

    async def list_messages(
        self,
        user_id: str,
        session_id: str,
    ) -> ChatMessageListOut:
        if await asyncio.to_thread(
            self.store.get_session,
            user_id,
            session_id,
        ) is None:
            raise SessionNotFound()

        rows = await asyncio.to_thread(
            self.store.recent_messages,
            user_id,
            session_id,
            MESSAGES_LIMIT,
        )

        messages = [
            ChatMessageOut.model_validate(r)
            for r in rows
        ]

        return ChatMessageListOut(
            messages=messages,
            count=len(messages),
        )