import pytest

pytestmark = pytest.mark.live


def test_register_creates_user_session_and_profile(
    client, supabase_env, register
):
    email, user, access_token = register(name="Ada Lovelace")
    assert user["email"] == email
    assert user["name"] == "Ada Lovelace"
    assert access_token


def test_register_duplicate_gmail_conflicts(client, supabase_env, register):
    """A confirmed address is refused, whichever shape Supabase answers with.

    With confirmation on, Supabase answers `200` plus a fabricated user
    instead of an error; the backend recognises it and still says `409`.
    """
    email, _, _ = register(name="Dup")

    resp = client.post(
        "/auth/register",
        json={
            "name": "Dup",
            "email": email,
            "password": "Sup3rSecure!",
            "role": "mother",
        },
    )

    assert resp.status_code == 409, resp.text
    assert "already registered" in resp.json()["detail"].lower()


def test_register_rejects_non_gmail(client, supabase_env, unique_email):
    resp = client.post(
        "/auth/register",
        json={
            "name": "Nope",
            "email": unique_email().replace("@gmail.com", "@outlook.com"),
            "password": "Sup3rSecure!",
            "role": "mother",
        },
    )
    assert resp.status_code == 422
    assert "gmail" in resp.text.lower()


def test_register_rejects_missing_name(client, supabase_env, unique_email):
    resp = client.post(
        "/auth/register",
        json={"email": unique_email(), "password": "Sup3rSecure!", "role": "mother"},
    )
    assert resp.status_code == 422


def test_register_rejects_blank_name(client, supabase_env, unique_email):
    resp = client.post(
        "/auth/register",
        json={
            "name": "",
            "email": unique_email(),
            "password": "Sup3rSecure!",
            "role": "mother",
        },
    )
    assert resp.status_code == 422


def test_register_rejects_short_password(client, supabase_env, unique_email):
    resp = client.post(
        "/auth/register",
        json={
            "name": "Shorty",
            "email": unique_email(),
            "password": "short",
            "role": "mother",
        },
    )
    assert resp.status_code == 422


def test_register_rejects_missing_fields(client, supabase_env):
    resp = client.post("/auth/register", json={})
    assert resp.status_code == 422
