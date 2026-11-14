"""`POST /auth/login` must hand the client the whole Session, not half of it.

The access token lives one hour, so a client that only receives it cannot stay
logged in. The refresh token and its lifetime are part of the login contract;
dropping them would force the client to keep the password instead.
"""

import pytest

from conftest import captured, supabase_json

pytestmark = pytest.mark.local

LOGIN = "/auth/login"

PROFILE = captured("profiles-select-2026-11-09")

LOGIN_SESSION = {
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


def _login(client, password="correct-horse"):
    return client.post(LOGIN, json={"email": "offline@gmail.com", "password": password})


def test_login_returns_the_refresh_token_and_its_lifetime(mock_client, upstream):
    client, _ = mock_client
    upstream(
        {
            ("POST", "/auth/v1/token"): supabase_json(200, LOGIN_SESSION),
            ("GET", "/rest/v1/profiles"): supabase_json(200, [PROFILE]),
        }
    )

    resp = _login(client)

    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["access_token"] == "OFFLINE-ACCESS-TOKEN"
    assert body["refresh_token"] == "OFFLINE-REFRESH-TOKEN"
    assert body["expires_in"] == 3600
    assert body["user"]["email"] == "offline@gmail.com"
    assert body["user"]["role"] == "mother"


def test_login_does_not_log_the_tokens(mock_client, upstream, caplog):
    client, _ = mock_client
    upstream(
        {
            ("POST", "/auth/v1/token"): supabase_json(200, LOGIN_SESSION),
            ("GET", "/rest/v1/profiles"): supabase_json(200, [PROFILE]),
        }
    )

    _login(client)

    logs = "\n".join(record.getMessage() for record in caplog.records)
    assert "OFFLINE-ACCESS-TOKEN" not in logs
    assert "OFFLINE-REFRESH-TOKEN" not in logs
