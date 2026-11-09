import httpx
import pytest

from conftest import (
    captured,
    captured_empty,
    supabase_error,
    supabase_json,
)

pytestmark = pytest.mark.local

PROFILE = captured("profiles-select-2026-11-09")

AUTH = {"Authorization": "Bearer offline-token"}


def _profile_route(profile=None):
    return ("GET", "/rest/v1/profiles"), supabase_json(200, [profile or PROFILE])


def test_throttled_verification_is_503_and_changes_nothing(mock_client, upstream):
    client, _ = mock_client
    (method, suffix), response = _profile_route()
    rec = upstream(
        {
            (method, suffix): response,
            ("POST", "/auth/v1/token"): supabase_error(
                429, "Request rate limit reached", "over_email_send_rate_limit"
            ),
        }
    )

    resp = client.post(
        "/auth/password",
        headers=AUTH,
        json={"current_password": "current", "new_password": "N3wSecure!pass"},
    )

    assert resp.status_code == 503, resp.text
    assert "incorrect" not in resp.text.lower()
    assert "rate limit" in resp.text.lower()
    assert not [r for r in rec.requests if r.url.path == "/auth/v1/user"]


def test_unreachable_upstream_is_503_on_login(mock_client, upstream):
    client, _ = mock_client

    def unreachable(_request):
        raise httpx.ConnectError("connection refused")

    rec = upstream({("POST", "/auth/v1/token"): unreachable})

    resp = client.post(
        "/auth/login", json={"email": "someone@gmail.com", "password": "Sup3rSecure!"}
    )

    assert resp.status_code == 503, resp.text
    assert "unreachable" in resp.text.lower()
    assert len(rec.requests) == 1


def test_unreachable_upstream_is_503_on_patch_me(mock_client, upstream):
    client, _ = mock_client

    def unreachable(_request):
        raise httpx.ConnectError("connection refused")

    rec = upstream({("GET", "/rest/v1/profiles"): unreachable})

    resp = client.patch("/me", headers=AUTH, json={"name": "New Name"})

    assert resp.status_code == 503, resp.text
    assert "unreachable" in resp.text.lower()
    assert len(rec.requests) == 1


def test_patch_me_when_no_row_matched_is_not_a_false_200(mock_client, upstream):
    client, _ = mock_client
    (method, suffix), response = _profile_route()
    rec = upstream(
        {
            (method, suffix): response,
            ("PATCH", "/rest/v1/profiles"): supabase_json(200, []),
        }
    )

    resp = client.patch("/me", headers=AUTH, json={"name": "New Name"})

    assert resp.status_code == 503, resp.text
    assert resp.status_code != 200
    assert [r for r in rec.requests if r.method == "PATCH"]


def test_partial_soft_delete_retry_completes_it(mock_client, upstream):
    client, _ = mock_client
    (method, suffix), response = _profile_route()
    ban_attempts = {"n": 0}

    def ban(_request):
        ban_attempts["n"] += 1
        if ban_attempts["n"] == 1:
            return supabase_error(500, "upstream exploded", "unexpected_failure")
        return supabase_json(200, captured("admin-user-ban-2026-11-09"))

    upstream(
        {
            (method, suffix): response,
            ("POST", "/auth/v1/logout"): captured_empty("auth-logout-2026-11-09"),
            ("PUT", f"/auth/v1/admin/users/{PROFILE['user_id']}"): ban,
            ("PATCH", "/rest/v1/profiles"): captured_empty(
                "profiles-patch-tombstone-2026-11-09"
            ),
        }
    )

    first = client.delete("/me", headers=AUTH)
    assert first.status_code == 503, first.text

    second = client.delete("/me", headers=AUTH)
    assert second.status_code == 204, second.text
    assert ban_attempts["n"] == 2, "retry must attempt the ban again"


def test_deleted_profile_read_is_403_not_500(mock_client, upstream):
    client, _ = mock_client
    (method, suffix), _ = _profile_route()
    upstream(
        {
            (method, suffix): supabase_json(
                200, [{**PROFILE, "deleted_at": "2026-11-09T00:00:00+00:00"}]
            )
        }
    )

    resp = client.get("/me", headers=AUTH)

    assert resp.status_code == 403, resp.text
    assert "deleted" in resp.json()["detail"].lower()


def test_transport_still_builds_real_requests(mock_client, upstream):
    client, _ = mock_client
    (method, suffix), response = _profile_route()
    rec = upstream({(method, suffix): response})

    assert client.get("/me", headers=AUTH).status_code == 200

    assert len(rec.requests) == 1
    sent = rec.requests[0]
    assert sent.url.host == "offline.supabase.test"
    assert sent.url.path == "/rest/v1/profiles"
    assert sent.headers["apikey"] == "offline-secret"


def test_register_reads_the_flat_signup_shape(mock_client, upstream):
    client, _ = mock_client
    signup = captured("auth-signup-2026-11-09")
    user_id = signup["user"]["id"]

    upstream(
        {
            ("POST", "/auth/v1/signup"): supabase_json(200, signup),
            ("GET", "/rest/v1/profiles"): supabase_json(
                200, [{**PROFILE, "user_id": user_id}]
            ),
        }
    )

    resp = client.post(
        "/auth/register",
        json={
            "name": "Capture User",
            "email": "offline@gmail.com",
            "password": "Sup3rSecure!",
            "role": "mother",
        },
    )

    assert resp.status_code == 201, resp.text
    body = resp.json()
    assert body["access_token"] == signup["access_token"]
    assert body["user"]["email"] == "offline@gmail.com"
    assert body["user"]["role"] == "mother"
