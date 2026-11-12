import logging
import os
import traceback
from dataclasses import dataclass
from functools import lru_cache
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException

from app.ai import AIError
from app.ai.config import build_gateway
from app.auth import service as auth_service
from app.auth import supabase as auth_supabase
from app.auth.router import verified_session
from app.supabase import SupabaseError

from .schemas import ChatMessageListOut, ChatRequest, ChatResponse, ChatSessionListOut
from .service import ChatService, DailyLimitReached, SessionNotFound, StillAnswering
from .store import SupabaseChatStore
from .context import SupabaseMoodSource

router = APIRouter(prefix="/chat", tags=["chat"])
logger = logging.getLogger(__name__)

CHAT_ROLES = {"mother", "companion"}
DB_DOWN = "Riwayat chat sedang tidak dapat diakses. Coba lagi nanti."
UNEXPECTED = "Terjadi kesalahan pada chat. Coba lagi nanti, ya."


@dataclass(frozen=True)
class ChatUser:
    id: str
    role: str


def chat_user(session: auth_service.Session = Depends(verified_session)) -> ChatUser:
    """Login + role mother/companion + akun belum dihapus."""
    try:
        profile = auth_supabase.fetch_profile(session.user_id)
    except SupabaseError:
        raise HTTPException(status_code=503, detail=DB_DOWN)
    if not profile or profile.get("deleted_at") or profile.get("role") not in CHAT_ROLES:
        raise HTTPException(status_code=403, detail="Fitur chat hanya untuk ibu dan pendamping.")
    return ChatUser(id=session.user_id, role=profile["role"])


@lru_cache
def get_chat_service() -> ChatService:
    return ChatService(
        SupabaseChatStore(),
        build_gateway(),
        moods=SupabaseMoodSource(),
        daily_limit=int(os.getenv("CHAT_DAILY_LIMIT", "50")),
    )


async def _guard(coro):
    """Ubah error internal jadi respons HTTP yang aman ditampilkan."""
    try:
        return await coro
    except SessionNotFound:
        raise HTTPException(status_code=404, detail="Percakapan tidak ditemukan.")
    except StillAnswering:
        raise HTTPException(status_code=429, detail="Tunggu jawaban sebelumnya selesai dulu, ya.")
    except DailyLimitReached as exc:
        raise HTTPException(
            status_code=429,
            detail=f"Batas {exc.limit} pesan per 24 jam sudah tercapai. Coba lagi nanti, ya.",
        )
    except AIError as exc:
        raise HTTPException(status_code=503, detail=exc.user_message)
    except SupabaseError:
        raise HTTPException(status_code=503, detail=DB_DOWN)
    except Exception as exc:
        # Bug yang tidak terduga: jangan sampai detailnya (yang bisa memuat isi chat)
        # muncul di respons maupun log. Cukup jenis error dan lokasinya.
        frame = traceback.extract_tb(exc.__traceback__)[-1]
        logger.error("Chat error tak terduga: %s di %s:%s",
                     type(exc).__name__, frame.filename, frame.lineno)
        raise HTTPException(status_code=500, detail=UNEXPECTED)


@router.post("", response_model=ChatResponse, summary="Kirim pesan ke chatbot")
async def send_message(
    payload: ChatRequest,
    user: ChatUser = Depends(chat_user),
    svc: ChatService = Depends(get_chat_service),
) -> ChatResponse:
    return await _guard(svc.send(user.id, user.role, payload))


@router.get("/sessions", response_model=ChatSessionListOut, summary="Daftar percakapan saya")
async def list_sessions(
    user: ChatUser = Depends(chat_user),
    svc: ChatService = Depends(get_chat_service),
) -> ChatSessionListOut:
    return await _guard(svc.list_sessions(user.id))


@router.get("/sessions/{session_id}/messages", response_model=ChatMessageListOut,
            summary="Isi satu percakapan")
async def list_messages(
    session_id: UUID,
    user: ChatUser = Depends(chat_user),
    svc: ChatService = Depends(get_chat_service),
) -> ChatMessageListOut:
    return await _guard(svc.list_messages(user.id, str(session_id)))