"""`POST /auth/refresh`: trade a refresh token for a fresh Session pair.

The refresh token is the credential that lets a client stay logged in without
keeping the password. Every successful call rotates it; a token that Supabase
no longer accepts ends the Session with a clear 401, never a login prompt that
says the password was wrong.
"""

import json

import pytest

from conftest import supabase_error, supabase_json

pytestmark = pytest.mark.local

REFRESH = "/auth/refresh"

REFRESHED = {
    "access_token": "NEW-ACCESS-TOKEN",
    "token_type": "bearer",
    "expires_in": 3600,
    "refresh_token": "NEW-REFRESH-TOKEN",
}


def _refresh(client, token="OLD-REFRESH-TOKEN"):
    return client.post(REFRESH, json={"refresh_token": token})


def test_refresh_returns_the_new_pair(mock_client, upstream):
    client, _ = mock_client
    upstream({("POST", "/auth/v1/token"): supabase_json(200, REFRESHED)})

    resp = _refresh(client)

    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["access_token"] == "NEW-ACCESS-TOKEN"
    assert body["refresh_token"] == "NEW-REFRESH-TOKEN"
    assert body["expires_in"] == 3600


def test_refresh_sends_the_token_to_supabase_as_a_refresh_grant(
    mock_client, upstream
):
    client, _ = mock_client
    recorded = upstream(
        {("POST", "/auth/v1/token"): supabase_json(200, REFRESHED)}
    )

    _refresh(client, "TOKEN-FROM-DEVICE")

    request = recorded.requests[0]
    assert request.url.params["grant_type"] == "refresh_token"
    assert json.loads(request.content) == {"refresh_token": "TOKEN-FROM-DEVICE"}


def test_a_rotated_token_cannot_be_reused(mock_client, upstream):
    client, _ = mock_client

    def by_call(_request):
        if len(recorded.requests) == 1:
            return supabase_json(200, REFRESHED)
        return supabase_error(400, "Invalid Refresh Token", "refresh_token_not_found")

    recorded = upstream({("POST", "/auth/v1/token"): by_call})

    first = _refresh(client, "OLD-REFRESH-TOKEN")
    second = _refresh(client, "OLD-REFRESH-TOKEN")

    assert first.status_code == 200
    assert first.json()["refresh_token"] == "NEW-REFRESH-TOKEN"
    assert second.status_code == 401
    assert second.json()["detail"] == "Sesi tidak valid. Silakan masuk kembali."


def test_an_unknown_or_expired_token_is_401(mock_client, upstream):
    client, _ = mock_client
    upstream(
        {
            ("POST", "/auth/v1/token"): supabase_error(
                400, "Invalid Refresh Token", "refresh_token_not_found"
            )
        }
    )

    resp = _refresh(client)

    assert resp.status_code == 401
    assert resp.json()["detail"] == "Sesi tidak valid. Silakan masuk kembali."


def test_a_missing_refresh_token_is_rejected_before_upstream(mock_client, upstream):
    client, _ = mock_client
    recorded = upstream({})

    resp = client.post(REFRESH, json={"refresh_token": ""})

    assert resp.status_code == 422
    assert recorded.requests == []


def test_refresh_is_throttled_per_address(mock_client, upstream):
    from app import throttle

    throttle.set_limiter(throttle.InMemoryRateLimiter())
    client, _ = mock_client
    upstream({("POST", "/auth/v1/token"): supabase_json(200, REFRESHED)})

    last = None
    for _ in range(throttle.REFRESH_PER_ADDRESS + 1):
        last = _refresh(client)

    assert last.status_code == 429
    assert last.headers["Retry-After"]
