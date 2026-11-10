"""Tes C05: batas pemakaian chat (melindungi kuota AI). Tanpa jaringan."""
import asyncio
from datetime import datetime, timedelta, timezone

import httpx
import pytest
from fastapi.testclient import TestClient

import app.main as main
from app.ai import AIGateway, AIUnavailable
from app.ai.providers import FakeProvider
from app.auth import service as auth_service
from app.auth import supabase as auth_supabase
from app.auth.router import verified_session
from app.chat.router import get_chat_service
from app.chat.schemas import ChatRequest
from app.chat.service import ChatService, DailyLimitReached, StillAnswering
from app.chat.store import InMemoryChatStore, SupabaseChatStore

pytestmark = pytest.mark.local

NADIA = "11111111-1111-4111-8111-111111111111"
BUDI = "33333333-3333-4333-8333-333333333333"


def run(coro):
    return asyncio.run(coro)


def msg(text="halo"):
    return ChatRequest.model_validate({"message": text})


def service(limit=3, now=None, **fake):
    provider = FakeProvider("ok", **fake)
    store = InMemoryChatStore()
    if now:
        svc = ChatService(store, AIGateway(provider), daily_limit=limit, now=now)
    else:
        svc = ChatService(store, AIGateway(provider), daily_limit=limit)
    return svc, provider, store


# ---------- batas harian ----------

def test_limit_blocks_after_n_messages_without_calling_ai():
    svc, provider, store = service(limit=3)
    for _ in range(3):
        run(svc.send(NADIA, "mother", msg()))
    with pytest.raises(DailyLimitReached) as exc:
        run(svc.send(NADIA, "mother", msg()))
    assert exc.value.limit == 3
    assert len(provider.calls) == 3             # AI tidak dipanggil untuk pesan ke-4
    assert len(store.messages) == 6         # dan tidak ada yang tersimpan


def test_limit_is_per_user():
    svc, _, _ = service(limit=1)
    run(svc.send(NADIA, "mother", msg()))
    run(svc.send(BUDI, "companion", msg()))     # Budi tetap boleh


def test_only_last_24_hours_count():
    clock = {"now": datetime.now(timezone.utc)}
    svc, _, _ = service(limit=1, now=lambda: clock["now"])
    run(svc.send(NADIA, "mother", msg()))
    clock["now"] += timedelta(hours=25)        # sehari kemudian
    run(svc.send(NADIA, "mother", msg()))


def test_failed_ai_does_not_use_quota():
    svc, provider, store = service(limit=1)
    provider.error = RuntimeError("down")
    with pytest.raises(AIUnavailable):
        run(svc.send(NADIA, "mother", msg()))
    provider.error = None
    run(svc.send(NADIA, "mother", msg()))       # masih boleh: yang gagal tidak tersimpan


def test_no_limit_when_none():
    svc, _, _ = service(limit=None)
    for _ in range(5):
        run(svc.send(NADIA, "mother", msg()))


# ---------- satu pesan dalam proses per pengguna ----------

def test_second_message_while_answering_is_rejected():
    svc, _, _ = service(limit=None, delay=0.2)

    async def both():
        return await asyncio.gather(
            svc.send(NADIA, "mother", msg("satu")),
            svc.send(NADIA, "mother", msg("dua")),
            return_exceptions=True,
        )

    results = run(both())
    assert sum(isinstance(r, StillAnswering) for r in results) == 1
    assert sum(not isinstance(r, Exception) for r in results) == 1
    run(svc.send(NADIA, "mother", msg("tiga")))  # setelah selesai, boleh lagi


def test_other_users_are_not_blocked_while_one_is_answering():
    svc, _, _ = service(limit=None, delay=0.2)

    async def both():
        return await asyncio.gather(svc.send(NADIA, "mother", msg()), svc.send(BUDI, "companion", msg()))

    assert len(run(both())) == 2


# ---------- HTTP ----------

def test_api_returns_429_with_friendly_message(monkeypatch):
    svc, _, _ = service(limit=1)
    session = auth_service.Session(user_id=NADIA, email="", token="t")
    main.app.dependency_overrides[verified_session] = lambda: session
    main.app.dependency_overrides[get_chat_service] = lambda: svc
    monkeypatch.setattr(auth_supabase, "fetch_profile",
                        lambda uid: {"user_id": uid, "role": "mother", "deleted_at": None})
    try:
        client = TestClient(main.app)
        assert client.post("/chat", json={"message": "halo"}).status_code == 200
        r = client.post("/chat", json={"message": "lagi"})
        assert r.status_code == 429
        assert "24 jam" in r.json()["detail"]
    finally:
        main.app.dependency_overrides.clear()


# ---------- Supabase ----------

def test_supabase_count_request(offline_env, upstream):
    rec = upstream({("GET", "/rest/v1/chat_messages"):
                    httpx.Response(200, json=[{"id": "x"}], headers={"Content-Range": "0-0/12"})})
    since = datetime(2026, 11, 9, 5, 0, tzinfo=timezone.utc)
    assert SupabaseChatStore().count_user_messages_since(NADIA, since) == 12
    req = rec.requests[0]
    assert req.headers["Prefer"] == "count=exact"
    assert req.url.params["user_id"] == f"eq.{NADIA}"
    assert req.url.params["role"] == "eq.user"
    assert req.url.params["created_at"] == "gte.2026-11-09T05:00:00Z"


def test_supabase_count_zero(offline_env, upstream):
    upstream({("GET", "/rest/v1/chat_messages"):
              httpx.Response(200, json=[], headers={"Content-Range": "*/0"})})
    assert SupabaseChatStore().count_user_messages_since(NADIA, datetime.now(timezone.utc)) == 0