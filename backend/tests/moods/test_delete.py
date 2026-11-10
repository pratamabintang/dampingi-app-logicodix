import pytest

from conftest import OTHER_AUTHOR, captured, mood_row

PROFILE = {**captured("profiles-select-2026-11-10"), "role": "mother"}
MOOD_ID = "00000000-0000-4000-8000-0000000000b3"


def _mood(**overrides):
    return {
        **mood_row(PROFILE["user_id"], "2026-10-30", mood=4),
        "id": MOOD_ID,
        **overrides,
    }


def test_a_mood_can_be_deleted_by_id(mock_client, moods_table):
    client, session = mock_client
    moods_table(PROFILE, moods=[_mood()])
    headers = {"Authorization": f"Bearer {session.token}"}

    resp = client.delete(f"/moods/{MOOD_ID}", headers=headers)

    assert resp.status_code == 204, resp.text
    assert client.get(f"/moods/{MOOD_ID}", headers=headers).status_code == 404


def test_deleting_an_unknown_id_is_idempotent(mock_client, moods_table):
    client, session = mock_client
    moods_table(PROFILE)

    resp = client.delete(
        "/moods/00000000-0000-4000-8000-00000000dead",
        headers={"Authorization": f"Bearer {session.token}"},
    )

    assert resp.status_code == 204, resp.text


def test_a_malformed_id_is_a_validation_error(mock_client, moods_table):
    client, session = mock_client
    moods_table(PROFILE, moods=[_mood()])

    resp = client.delete(
        "/moods/not-a-uuid",
        headers={"Authorization": f"Bearer {session.token}"},
    )

    assert resp.status_code == 422, resp.text


def test_another_mothers_mood_id_cannot_be_deleted(
    mock_client, moods_table, real_moods_gate, as_author
):
    client, _ = mock_client
    moods_table(PROFILE, moods=[_mood(description="Private.")])

    as_author(OTHER_AUTHOR)
    resp = client.delete(
        f"/moods/{MOOD_ID}",
        headers={"Authorization": "Bearer offline-token"},
    )

    assert resp.status_code == 204, resp.text

    as_author(PROFILE["user_id"])
    read = client.get(
        f"/moods/{MOOD_ID}",
        headers={"Authorization": "Bearer offline-token"},
    )
    assert read.status_code == 200, read.text
    assert read.json()["description"] == "Private."


@pytest.mark.live
def test_delete_mood(client, register):
    _, _, token = register()
    headers = {"Authorization": f"Bearer {token}"}

    created = client.post(
        "/moods",
        headers=headers,
        json={"created_at": "2026-10-30", "mood": 4},
    )
    assert created.status_code == 201, created.text
    mood_id = created.json()["id"]

    resp = client.delete(f"/moods/{mood_id}", headers=headers)
    assert resp.status_code == 204, resp.text

    resp = client.get(f"/moods/{mood_id}", headers=headers)
    assert resp.status_code == 404, resp.text


@pytest.mark.live
def test_delete_mood_idempotent(client, register):
    _, _, token = register()
    headers = {"Authorization": f"Bearer {token}"}

    resp = client.delete(
        "/moods/00000000-0000-4000-8000-00000000dead", headers=headers
    )
    assert resp.status_code == 204, resp.text


@pytest.mark.live
def test_another_mothers_mood_may_not_be_deleted(client, register):
    _, _, alice = register()
    _, _, bob = register()
    alice_headers = {"Authorization": f"Bearer {alice}"}
    created = client.post(
        "/moods",
        headers=alice_headers,
        json={"created_at": "2026-10-30", "mood": 4, "description": "Private."},
    )
    assert created.status_code == 201, created.text
    mood_id = created.json()["id"]

    resp = client.delete(
        f"/moods/{mood_id}",
        headers={"Authorization": f"Bearer {bob}"},
    )

    assert resp.status_code == 204, resp.text

    mine = client.get(f"/moods/{mood_id}", headers=alice_headers)
    assert mine.status_code == 200, mine.text
    assert mine.json()["description"] == "Private."


def test_delete_mood_no_auth(client):
    resp = client.delete("/moods/00000000-0000-4000-8000-0000000000b3")
    assert resp.status_code == 401


@pytest.mark.live
def test_deleting_the_account_removes_its_moods(client, register):
    from app.auth import supabase as auth_supabase
    from app.config import supabase_service_http
    from app.supabase import TIMEOUT, _base_url, _client, _request

    _, user, token = register()

    created = client.post(
        "/moods",
        headers={"Authorization": f"Bearer {token}"},
        json={"created_at": "2026-10-30", "mood": 4},
    )
    assert created.status_code == 201, created.text

    auth_supabase.delete_user(user["id"])

    rows = auth_supabase.fetch_profile(user["id"])
    assert rows is None, "profile should be gone"

    resp = _request(
        _client().get,
        f"{_base_url()}/rest/v1/moods",
        params={"user_id": f"eq.{user['id']}", "select": "user_id,created_at"},
        headers=supabase_service_http(),
        timeout=TIMEOUT,
    )
    assert resp.status_code == 200, resp.text
    assert resp.json() == [], f"moods outlived their author: {resp.json()}"
