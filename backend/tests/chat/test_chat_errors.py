"""Tes C08: setiap kegagalan chat berakhir dengan pesan yang jelas, tanpa membocorkan detail.

Skenario: AI lambat, jawaban AI rusak, kuota Gemini habis, Gemini menolak, database mati,
sesi tidak ditemukan, batas pemakaian, dan bug tak terduga.
"""
import asyncio
import logging
from types import SimpleNamespace
from typing import Any, cast

import pytest
from fastapi.testclient import TestClient
from google.genai import errors as genai_errors

import app.main as main
from app.ai import AIBusy, AIGateway, AITimeout, AIUnavailable, Turn
from app.ai.providers import FakeProvider, GeminiProvider
from app.auth import service as auth_service
from app.auth import supabase as auth_supabase
from app.auth.router import verified_session
from app.chat.router import UNEXPECTED, get_chat_service
from app.chat.service import ChatService
from app.chat.store import InMemoryChatStore
from app.supabase import SupabaseError

pytestmark = [pytest.mark.local, pytest.mark.usefixtures("offline_env")]

NADIA = "11111111-1111-4111-8111-111111111111"
SECRETS = ["AIza-rahasia", "isi-rahasia-ibu", "Traceback", 'File "']


def run(coro):
    return asyncio.run(coro)


# ---------- Gemini: error dari Google diterjemahkan ----------

class FailingModels:
    def __init__(self, exc):
        self.exc = exc

    async def generate_content(self, **kwargs):
        raise self.exc


def gemini_failing(code, status):
    body = {"error": {"code": code, "status": status,
                      "message": f"ditolak untuk key AIza-rahasia: isi-rahasia-ibu"}}
    exc = genai_errors.ClientError(code, body)
    client = SimpleNamespace(aio=SimpleNamespace(models=FailingModels(exc)))
    return GeminiProvider(cast(Any, client), "model-x")


def test_gemini_quota_exhausted_is_busy(caplog):
    with caplog.at_level(logging.WARNING), pytest.raises(AIBusy) as exc:
        run(AIGateway(gemini_failing(429, "RESOURCE_EXHAUSTED")).reply("s", [Turn("user", "halo")]))
    assert "beberapa menit" in exc.value.user_message
    assert "429 RESOURCE_EXHAUSTED" in caplog.text           # kode tetap tercatat untuk tim
    assert not any(s in caplog.text for s in SECRETS[:2])    # tapi isi pesan Google tidak


def test_gemini_other_error_is_unavailable(caplog):
    with caplog.at_level(logging.WARNING), pytest.raises(AIUnavailable):
        run(AIGateway(gemini_failing(404, "NOT_FOUND")).reply("s", [Turn("user", "halo")]))
    assert "404 NOT_FOUND" in caplog.text and "AIza-rahasia" not in caplog.text


# ---------- lewat HTTP: matriks kegagalan ----------

class BrokenStore(InMemoryChatStore):
    """Penyimpanan yang bisa dibuat gagal dengan cara tertentu."""

    def __init__(self, error=None):
        super().__init__()
        self.error = error

    def add_messages(self, user_id, session_id, messages):
        if self.error:
            raise self.error
        return super().add_messages(user_id, session_id, messages)


@pytest.fixture
def api(monkeypatch):
    holder: dict = {}

    def use(provider=None, store=None, timeout_s=20.0, daily_limit=None):
        svc = ChatService(store or InMemoryChatStore(),
                          AIGateway(provider or FakeProvider("ok"), timeout_s=timeout_s),
                          daily_limit=daily_limit)
        holder["svc"] = svc
        return svc

    monkeypatch.setattr(auth_supabase, "fetch_profile",
                        lambda uid: {"user_id": uid, "role": "mother", "deleted_at": None})
    main.app.dependency_overrides[verified_session] = (
        lambda: auth_service.Session(user_id=NADIA, email="", token="t"))
    main.app.dependency_overrides[get_chat_service] = lambda: holder["svc"]
    yield TestClient(main.app), use
    main.app.dependency_overrides.clear()


def send(client, text="isi-rahasia-ibu"):
    return client.post("/chat", json={"message": text})


def assert_safe(resp, status):
    assert resp.status_code == status, resp.text
    body = resp.json()
    assert isinstance(body["detail"], str) and body["detail"].strip()
    assert not any(s in resp.text for s in SECRETS)


def test_slow_ai_is_503(api):
    client, use = api
    use(provider=FakeProvider(delay=1), timeout_s=0.05)
    r = send(client)
    assert_safe(r, 503)
    assert r.json()["detail"] == AITimeout.user_message


def test_broken_ai_output_is_503(api):
    client, use = api
    use(provider=FakeProvider(raw='{"reply": "x", "diagnosis": "isi-rahasia-ibu"}'))
    assert_safe(send(client), 503)


def test_gemini_quota_is_503_with_busy_message(api):
    client, use = api
    use(provider=gemini_failing(429, "RESOURCE_EXHAUSTED"))
    r = send(client)
    assert_safe(r, 503)
    assert r.json()["detail"] == AIBusy.user_message


def test_database_down_is_503(api):
    client, use = api
    use(store=BrokenStore(SupabaseError(503, "Supabase unreachable: isi-rahasia-ibu")))
    assert_safe(send(client), 503)


def test_unexpected_bug_is_500_without_details(api, caplog):
    client, use = api
    use(store=BrokenStore(RuntimeError("bug memuat isi-rahasia-ibu")))
    with caplog.at_level(logging.ERROR):
        r = send(client)
    assert_safe(r, 500)
    assert r.json()["detail"] == UNEXPECTED
    assert "RuntimeError" in caplog.text            # tim tetap tahu jenis dan lokasinya
    assert "isi-rahasia-ibu" not in caplog.text     # tanpa isi chat di log


def test_daily_limit_is_429(api):
    client, use = api
    use(daily_limit=1)
    assert send(client, "pertama").status_code == 200
    assert_safe(send(client, "kedua"), 429)


def test_unknown_session_is_404(api):
    client, use = api
    use()
    r = client.post("/chat", json={"message": "halo", "session_id": "6f1c2a52-0d3e-4c1b-9a7e-2b9f4f0c1a11"})
    assert_safe(r, 404)


def test_failed_attempts_save_nothing(api):
    client, use = api
    store = BrokenStore()
    use(provider=FakeProvider(delay=1), store=store, timeout_s=0.05)
    send(client)
    assert store.sessions == {} and store.messages == []