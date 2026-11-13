"""The Profile timezone captured at registration.

The client sends the device's IANA zone in `data.timezone`; the profile
trigger copies it onto the row. Omitting it means Jakarta (the product
default), and an unknown zone is refused before any upstream call.

The seam is the same as every offline auth test: the HTTP surface plus the
injected Supabase transport.
"""

import json

import pytest

from conftest import captured, supabase_json

pytestmark = pytest.mark.local

REGISTER = "/auth/register"

PROFILE = captured("profiles-select-2026-11-10")

PENDING_USER_ID = "00000000-0000-4000-8000-0000000000ab"


def _pending_user():
    return {
        "id": PENDING_USER_ID,
        "aud": "authenticated",
        "role": "authenticated",
        "email": "tz@gmail.com",
        "email_confirmed_at": None,
        "identities": [{"identity_id": PENDING_USER_ID, "provider": "email"}],
        "user_metadata": {"name": "Tz", "role": "mother"},
    }


def _register(client, **extra):
    payload = {
        "name": "Tz",
        "email": "tz@gmail.com",
        "password": "Sup3rSecure!",
        "role": "mother",
    }
    payload.update(extra)
    return client.post(REGISTER, json=payload)


def _signup_data(recorded) -> dict:
    for request in recorded.requests:
        if request.url.path.endswith("/auth/v1/signup"):
            return json.loads(request.content)["data"]
    raise AssertionError("no signup request was recorded")


def _routes():
    return {
        ("POST", "/auth/v1/signup"): supabase_json(200, _pending_user()),
        ("GET", "/rest/v1/profiles"): supabase_json(200, [PROFILE]),
    }


def test_an_omitted_timezone_sends_the_jakarta_default(mock_client, upstream):
    client, _ = mock_client
    recorded = upstream(_routes())

    resp = _register(client)

    assert resp.status_code == 201, resp.text
    assert _signup_data(recorded)["timezone"] == "Asia/Jakarta"


def test_an_explicit_timezone_is_forwarded_to_signup(mock_client, upstream):
    client, _ = mock_client
    recorded = upstream(_routes())

    resp = _register(client, timezone="Pacific/Kiritimati")

    assert resp.status_code == 201, resp.text
    assert _signup_data(recorded)["timezone"] == "Pacific/Kiritimati"


def test_an_unknown_timezone_is_422_without_an_upstream_call(mock_client, upstream):
    client, _ = mock_client
    recorded = upstream(_routes())

    resp = _register(client, timezone="Not/AZone")

    assert resp.status_code == 422, resp.text
    assert "timezone" in resp.text.lower()
    assert recorded.requests == []
