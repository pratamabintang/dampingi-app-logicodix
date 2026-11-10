import pytest

from conftest import captured

PROFILE = {**captured("profiles-select-2026-11-10"), "role": "mother"}


@pytest.mark.live
def test_delete_mood(client, register):
    email, user, token = register()
    
    client.post(
        "/moods",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "created_at": "2026-10-30",
            "mood": "good",
        },
    )
    
    resp = client.delete(
        "/moods/2026-10-30",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 204
    
    resp = client.get(
        "/moods/2026-10-30",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 404


@pytest.mark.live
def test_delete_mood_idempotent(client, register):
    email, user, token = register()
    
    resp = client.delete(
        "/moods/2026-10-30",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 204


def test_delete_mood_no_auth(client):
    resp = client.delete("/moods/2026-10-30")
    assert resp.status_code == 401


def test_a_malformed_date_is_a_400_not_an_outage(mock_client, moods_table):
    client, session = mock_client
    moods_table({**PROFILE, "role": "mother"})

    resp = client.delete(
        "/moods/2026-13-45",
        headers={"Authorization": f"Bearer {session.token}"},
    )

    assert resp.status_code == 400, resp.text
    assert "date" in resp.json()["detail"].lower()
