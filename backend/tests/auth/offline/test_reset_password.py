"""`POST /auth/reset-password`: finish the reset with the emailed code.

The code is exchanged for a short-lived session (`type=recovery`), the new
password is written through it, and that session is revoked at once. A wrong
or expired code answers the same `400`, so the endpoint cannot be used to
tell whether an address is registered.
"""

import json

import pytest

from conftest import supabase_error, supabase_json

pytestmark = pytest.mark.local

RESET = "/auth/reset-password"
VERIFY = ("POST", "/auth/v1/verify")
UPDATE_USER = ("PUT", "/auth/v1/user")
LOGOUT = ("POST", "/auth/v1/logout")

RECOVERY_SESSION = {
    "access_token": "RECOVERY-ACCESS-TOKEN",
    "refresh_token": "RECOVERY-REFRESH-TOKEN",
    "user": {"id": "00000000-0000-4000-8000-000000000002", "email": "bunda@gmail.com"},
}

ROUTES = {
    VERIFY: supabase_json(200, RECOVERY_SESSION),
    UPDATE_USER: supabase_json(200, {}),
    LOGOUT: supabase_json(200, {}),
}

BAD_CODE = supabase_error(403, "Invalid or expired token", "otp_expired")


def _reset(client, token="12345678", new_password="N3wSecure!pass"):
    return client.post(
        RESET,
        json={
            "email": "bunda@gmail.com",
            "token": token,
            "new_password": new_password,
        },
    )


def _sent(recorded, path):
    return [r for r in recorded.requests if r.url.path == path][0]


def test_a_good_code_answers_204(mock_client, upstream):
    client, _ = mock_client
    upstream(ROUTES)

    resp = _reset(client)

    assert resp.status_code == 204, resp.text
    assert resp.content == b""


def test_it_verifies_with_the_recovery_type(mock_client, upstream):
    client, _ = mock_client
    recorded = upstream(ROUTES)

    _reset(client)

    sent = recorded.requests[0]
    assert sent.url.path == "/auth/v1/verify"
    assert sent.url.params.get("type") == "recovery"
    assert json.loads(sent.content)["type"] == "recovery"
    assert json.loads(sent.content)["email"] == "bunda@gmail.com"


def test_it_writes_the_new_password_through_the_recovery_session(
    mock_client, upstream
):
    client, _ = mock_client
    recorded = upstream(ROUTES)

    _reset(client, new_password="An0therSecure!pass")

    sent = _sent(recorded, "/auth/v1/user")
    assert sent.method == "PUT"
    assert sent.headers["Authorization"] == "Bearer RECOVERY-ACCESS-TOKEN"
    assert json.loads(sent.content)["password"] == "An0therSecure!pass"


def test_it_revokes_the_recovery_session(mock_client, upstream):
    client, _ = mock_client
    recorded = upstream(ROUTES)

    _reset(client)

    sent = _sent(recorded, "/auth/v1/logout")
    assert sent.headers["Authorization"] == "Bearer RECOVERY-ACCESS-TOKEN"
    assert sent.url.params.get("scope") == "global"


def test_a_wrong_code_is_400_with_one_message(mock_client, upstream):
    client, _ = mock_client
    upstream({VERIFY: BAD_CODE})

    resp = _reset(client, token="00000000")

    assert resp.status_code == 400, resp.text
    assert resp.json()["detail"] == "Kode reset salah atau sudah kedaluwarsa."


def test_an_expired_code_reads_the_same_as_a_wrong_one(mock_client, upstream):
    client, _ = mock_client
    upstream(
        {
            VERIFY: supabase_error(
                400, "Email link is invalid or has expired", "otp_expired"
            )
        }
    )

    resp = _reset(client, token="87654321")

    assert resp.status_code == 400, resp.text
    assert resp.json()["detail"] == "Kode reset salah atau sudah kedaluwarsa."


def test_a_short_new_password_is_422_without_an_upstream_call(mock_client, upstream):
    client, _ = mock_client
    recorded = upstream(ROUTES)

    resp = _reset(client, new_password="short")

    assert resp.status_code == 422, resp.text
    assert recorded.requests == []


def test_an_unreachable_upstream_is_503(mock_client, upstream):
    import httpx

    client, _ = mock_client

    def unreachable(_request):
        raise httpx.ConnectError("connection refused")

    upstream({VERIFY: unreachable})

    assert _reset(client).status_code == 503
