from uuid import uuid4

import pytest

pytestmark = pytest.mark.live


def test_logout_returns_204(client, supabase_env, register):
    _, _, token = register(name="Logging Out")
    resp = client.post("/auth/logout", headers={"Authorization": f"Bearer {token}"})
    assert resp.status_code == 204, resp.text


def test_logout_for_deleted_user_is_403(client, supabase_env, register):
    _, _, token = register()
    assert client.delete("/me", headers={"Authorization": f"Bearer {token}"}).status_code == 204
    resp = client.post("/auth/logout", headers={"Authorization": f"Bearer {token}"})
    assert resp.status_code == 403, resp.text
    assert "deleted" in resp.json()["detail"].lower()


def test_logout_is_idempotent(client, supabase_env, register):
    _, _, token = register()
    headers = {"Authorization": f"Bearer {token}"}
    first = client.post("/auth/logout", headers=headers)
    assert first.status_code == 204, first.text
    second = client.post("/auth/logout", headers=headers)
    assert second.status_code == 204, second.text


def test_logout_kills_every_session(client, supabase_env, register):
    email, _, _ = register()
    from app import supabase as sb

    first = sb.login(email, "Sup3rSecure!")
    second = sb.login(email, "Sup3rSecure!")

    resp = client.post(
        "/auth/logout", headers={"Authorization": f"Bearer {first['access_token']}"}
    )
    assert resp.status_code == 204, resp.text

    for label, token in (("A (logged out)", first), ("B (other device)", second)):
        refresh = sb.refresh_grant(token["refresh_token"])
        assert refresh.status_code >= 400, f"session {label} survived logout"


def test_login_still_works_after_logout(client, supabase_env, register):
    email, _, token = register()
    assert client.post(
        "/auth/logout", headers={"Authorization": f"Bearer {token}"}
    ).status_code == 204

    resp = client.post(
        "/auth/login", json={"email": email, "password": "Sup3rSecure!"}
    )
    assert resp.status_code == 200, resp.text
    assert resp.json()["access_token"]


def test_logout_for_banned_but_not_tombstoned_user_is_403(
    client, supabase_env, register
):
    _, user, token = register()
    from app import supabase as sb

    sb.ban_user(user["id"])

    resp = client.post("/auth/logout", headers={"Authorization": f"Bearer {token}"})
    assert resp.status_code == 403, resp.text
    assert "deleted" in resp.json()["detail"].lower()
