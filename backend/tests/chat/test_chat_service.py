
"""Tes C03: alur chat di service. Tanpa jaringan:
penyimpanan dan AI dipalsukan."""

import asyncio
from uuid import uuid4
from unittest.mock import AsyncMock

import pytest

import app.chat.service as chat_service_module

from app.ai import AIGateway, AIUnavailable
from app.ai.providers import FakeProvider
from app.chat.prompts import PROMPTS
from app.chat.schemas import ChatRequest
from app.chat.service import (
    HISTORY_LIMIT,
    ChatService,
    SessionNotFound,
    make_title,
    trim_history,
)
from app.chat.store import InMemoryChatStore

pytestmark = pytest.mark.local

NADIA = "11111111-1111-4111-8111-111111111111"  # ibu
BUDI = "33333333-3333-4333-8333-333333333333"   # pendamping


def run(coro):
    return asyncio.run(coro)


def make(reply="Aku di sini.", **fake):
    store = InMemoryChatStore()
    provider = FakeProvider(reply, **fake)
    return ChatService(store, AIGateway(provider)), store, provider


def msg(text, session_id=None):
    return ChatRequest.model_validate({
        "message": text,
        "session_id": session_id,
    })


# ---------- percakapan baru dan lanjutan ----------

def test_new_conversation_creates_session_and_saves_both_messages():
    svc, store, _ = make("Wajar merasa capek.")

    res = run(svc.send(NADIA, "mother", msg("Aku capek banget")))

    assert res.user_message.content == "Aku capek banget"
    assert res.reply.content == "Wajar merasa capek."
    assert res.reply.role == "assistant"
    assert res.urgent is False
    assert store.sessions[str(res.session_id)]["title"] == "Aku capek banget"
    assert [m["role"] for m in store.messages] == ["user", "assistant"]


def test_continuing_sends_history_to_ai():
    svc, _, provider = make()

    first = run(svc.send(NADIA, "mother", msg("Halo")))
    run(svc.send(NADIA, "mother", msg("Bayiku rewel", first.session_id)))

    _system, turns = provider.calls[-1]

    assert [(t.role, t.content) for t in turns] == [
        ("user", "Halo"),
        ("assistant", "Aku di sini."),
        ("user", "Bayiku rewel"),
    ]


def test_system_prompt_follows_role():
    svc, _, provider = make()

    run(svc.send(NADIA, "mother", msg("hai")))
    run(svc.send(BUDI, "companion", msg("hai")))

    assert provider.calls[0][0] == PROMPTS["mother"][1]
    assert provider.calls[1][0] == PROMPTS["companion"][1]


def test_urgent_is_returned():
    svc, _, _ = make("Segera hubungi 119.", urgent=True)

    result = run(
        svc.send(
            NADIA,
            "mother",
            msg("Aku pengen nyakitin diri"),
        )
    )

    assert result.urgent is True


# ---------- kepemilikan ----------

def test_cannot_continue_someone_elses_session():
    svc, store, provider = make()

    nadia = run(svc.send(NADIA, "mother", msg("rahasia ibu")))

    with pytest.raises(SessionNotFound):
        run(
            svc.send(
                BUDI,
                "companion",
                msg("halo", nadia.session_id),
            )
        )

    assert len(provider.calls) == 1
    assert len(store.messages) == 2


def test_unknown_session_is_not_found():
    svc, _, _ = make()

    with pytest.raises(SessionNotFound):
        run(svc.send(NADIA, "mother", msg("halo", str(uuid4()))))


def test_list_only_shows_own_sessions_and_messages():
    svc, _, _ = make()

    nadia = run(svc.send(NADIA, "mother", msg("punya Nadia")))
    run(svc.send(BUDI, "companion", msg("punya Budi")))

    assert [
        s.title for s in run(svc.list_sessions(NADIA)).sessions
    ] == ["punya Nadia"]

    assert run(
        svc.list_messages(NADIA, str(nadia.session_id))
    ).count == 2

    with pytest.raises(SessionNotFound):
        run(svc.list_messages(BUDI, str(nadia.session_id)))


# ---------- AI gagal ----------

def test_ai_failure_saves_nothing():
    svc, store, _ = make(error=RuntimeError("down"))

    with pytest.raises(AIUnavailable):
        run(svc.send(NADIA, "mother", msg("halo")))

    assert store.sessions == {}
    assert store.messages == []


# ---------- batas riwayat ----------

def test_history_is_limited():
    svc, _, provider = make()

    first = run(svc.send(NADIA, "mother", msg("pesan 0")))

    for i in range(1, 8):
        run(
            svc.send(
                NADIA,
                "mother",
                msg(f"pesan {i}", first.session_id),
            )
        )

    _system, turns = provider.calls[-1]

    assert len(turns) == HISTORY_LIMIT + 1
    assert turns[-1].content == "pesan 7"


def test_trim_history_keeps_newest_within_budget():
    rows = [
        {"content": "a" * 100},
        {"content": "b" * 100},
        {"content": "c" * 100},
    ]

    assert [
        r["content"][0] for r in trim_history(rows, 250)
    ] == ["b", "c"]


def test_title_is_shortened():
    assert make_title("  halo   ibu  ") == "halo ibu"

    long = make_title("x" * 100)
    assert len(long) <= 60


# ---------- Daily Summary integration ----------

def test_only_mothers_chat_refreshes_daily_summary(monkeypatch):
    svc, store, _ = make()

    refresh = AsyncMock()

    monkeypatch.setattr(
        chat_service_module,
        "create_daily_summary",
        refresh,
    )

    run(
        svc.send(
            NADIA,
            "mother",
            msg("Aku merasa lelah."),
        )
    )

    run(
        svc.send(
            BUDI,
            "companion",
            msg("Ibu terlihat lelah."),
        )
    )

    refresh.assert_awaited_once_with(
        user_id=NADIA,
        chat_store=store,
    )
