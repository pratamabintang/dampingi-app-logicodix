"""Changing a password must satisfy the upstream's reauthentication rule.

The hosted project has `security_update_password_require_current_password`
enabled, so GoTrue refuses a `PUT /auth/v1/user` that sets a password without
the current one and answers `400 current_password_required`. That upstream
`400` used to reach the error boundary and come back as a `503` outage. The
route now forwards `current_password`, which it already verified, so the
legitimate change succeeds and a rejection stays a caller-actionable `400`.
"""

import json

import pytest

from conftest import captured, supabase_error, supabase_json

pytestmark = pytest.mark.local

PROFILE = captured("profiles-select-2026-11-09")

AUTH = {"Authorization": "Bearer offline-token"}

TOKEN = ("POST", "/auth/v1/token")
UPDATE_USER = ("PUT", "/auth/v1/user")
LOGOUT = ("POST", "/auth/v1/logout")

STRONG = "Sup3rSecure!"
NEW = "N3wSecure!pass"

_THROWAWAY = {
    "access_token": "THROWAWAY",
    "refresh_token": "THROWAWAY-REFRESH",
    "user": {"id": PROFILE["user_id"], "email": "offline@gmail.com"},
}


def _happy_routes(update_response):
    return {
        ("GET", "/rest/v1/profiles"): supabase_json(200, [PROFILE]),
        TOKEN: supabase_json(200, _THROWAWAY),
        LOGOUT: supabase_json(200, {}),
        UPDATE_USER: update_response,
    }


def test_change_password_forwards_current_password_upstream(mock_client, upstream):
    client, _ = mock_client
    rec = upstream(_happy_routes(supabase_json(200, PROFILE)))

    resp = client.post(
        "/auth/password",
        headers=AUTH,
        json={"current_password": STRONG, "new_password": NEW},
    )

    assert resp.status_code == 204, resp.text
    sent = [r for r in rec.requests if r.url.path == "/auth/v1/user"]
    assert sent, "the update never reached the upstream"
    body = json.loads(sent[0].content)
    assert body == {"password": NEW, "current_password": STRONG}


def test_current_password_required_from_upstream_is_400_not_503(
    mock_client, upstream
):
    client, _ = mock_client
    upstream(
        _happy_routes(
            supabase_error(
                400,
                "Current password required when setting new password.",
                "current_password_required",
            )
        )
    )

    resp = client.post(
        "/auth/password",
        headers=AUTH,
        json={"current_password": STRONG, "new_password": NEW},
    )

    assert resp.status_code == 400, resp.text
    assert resp.status_code != 503
    assert "current password" in resp.json()["detail"].lower()


def test_current_password_invalid_from_upstream_is_400_not_503(mock_client, upstream):
    client, _ = mock_client
    upstream(
        _happy_routes(
            supabase_error(
                400,
                "Current password required when setting new password.",
                "current_password_invalid",
            )
        )
    )

    resp = client.post(
        "/auth/password",
        headers=AUTH,
        json={"current_password": STRONG, "new_password": NEW},
    )

    assert resp.status_code == 400, resp.text
    assert resp.status_code != 503
    assert "incorrect" in resp.json()["detail"].lower()
