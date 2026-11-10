import pytest


@pytest.mark.live
def test_update_mood(client, register):
    email, user, token = register()
    
    client.post(
        "/moods",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "created_at": "2026-11-10",
            "mood": 4,
        },
    )
    
    resp = client.patch(
        "/moods/2026-11-10",
        headers={"Authorization": f"Bearer {token}"},
        json={"mood": 5},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["mood"] == 5
    assert body["created_at"] == "2026-11-10"
    assert body["description"] is None

    resp = client.patch(
        "/moods/2026-11-10",
        headers={"Authorization": f"Bearer {token}"},
        json={"description": "Better now"},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["mood"] == 5
    assert body["description"] == "Better now"


@pytest.mark.live
def test_update_mood_not_found(client, register):
    email, user, token = register()
    
    resp = client.patch(
        "/moods/2026-11-10",
        headers={"Authorization": f"Bearer {token}"},
        json={"mood": 5},
    )
    assert resp.status_code == 404


@pytest.mark.live
def test_update_mood_invalid_date_format(client, register):
    email, user, token = register()
    
    resp = client.patch(
        "/moods/2026-13-45",
        headers={"Authorization": f"Bearer {token}"},
        json={"mood": 4},
    )
    assert resp.status_code == 400
    assert "date" in resp.json()["detail"].lower()


def test_update_mood_rejects_extra_fields(mock_client):
    client, session = mock_client
    
    resp = client.patch(
        "/moods/2026-11-10",
        headers={"Authorization": f"Bearer {session.token}"},
        json={"mood": 4, "created_at": "2026-11-10"},
    )
    assert resp.status_code == 422


def test_update_mood_no_auth(client):
    resp = client.patch(
        "/moods/2026-11-10",
        json={"mood": 4},
    )
    assert resp.status_code == 401
