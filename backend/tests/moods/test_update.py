import pytest

from conftest import OTHER_AUTHOR, captured, mood_row

PROFILE = {**captured("profiles-select-2026-11-10"), "role": "mother"}
MOOD_ID = "00000000-0000-4000-8000-0000000000b2"


def _mood(**overrides):
    return {
        **mood_row(PROFILE["user_id"], "2026-10-30", mood=4),
        "id": MOOD_ID,
        **overrides,
    }


def test_a_mood_can_be_updated_by_id(mock_client, moods_table):
    client, session = mock_client
    moods_table(PROFILE, moods=[_mood()])

    resp = client.patch(
        f"/moods/{MOOD_ID}",
        headers={"Authorization": f"Bearer {session.token}"},
        json={"mood": 5, "description": "Better now"},
    )

    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["id"] == MOOD_ID
    assert body["created_at"] == "2026-10-30"
    assert body["mood"] == 5
    assert body["description"] == "Better now"


def test_an_unknown_well_formed_id_is_not_found(mock_client, moods_table):
    client, session = mock_client
    moods_table(PROFILE)

    resp = client.patch(
        "/moods/00000000-0000-4000-8000-00000000dead",
        headers={"Authorization": f"Bearer {session.token}"},
        json={"mood": 5},
    )

    assert resp.status_code == 404, resp.text


def test_a_malformed_id_is_a_validation_error(mock_client, moods_table):
    client, session = mock_client
    moods_table(PROFILE, moods=[_mood()])

    resp = client.patch(
        "/moods/not-a-uuid",
        headers={"Authorization": f"Bearer {session.token}"},
        json={"mood": 5},
    )

    assert resp.status_code == 422, resp.text


def test_another_mothers_mood_id_cannot_be_edited(
    mock_client, moods_table, real_moods_gate, as_author
):
    client, _ = mock_client
    moods_table(PROFILE, moods=[_mood(description="Private.")])

    as_author(OTHER_AUTHOR)
    resp = client.patch(
        f"/moods/{MOOD_ID}",
        headers={"Authorization": "Bearer offline-token"},
        json={"mood": 1, "description": "Hijacked"},
    )

    assert resp.status_code == 404, resp.text
    assert resp.status_code != 403

    as_author(PROFILE["user_id"])
    read = client.get(
        f"/moods/{MOOD_ID}",
        headers={"Authorization": "Bearer offline-token"},
    )
    assert read.status_code == 200, read.text
    assert read.json()["mood"] == 4
    assert read.json()["description"] == "Private."


@pytest.mark.live
def test_update_mood(client, register):
    _, _, token = register()
    headers = {"Authorization": f"Bearer {token}"}

    created = client.post(
        "/moods",
        headers=headers,
        json={"created_at": "2026-10-30", "mood": 4},
    )
    assert created.status_code == 201, created.text
    mood_id = created.json()["id"]

    resp = client.patch(
        f"/moods/{mood_id}",
        headers=headers,
        json={"mood": 5},
    )
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["id"] == mood_id
    assert body["mood"] == 5
    assert body["created_at"] == "2026-10-30"
    assert body["description"] is None

    resp = client.patch(
        f"/moods/{mood_id}",
        headers=headers,
        json={"description": "Better now"},
    )
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["mood"] == 5
    assert body["description"] == "Better now"


@pytest.mark.live
def test_update_mood_not_found(client, register):
    _, _, token = register()

    resp = client.patch(
        "/moods/00000000-0000-4000-8000-00000000dead",
        headers={"Authorization": f"Bearer {token}"},
        json={"mood": 5},
    )
    assert resp.status_code == 404, resp.text


@pytest.mark.live
def test_update_mood_malformed_id(client, register):
    _, _, token = register()

    resp = client.patch(
        "/moods/not-a-uuid",
        headers={"Authorization": f"Bearer {token}"},
        json={"mood": 4},
    )
    assert resp.status_code == 422, resp.text


@pytest.mark.live
def test_another_mothers_mood_may_not_be_edited(client, register):
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

    resp = client.patch(
        f"/moods/{mood_id}",
        headers={"Authorization": f"Bearer {bob}"},
        json={"mood": 1, "description": "Hijacked"},
    )

    assert resp.status_code == 404, resp.text
    assert resp.status_code != 403

    mine = client.get(f"/moods/{mood_id}", headers=alice_headers)
    assert mine.status_code == 200, mine.text
    assert mine.json()["mood"] == 4
    assert mine.json()["description"] == "Private."


def test_update_mood_rejects_extra_fields(mock_client, moods_table):
    client, session = mock_client
    moods_table(PROFILE, moods=[_mood()])

    resp = client.patch(
        f"/moods/{MOOD_ID}",
        headers={"Authorization": f"Bearer {session.token}"},
        json={"mood": 4, "created_at": "2026-10-31"},
    )
    assert resp.status_code == 422, resp.text


def test_update_mood_no_auth(client):
    resp = client.patch(
        f"/moods/{MOOD_ID}",
        json={"mood": 4},
    )
    assert resp.status_code == 401
