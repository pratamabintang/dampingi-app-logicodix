"""Tes C03: SupabaseChatStore mengirim request yang benar (Supabase dipalsukan, pakai fixture B)."""
import json

import pytest

from conftest import supabase_error, supabase_json

from app.chat.store import SupabaseChatStore
from app.supabase import SupabaseError

pytestmark = pytest.mark.local

UID = "11111111-1111-4111-8111-111111111111"
SID = "6f1c2a52-0d3e-4c1b-9a7e-2b9f4f0c1a11"


def test_every_read_filters_by_owner(offline_env, upstream):
    rec = upstream({("GET", "/rest/v1/chat_sessions"): supabase_json(200, []),
                    ("GET", "/rest/v1/chat_messages"): supabase_json(200, [])})
    store = SupabaseChatStore()
    store.get_session(UID, SID)
    store.list_sessions(UID, 50)
    store.recent_messages(UID, SID, 10)
    assert len(rec.requests) == 3
    assert all(r.url.params["user_id"] == f"eq.{UID}" for r in rec.requests)
    assert rec.requests[0].url.params["id"] == f"eq.{SID}"


def test_recent_messages_are_returned_oldest_first(offline_env, upstream):
    newest_first = [{"content": "dua", "created_at": "2026-11-10T10:01:00Z"},
                    {"content": "satu", "created_at": "2026-11-10T10:00:00Z"}]
    rec = upstream({("GET", "/rest/v1/chat_messages"): supabase_json(200, newest_first)})
    rows = SupabaseChatStore().recent_messages(UID, SID, 10)
    assert [r["content"] for r in rows] == ["satu", "dua"]
    params = rec.requests[0].url.params
    assert params["order"] == "created_at.desc" and params["limit"] == "10"


def test_both_messages_are_inserted_in_one_request(offline_env, upstream):
    saved = [{"role": "assistant", "content": "b", "created_at": "2026-11-10T10:00:01Z"},
             {"role": "user", "content": "a", "created_at": "2026-11-10T10:00:00Z"}]
    rec = upstream({("POST", "/rest/v1/chat_messages"): supabase_json(201, saved)})
    rows = SupabaseChatStore().add_messages(UID, SID, [("user", "a"), ("assistant", "b")])
    assert len(rec.requests) == 1
    sent = json.loads(rec.requests[0].content)
    assert [m["role"] for m in sent] == ["user", "assistant"]
    assert all(m["user_id"] == UID and m["session_id"] == SID for m in sent)
    assert [r["role"] for r in rows] == ["user", "assistant"]


def test_supabase_error_is_raised(offline_env, upstream):
    upstream({("GET", "/rest/v1/chat_sessions"): supabase_error(500, "boom", "x")})
    with pytest.raises(SupabaseError):
        SupabaseChatStore().list_sessions(UID, 50)