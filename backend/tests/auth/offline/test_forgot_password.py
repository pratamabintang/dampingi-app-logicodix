"""`POST /auth/forgot-password`: ask for a password-reset code.

The answer is the same `202` for every address, so the endpoint cannot be
used to learn which addresses are registered. An upstream outage (`503`) and
an upstream rate limit (`429`) are still surfaced, because neither depends on
the address.
"""

import json

import pytest

from app import errors, throttle
from conftest import supabase_error, supabase_json

pytestmark = pytest.mark.local

FORGOT = "/auth/forgot-password"
RECOVER = ("POST", "/auth/v1/recover")

DETAIL = "Jika email terdaftar, kode reset sudah dikirim."


def _forgot(client, email="bunda@gmail.com"):
    return client.post(FORGOT, json={"email": email})


def test_it_answers_202_with_one_body(mock_client, upstream):
    client, _ = mock_client
    upstream({RECOVER: supabase_json(200, {})})

    resp = _forgot(client)

    assert resp.status_code == 202, resp.text
    assert resp.json()["detail"] == DETAIL


def test_it_forwards_the_address_to_recover(mock_client, upstream):
    client, _ = mock_client
    recorded = upstream({RECOVER: supabase_json(200, {})})

    _forgot(client, "bunda@gmail.com")

    sent = recorded.requests[0]
    assert sent.url.path == "/auth/v1/recover"
    assert json.loads(sent.content)["email"] == "bunda@gmail.com"


def test_an_unregistered_address_answers_the_same_202(mock_client, upstream):
    """GoTrue rejects an unknown address; the local body stays neutral."""
    client, _ = mock_client
    upstream({RECOVER: supabase_error(400, "User not found", "user_not_found")})

    resp = _forgot(client, "nobody@gmail.com")

    assert resp.status_code == 202, resp.text
    assert resp.json()["detail"] == DETAIL


def test_an_upstream_cooldown_is_429_not_503(mock_client, upstream):
    client, _ = mock_client
    upstream(
        {
            RECOVER: supabase_error(
                429,
                "For security purposes, you can only request this after 42 seconds.",
                "over_email_send_rate_limit",
            )
        }
    )

    resp = _forgot(client)

    assert resp.status_code == 429, resp.text
    assert resp.headers.get("Retry-After")


def test_an_unreachable_upstream_is_503(mock_client, upstream):
    import httpx

    client, _ = mock_client

    def unreachable(_request):
        raise httpx.ConnectError("connection refused")

    upstream({RECOVER: unreachable})

    assert _forgot(client).status_code == 503


def test_the_account_limit_refuses_the_nth_plus_one(
    mock_client, upstream, monkeypatch
):
    monkeypatch.setattr(throttle, "FORGOT_PER_ADDRESS", 100)
    monkeypatch.setattr(throttle, "FORGOT_PER_ACCOUNT", 1)
    throttle.set_limiter(throttle.InMemoryRateLimiter())
    client, _ = mock_client
    recorded = upstream({RECOVER: supabase_json(200, {})})

    assert _forgot(client, "same@gmail.com").status_code == 202

    refused = _forgot(client, "Same@Gmail.com")

    assert refused.status_code == 429, refused.text
    assert refused.json()["detail"] == errors._THROTTLED
    assert refused.headers.get("Retry-After")
    assert len(recorded.requests) == 1
