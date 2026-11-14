from datetime import datetime, timezone
from typing import Protocol
from uuid import uuid4

from app.config import supabase_service_http
from app.supabase import TIMEOUT, SupabaseError, _base_url, _client, _error_from_response, _request


class ChatStore(Protocol):
    def get_session(self, user_id: str, session_id: str) -> dict | None: ...
    def create_session(self, user_id: str, title: str) -> dict: ...
    def list_sessions(self, user_id: str, limit: int) -> list[dict]: ...
    def recent_messages(self, user_id: str, session_id: str, limit: int) -> list[dict]: ...
    def add_messages(self, user_id: str, session_id: str, messages: list[tuple[str, str]]) -> list[dict]: ...
    def count_user_messages_since(self, user_id: str, since: datetime) -> int: ...
    def messages_between(
        self, user_id: str, start: datetime, end: datetime
    ) -> list[dict]: ...

class InMemoryChatStore:
    """Untuk tes. Perilakunya meniru tabel Supabase."""

    def __init__(self):
        self.sessions: dict[str, dict] = {}
        self.messages: list[dict] = []

    def get_session(self, user_id, session_id):
        s = self.sessions.get(session_id)
        return s if s and s["user_id"] == user_id else None

    def create_session(self, user_id, title):
        now = datetime.now(timezone.utc).isoformat()
        s = {"id": str(uuid4()), "user_id": user_id, "title": title, "created_at": now, "updated_at": now}
        self.sessions[s["id"]] = s
        return s

    def list_sessions(self, user_id, limit):
        mine = [s for s in self.sessions.values() if s["user_id"] == user_id]
        return sorted(mine, key=lambda s: s["updated_at"], reverse=True)[:limit]

    def recent_messages(self, user_id, session_id, limit):
        mine = [m for m in self.messages if m["session_id"] == session_id and m["user_id"] == user_id]
        return mine[-limit:]

    def add_messages(self, user_id, session_id, messages):
        rows = []
        for role, content in messages:
            now = datetime.now(timezone.utc).isoformat()
            rows.append({"id": str(uuid4()), "session_id": session_id, "user_id": user_id,
                         "role": role, "content": content, "created_at": now})
        self.messages += rows
        self.sessions[session_id]["updated_at"] = rows[-1]["created_at"]
        return rows

    def count_user_messages_since(self, user_id, since):
        return sum(1 for m in self.messages
                   if m["user_id"] == user_id and m["role"] == "user"
                   and datetime.fromisoformat(m["created_at"]) >= since)

    def messages_between(self, user_id, start, end):
        return sorted(
            [
                m for m in self.messages
                if m["user_id"] == user_id
                and start <= datetime.fromisoformat(m["created_at"]) < end
            ],
            key=lambda m: m["created_at"],
        )


class SupabaseChatStore:
    def _get(self, table: str, params: dict) -> list[dict]:
        resp = _request(_client().get, f"{_base_url()}/rest/v1/{table}",
                        params=params, headers=supabase_service_http(), timeout=TIMEOUT)
        if resp.status_code >= 400:
            raise _error_from_response(resp)
        return resp.json()

    def _insert(self, table: str, payload) -> list[dict]:
        resp = _request(_client().post, f"{_base_url()}/rest/v1/{table}",
                        headers={**supabase_service_http(), "Prefer": "return=representation"},
                        json=payload, timeout=TIMEOUT)
        if resp.status_code >= 400:
            raise _error_from_response(resp)
        rows = resp.json()
        if not rows:
            raise SupabaseError(500, "No row returned after insert")
        return rows

    def get_session(self, user_id, session_id):
        rows = self._get("chat_sessions", {"id": f"eq.{session_id}", "user_id": f"eq.{user_id}", "select": "*"})
        return rows[0] if rows else None

    def create_session(self, user_id, title):
        return self._insert("chat_sessions", {"user_id": user_id, "title": title})[0]

    def list_sessions(self, user_id, limit):
        return self._get("chat_sessions", {"user_id": f"eq.{user_id}", "select": "*",
                                           "order": "updated_at.desc", "limit": str(limit)})

    def recent_messages(self, user_id, session_id, limit):
        rows = self._get("chat_messages", {"session_id": f"eq.{session_id}", "user_id": f"eq.{user_id}",
                                           "select": "*", "order": "created_at.desc", "limit": str(limit)})
        return list(reversed(rows))  # terlama dulu

    def add_messages(self, user_id, session_id, messages):
        # Satu request = satu statement: kedua pesan tersimpan bersama, atau tidak sama sekali.
        payload = [{"session_id": session_id, "user_id": user_id, "role": r, "content": c} for r, c in messages]
        return sorted(self._insert("chat_messages", payload), key=lambda m: m["created_at"])

    def count_user_messages_since(self, user_id, since):
        """Hitung pesan pengguna sejak `since`, tanpa mengambil isinya (count=exact)."""
        resp = _request(
            _client().get, f"{_base_url()}/rest/v1/chat_messages",
            params={"user_id": f"eq.{user_id}", "role": "eq.user",
                    "created_at": f"gte.{since.strftime('%Y-%m-%dT%H:%M:%SZ')}",
                    "select": "id", "limit": "1"},
            headers={**supabase_service_http(), "Prefer": "count=exact"},
            timeout=TIMEOUT,
        )
        if resp.status_code >= 400:
            raise _error_from_response(resp)
        # Content-Range berbentuk "0-0/12" atau "*/0": angka setelah "/" adalah totalnya.
        return int(resp.headers.get("content-range", "*/0").split("/")[-1])

    def messages_between(self, user_id, start, end):
        start_utc = start.astimezone(timezone.utc)
        end_utc = end.astimezone(timezone.utc)

        return self._get(
            "chat_messages",
            {
                "user_id": f"eq.{user_id}",
                "created_at": f"gte.{start_utc.strftime('%Y-%m-%dT%H:%M:%SZ')}",
                "and": (
                    f"(created_at.lt.{end_utc.strftime('%Y-%m-%dT%H:%M:%SZ')})"
                ),
                "select": "*",
                "order": "created_at.asc",
            },
        )