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
from .service import ChatService, SessionNotFound
from .store import SupabaseChatStore

router = APIRouter(prefix="/chat", tags=["chat"])

CHAT_ROLES = {"mother", "companion"}
DB_DOWN = "Riwayat chat sedang tidak dapat diakses. Coba lagi nanti."


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
    return ChatService(SupabaseChatStore(), build_gateway())


async def _guard(coro):
    """Ubah error internal jadi respons HTTP yang aman ditampilkan."""
    try:
        return await coro
    except SessionNotFound:
        raise HTTPException(status_code=404, detail="Percakapan tidak ditemukan.")
    except AIError as exc:
        raise HTTPException(status_code=503, detail=exc.user_message)
    except SupabaseError:
        raise HTTPException(status_code=503, detail=DB_DOWN)


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