"""Tes C03: endpoint /chat lewat HTTP. Login B dipalsukan, AI dan penyimpanan palsu."""
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient

import app.main as main
from app.ai import AIGateway
from app.ai.providers import FakeProvider
from app.auth import service as auth_service
from app.auth import supabase as auth_supabase
from app.auth.router import verified_session
from app.chat.router import get_chat_service
from app.chat.service import ChatService
from app.chat.store import InMemoryChatStore
from app.supabase import SupabaseError

pytestmark = [pytest.mark.local, pytest.mark.usefixtures("offline_env")]

USERS = {
    "tok-nadia": ("11111111-1111-4111-8111-111111111111", "mother"),
    "tok-budi": ("33333333-3333-4333-8333-333333333333", "companion"),
    "tok-sari": ("44444444-4444-4444-8444-444444444444", "professional"),
}
PROFILES = {uid: {"user_id": uid, "role": role, "deleted_at": None} for uid, role in USERS.values()}


@pytest.fixture
def api(monkeypatch):
    """TestClient + akses ke FakeProvider. Token di header menentukan siapa yang login."""
    from fastapi import Header

    def fake_session(authorization: str = Header(default="")):
        token = authorization.removeprefix("Bearer ")
        if token not in USERS:
            from fastapi import HTTPException
            raise HTTPException(status_code=401, detail="Invalid or expired token")
        return auth_service.Session(user_id=USERS[token][0], email="", token=token)

    provider = FakeProvider("Aku di sini.")
    service = ChatService(InMemoryChatStore(), AIGateway(provider))
    main.app.dependency_overrides[verified_session] = fake_session
    main.app.dependency_overrides[get_chat_service] = lambda: service
    monkeypatch.setattr(auth_supabase, "fetch_profile", lambda uid: PROFILES.get(uid))
    yield TestClient(main.app), provider
    main.app.dependency_overrides.clear()


def as_(token):
    return {"Authorization": f"Bearer {token}"}


def test_mother_can_chat(api):
    client, _ = api
    r = client.post("/chat", headers=as_("tok-nadia"), json={"message": "Aku capek"})
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["reply"]["content"] == "Aku di sini." and body["urgent"] is False


def test_companion_can_chat(api):
    client, _ = api
    assert client.post("/chat", headers=as_("tok-budi"), json={"message": "halo"}).status_code == 200


def test_without_login_is_401(api):
    client, _ = api
    assert client.post("/chat", json={"message": "halo"}).status_code == 401


def test_professional_is_403(api):
    client, provider = api
    r = client.post("/chat", headers=as_("tok-sari"), json={"message": "halo"})
    assert r.status_code == 403 and provider.calls == []


def test_deleted_account_is_403(api, monkeypatch):
    client, _ = api
    uid = USERS["tok-nadia"][0]
    monkeypatch.setitem(PROFILES, uid, {**PROFILES[uid], "deleted_at": "2026-11-10T00:00:00Z"})
    assert client.post("/chat", headers=as_("tok-nadia"), json={"message": "halo"}).status_code == 403


@pytest.mark.parametrize("body", [{"message": "   "}, {"message": "x" * 2001}, {"message": "hi", "role": "assistant"}])
def test_invalid_body_is_422(api, body):
    client, _ = api
    assert client.post("/chat", headers=as_("tok-nadia"), json=body).status_code == 422


def test_other_users_session_is_404(api):
    client, _ = api
    sid = client.post("/chat", headers=as_("tok-nadia"), json={"message": "rahasia"}).json()["session_id"]
    r = client.post("/chat", headers=as_("tok-budi"), json={"message": "hai", "session_id": sid})
    assert r.status_code == 404
    assert client.get(f"/chat/sessions/{sid}/messages", headers=as_("tok-budi")).status_code == 404


def test_ai_error_is_503_with_friendly_message(api):
    client, provider = api
    provider.error = RuntimeError("401 invalid key sk-rahasia")
    r = client.post("/chat", headers=as_("tok-nadia"), json={"message": "halo"})
    assert r.status_code == 503
    assert "sk-rahasia" not in r.text and r.json()["detail"]


def test_database_error_is_503(api, monkeypatch):
    client, _ = api

    def down(uid):
        raise SupabaseError(503, "Supabase unreachable")

    monkeypatch.setattr(auth_supabase, "fetch_profile", down)
    assert client.post("/chat", headers=as_("tok-nadia"), json={"message": "halo"}).status_code == 503


def test_history_endpoints(api):
    client, _ = api
    sid = client.post("/chat", headers=as_("tok-nadia"), json={"message": "satu"}).json()["session_id"]
    client.post("/chat", headers=as_("tok-nadia"), json={"message": "dua", "session_id": sid})

    sessions = client.get("/chat/sessions", headers=as_("tok-nadia")).json()
    assert sessions["count"] == 1 and sessions["sessions"][0]["title"] == "satu"

    messages = client.get(f"/chat/sessions/{sid}/messages", headers=as_("tok-nadia")).json()
    assert [m["content"] for m in messages["messages"]] == ["satu", "Aku di sini.", "dua", "Aku di sini."]


def test_bad_session_id_in_path_is_422(api):
    client, _ = api
    assert client.get("/chat/sessions/123/messages", headers=as_("tok-nadia")).status_code == 422


def test_unknown_session_in_path_is_404(api):
    client, _ = api
    assert client.get(f"/chat/sessions/{uuid4()}/messages", headers=as_("tok-nadia")).status_code == 404