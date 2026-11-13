"""Registration while email confirmation is on.

With confirmation OFF Supabase wraps the answer in `{"user": ..., "session":
...}` (see fixtures/auth-signup-2026-11-09.json). With confirmation ON it
answers with the bare User object: no `user` key, no `session`, and no
token.

An address that already exists and is confirmed does not come back as an
error: Supabase answers `200` with a fabricated user, so the endpoint is not
an oracle for which addresses are registered. The fabrication is recognised
by its empty `identities` list and reported as `409`.
"""

import pytest

from conftest import captured, supabase_json

pytestmark = pytest.mark.local

REGISTER = "/auth/register"

PROFILE = captured("profiles-select-2026-11-09")

PENDING_USER_ID = "00000000-0000-4000-8000-0000000000aa"

IDENTITY = {"identity_id": PENDING_USER_ID, "provider": "email"}


def _pending_user(user_id=PENDING_USER_ID, identities=None):
    return {
        "id": user_id,
        "aud": "authenticated",
        "role": "authenticated",
        "email": "pending@gmail.com",
        "email_confirmed_at": None,
        "identities": [IDENTITY] if identities is None else identities,
        "user_metadata": {"name": "Pending", "role": "mother"},
    }


# What Supabase answers for an address that already exists and is confirmed:
# a fresh random id, empty role and metadata, and no identities.
OBFUSCATED_USER = {
    "id": "07503069-e10c-42c5-9e58-a78f4b39d48e",
    "aud": "authenticated",
    "role": "",
    "email": "taken@gmail.com",
    "email_confirmed_at": None,
    "identities": [],
    "user_metadata": {},
}


def _register(client, email="pending@gmail.com"):
    return client.post(
        REGISTER,
        json={
            "name": "Pending",
            "email": email,
            "password": "Sup3rSecure!",
            "role": "mother",
        },
    )


def test_a_top_level_user_answer_is_201_without_a_token(mock_client, upstream):
    client, _ = mock_client
    upstream(
        {
            ("POST", "/auth/v1/signup"): supabase_json(200, _pending_user()),
            ("GET", "/rest/v1/profiles"): supabase_json(200, [PROFILE]),
        }
    )

    resp = _register(client)

    assert resp.status_code == 201, resp.text
    body = resp.json()
    assert body["access_token"] is None
    assert body["user"]["id"] == PENDING_USER_ID
    assert body["user"]["email"] == "pending@gmail.com"


def test_it_falls_back_to_the_metadata_when_the_profile_is_not_there(
    mock_client, upstream
):
    client, _ = mock_client
    upstream(
        {
            ("POST", "/auth/v1/signup"): supabase_json(200, _pending_user()),
            ("GET", "/rest/v1/profiles"): supabase_json(200, []),
        }
    )

    resp = _register(client)

    assert resp.status_code == 201, resp.text
    assert resp.json()["user"]["name"] == "Pending"
    assert resp.json()["user"]["role"] == "mother"


def test_an_obfuscated_answer_is_409_and_reads_no_profile(mock_client, upstream):
    client, _ = mock_client
    recorded = upstream(
        {
            ("POST", "/auth/v1/signup"): supabase_json(200, OBFUSCATED_USER),
            ("GET", "/rest/v1/profiles"): supabase_json(200, [PROFILE]),
        }
    )

    resp = _register(client, "taken@gmail.com")

    assert resp.status_code == 409, resp.text
    assert "already registered" in resp.json()["detail"].lower()
    assert [r.url.path for r in recorded.requests] == ["/auth/v1/signup"]


def test_a_zero_id_answer_is_409(mock_client, upstream):
    client, _ = mock_client
    upstream(
        {
            ("POST", "/auth/v1/signup"): supabase_json(
                200, _pending_user(user_id="00000000-0000-0000-0000-000000000000")
            ),
            ("GET", "/rest/v1/profiles"): supabase_json(200, [PROFILE]),
        }
    )

    assert _register(client).status_code == 409


def test_the_upstream_cooldown_is_429_not_503(mock_client, upstream):
    from conftest import supabase_error

    client, _ = mock_client
    upstream(
        {
            ("POST", "/auth/v1/signup"): supabase_error(
                429,
                "For security purposes, you can only request this after 57 seconds.",
                "over_email_send_rate_limit",
            )
        }
    )

    resp = _register(client)

    assert resp.status_code == 429, resp.text
    assert resp.headers.get("Retry-After")
