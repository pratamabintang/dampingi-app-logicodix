import os

import httpx
import pytest

pytestmark = pytest.mark.live

TIMEOUT = 10


def _public_headers() -> dict:
    key = os.environ["SUPABASE_PUBLISHABLE_KEY"]
    return {"apikey": key, "Authorization": f"Bearer {key}"}


def _rest_url(base_url: str, table: str) -> str:
    return f"{base_url.rstrip('/')}/rest/v1/{table}"


def _is_refused(resp: httpx.Response) -> bool:
    return resp.status_code in (401, 403)


def test_public_key_cannot_read_a_private_table(supabase_env):
    resp = httpx.get(
        _rest_url(supabase_env, "journals"),
        params={"select": "id", "limit": 1},
        headers=_public_headers(),
        timeout=TIMEOUT,
    )
    assert _is_refused(resp), f"public key read a private table: {resp.status_code} {resp.text}"


def test_public_key_cannot_write_a_private_table(supabase_env):
    resp = httpx.post(
        _rest_url(supabase_env, "moods"),
        headers=_public_headers(),
        json={
            "user_id": "00000000-0000-0000-0000-000000000001",
            "created_at": "2026-11-12",
            "mood": 3,
        },
        timeout=TIMEOUT,
    )
    assert _is_refused(resp), f"public key wrote a private table: {resp.status_code} {resp.text}"
