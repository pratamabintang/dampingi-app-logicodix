"""Local throttles on the two confirmation endpoints.

Supabase also caps confirmation emails, but its cap is per project, so a
single caller can spend it for everyone. These per-address and per-account
windows refuse the caller before the upstream call leaves the process.
"""

import pytest

from app import errors, throttle
from conftest import supabase_error, supabase_json

pytestmark = pytest.mark.local

VERIFY = "/auth/verify-email"
RESEND = "/auth/resend-confirmation"

BAD_CODE = supabase_error(403, "Invalid or expired token", "otp_expired")


def _limits(monkeypatch, **overrides):
    for name, value in overrides.items():
        monkeypatch.setattr(throttle, name.upper(), value)
    throttle.set_limiter(throttle.InMemoryRateLimiter())


def _verify(client, email="waiting@gmail.com", token="12345678"):
    return client.post(VERIFY, json={"email": email, "token": token})


def _resend(client, email="waiting@gmail.com"):
    return client.post(RESEND, json={"email": email})


def test_the_verify_address_limit_refuses_the_nth_plus_one(
    mock_client, upstream, monkeypatch
):
    _limits(monkeypatch, verify_per_address=2, verify_per_account=100)
    client, _ = mock_client
    recorded = upstream({("POST", "/auth/v1/verify"): BAD_CODE})

    assert _verify(client, "a@gmail.com").status_code == 400
    assert _verify(client, "b@gmail.com").status_code == 400
    assert len(recorded.requests) == 2

    refused = _verify(client, "c@gmail.com")

    assert refused.status_code == 429, refused.text
    assert refused.json()["detail"] == errors._THROTTLED
    assert refused.headers.get("Retry-After")
    assert len(recorded.requests) == 2


def test_the_verify_account_limit_counts_address_spelling(
    mock_client, upstream, monkeypatch
):
    _limits(monkeypatch, verify_per_address=100, verify_per_account=2)
    client, _ = mock_client
    recorded = upstream({("POST", "/auth/v1/verify"): BAD_CODE})

    assert _verify(client, "same@gmail.com").status_code == 400
    assert _verify(client, "same@gmail.com").status_code == 400

    refused = _verify(client, "Same@Gmail.com")

    assert refused.status_code == 429, refused.text
    assert len(recorded.requests) == 2


def test_the_resend_account_limit_refuses_the_nth_plus_one(
    mock_client, upstream, monkeypatch
):
    _limits(monkeypatch, resend_per_address=100, resend_per_account=1)
    client, _ = mock_client
    recorded = upstream({("POST", "/auth/v1/resend"): supabase_json(200, {})})

    assert _resend(client, "same@gmail.com").status_code == 202

    refused = _resend(client, "same@gmail.com")

    assert refused.status_code == 429, refused.text
    assert refused.headers.get("Retry-After")
    assert len(recorded.requests) == 1


def test_the_resend_address_limit_refuses_across_accounts(
    mock_client, upstream, monkeypatch
):
    _limits(monkeypatch, resend_per_address=1, resend_per_account=100)
    client, _ = mock_client
    recorded = upstream({("POST", "/auth/v1/resend"): supabase_json(200, {})})

    assert _resend(client, "a@gmail.com").status_code == 202

    refused = _resend(client, "b@gmail.com")

    assert refused.status_code == 429, refused.text
    assert len(recorded.requests) == 1
