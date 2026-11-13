"""`POST /auth/resend-confirmation` answers the same thing for everyone.

The route is deliberately useless as an account oracle: registered or not,
confirmed or not, it answers `202` with one body. Only an unreachable upstream
(`503`) or an upstream rate limit (`429`) is surfaced, because something is
genuinely wrong then.
"""

import pytest

from conftest import supabase_error, supabase_json

pytestmark = pytest.mark.local

RESEND = "/auth/resend-confirmation"

NEUTRAL = {"detail": "Jika email terdaftar, kode verifikasi sudah dikirim ulang."}


def _resend(client, email="someone@gmail.com"):
    return client.post(RESEND, json={"email": email})


def test_a_known_address_is_202_with_the_neutral_body(mock_client, upstream):
    client, _ = mock_client
    upstream({("POST", "/auth/v1/resend"): supabase_json(200, {})})

    resp = _resend(client, "known@gmail.com")

    assert resp.status_code == 202, resp.text
    assert resp.json() == NEUTRAL


def test_an_unknown_address_looks_identical(mock_client, upstream):
    client, _ = mock_client
    upstream({("POST", "/auth/v1/resend"): supabase_json(200, {})})

    known = _resend(client, "known@gmail.com")
    unknown = _resend(client, "nobody@gmail.com")

    assert known.status_code == unknown.status_code == 202
    assert known.content == unknown.content


def test_it_asks_for_the_signup_confirmation(mock_client, upstream):
    import json

    client, _ = mock_client
    recorded = upstream({("POST", "/auth/v1/resend"): supabase_json(200, {})})

    _resend(client, "known@gmail.com")

    assert json.loads(recorded.requests[0].content) == {
        "type": "signup",
        "email": "known@gmail.com",
    }


def test_an_upstream_refusal_is_still_202(mock_client, upstream):
    client, _ = mock_client
    upstream(
        {
            ("POST", "/auth/v1/resend"): supabase_error(
                422, "User not found", "user_not_found"
            )
        }
    )

    assert _resend(client).status_code == 202


def test_an_unreachable_upstream_is_503(mock_client, upstream):
    import httpx

    client, _ = mock_client

    def unreachable(_request):
        raise httpx.ConnectError("connection refused")

    upstream({("POST", "/auth/v1/resend"): unreachable})

    assert _resend(client).status_code == 503


def test_an_upstream_rate_limit_is_429_not_503(mock_client, upstream):
    client, _ = mock_client
    upstream(
        {
            ("POST", "/auth/v1/resend"): supabase_error(
                429, "Request rate limit reached", "over_email_send_rate_limit"
            )
        }
    )

    resp = _resend(client)

    assert resp.status_code == 429, resp.text
    assert resp.headers.get("Retry-After")
