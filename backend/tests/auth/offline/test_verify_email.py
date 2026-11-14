"""`POST /auth/verify-email`: exchange the signup code for a session.

The endpoint logs the caller in on success, so a confirmed user does not have
to type the password a second time. A wrong or expired code answers one
`400`, whichever it was, so the endpoint cannot be used to tell whether an
address is registered.
"""

import pytest

from conftest import captured, supabase_error, supabase_json

pytestmark = pytest.mark.local

VERIFY = "/auth/verify-email"

PROFILE = captured("profiles-select-2026-11-09")

VERIFIED_SESSION = {
    "access_token": "OFFLINE-ACCESS-TOKEN",
    "token_type": "bearer",
    "expires_in": 3600,
    "refresh_token": "OFFLINE-REFRESH-TOKEN",
    "user": {
        "id": "00000000-0000-4000-8000-000000000001",
        "email": "offline@gmail.com",
        "email_confirmed_at": "2026-11-13T00:00:00Z",
        "user_metadata": {"name": "Capture User", "role": "mother"},
    },
}

BAD_CODE = supabase_error(403, "Invalid or expired token", "otp_expired")


def _verify(client, token="12345678", email="offline@gmail.com"):
    return client.post(VERIFY, json={"email": email, "token": token})


def test_a_good_code_is_200_and_logs_the_caller_in(mock_client, upstream):
    client, _ = mock_client
    upstream(
        {
            ("POST", "/auth/v1/verify"): supabase_json(200, VERIFIED_SESSION),
            ("GET", "/rest/v1/profiles"): supabase_json(200, [PROFILE]),
        }
    )

    resp = _verify(client)

    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["access_token"] == "OFFLINE-ACCESS-TOKEN"
    assert body["refresh_token"] == "OFFLINE-REFRESH-TOKEN"
    assert body["expires_in"] == 3600
    assert body["user"]["email"] == "offline@gmail.com"
    assert body["user"]["name"] == "Capture User"


def test_it_sends_the_signup_type_both_ways(mock_client, upstream):
    import json

    client, _ = mock_client
    recorded = upstream(
        {
            ("POST", "/auth/v1/verify"): supabase_json(200, VERIFIED_SESSION),
            ("GET", "/rest/v1/profiles"): supabase_json(200, [PROFILE]),
        }
    )

    _verify(client)

    sent = recorded.requests[0]
    assert sent.url.params.get("type") == "signup"
    assert json.loads(sent.content)["type"] == "signup"
    assert json.loads(sent.content)["email"] == "offline@gmail.com"


def test_a_wrong_code_is_400_with_one_message(mock_client, upstream):
    client, _ = mock_client
    upstream({("POST", "/auth/v1/verify"): BAD_CODE})

    resp = _verify(client, token="00000000")

    assert resp.status_code == 400, resp.text
    assert resp.json()["detail"] == "Kode verifikasi salah atau sudah kedaluwarsa."


def test_an_expired_code_reads_the_same_as_a_wrong_one(mock_client, upstream):
    client, _ = mock_client
    upstream(
        {
            ("POST", "/auth/v1/verify"): supabase_error(
                400, "Email link is invalid or has expired", "otp_expired"
            )
        }
    )

    resp = _verify(client, token="87654321")

    assert resp.status_code == 400, resp.text
    assert resp.json()["detail"] == "Kode verifikasi salah atau sudah kedaluwarsa."


def test_an_unreachable_upstream_is_503(mock_client, upstream):
    import httpx

    client, _ = mock_client

    def unreachable(_request):
        raise httpx.ConnectError("connection refused")

    upstream({("POST", "/auth/v1/verify"): unreachable})

    assert _verify(client).status_code == 503
