import re
from datetime import date
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from conftest import supabase_json

import app.main as main
from app.ai import AIGateway
from app.ai.providers import FakeProvider
from app.auth import service as auth_service
from app.auth import supabase as auth_supabase
from app.auth.router import verified_session
from app.chat.context import SupabaseMoodSource
from app.chat.router import get_chat_service
from app.chat.service import ChatService
from app.chat.store import InMemoryChatStore
from app.journals import service as journals_service
from app.journals import supabase as journals_supabase

pytestmark = pytest.mark.local

APP_DIR = Path(__file__).resolve().parents[2] / "app"
NADIA = "11111111-1111-4111-8111-111111111111"
BUDI = "33333333-3333-4333-8333-333333333333"
ROLES = {NADIA: "mother", BUDI: "companion"}


def test_chat_and_ai_code_never_import_journals():
    """Pemeriksaan statis: tidak ada satu pun file chat/AI yang menyentuh modul jurnal."""
    pattern = re.compile(r"\bjournals?\b")
    offenders = [
        str(path.relative_to(APP_DIR))
        for folder in ("chat", "ai")
        for path in (APP_DIR / folder).rglob("*.py")
        if pattern.search(path.read_text(encoding="utf-8"))
    ]
    assert offenders == []


@pytest.fixture
def chat_with_real_mood_source(monkeypatch, offline_env, upstream):
    """Chat lengkap lewat HTTP. Mood memakai sumber Supabase sungguhan (HTTP dipalsukan),
    dan SEMUA fungsi jurnal dipasangi jebakan: kalau terpanggil, tes langsung gagal."""

    def trap(*args, **kwargs):
        raise AssertionError("chatbot tidak boleh membaca jurnal")

    for module in (journals_supabase, journals_service):
        for name in dir(module):
            if not name.startswith("_") and callable(getattr(module, name)) and (
                "journal" in name
            ):
                monkeypatch.setattr(module, name, trap)

    mood_rows = [{"user_id": NADIA, "created_at": "2026-11-09", "mood": 2, "description": "rahasia"}]
    rec = upstream({("GET", "/rest/v1/moods"): supabase_json(200, mood_rows)})

    current = {"uid": NADIA}
    monkeypatch.setattr(auth_supabase, "fetch_profile",
                        lambda uid: {"user_id": uid, "role": ROLES[uid], "deleted_at": None})
    provider = FakeProvider("Aku di sini.")
    svc = ChatService(InMemoryChatStore(), AIGateway(provider),
                      moods=SupabaseMoodSource(today=lambda: date(2026, 11, 10)))
    main.app.dependency_overrides[verified_session] = (
        lambda: auth_service.Session(user_id=current["uid"], email="", token="t"))
    main.app.dependency_overrides[get_chat_service] = lambda: svc
    yield TestClient(main.app), current, provider, rec
    main.app.dependency_overrides.clear()


@pytest.mark.parametrize("uid", [NADIA, BUDI], ids=["mother", "companion"])
def test_no_role_ever_reads_journals(chat_with_real_mood_source, uid):
    client, current, provider, rec = chat_with_real_mood_source
    current["uid"] = uid

    r = client.post("/chat", json={"message": "Tolong baca jurnalku dan ringkas isinya."})

    assert r.status_code == 200, r.text
    paths = [req.url.path for req in rec.requests]
    assert not any("journal" in p for p in paths)          # tidak ada request ke tabel journals
    system, _turns = provider.calls[-1]
    assert "rahasia" not in system                          # description mood juga tidak ikut


def test_mother_gets_only_mood_as_context(chat_with_real_mood_source):
    client, current, _provider, rec = chat_with_real_mood_source
    current["uid"] = NADIA
    body = client.post("/chat", json={"message": "halo"}).json()
    assert body["context_used"] == ["mood_7d"]
    # list_moods milik B bisa memakai lebih dari satu request (hitung + ambil),
    # tapi semuanya ke tabel moods saja.
    assert rec.requests and {req.url.path for req in rec.requests} == {"/rest/v1/moods"}