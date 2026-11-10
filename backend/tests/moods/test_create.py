import pytest


@pytest.mark.live
def test_create_mood(client, register):
    email, user, token = register()
    
    resp = client.post(
        "/moods",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "created_at": "2026-11-10",
            "mood": 4,
        },
    )
    assert resp.status_code == 201
    body = resp.json()
    assert body["user_id"] == user["id"]
    assert body["mood"] == 4
    assert body["created_at"] == "2026-11-10"
    assert body["description"] is None


@pytest.mark.live
def test_create_mood_with_description(client, register):
    email, user, token = register()
    
    resp = client.post(
        "/moods",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "created_at": "2026-11-10",
            "mood": 5,
            "description": "Feeling great today!",
        },
    )
    assert resp.status_code == 201
    body = resp.json()
    assert body["mood"] == 5
    assert body["description"] == "Feeling great today!"


def test_create_mood_future_rejected(mock_client):
    client, session = mock_client
    
    resp = client.post(
        "/moods",
        headers={"Authorization": f"Bearer {session.token}"},
        json={
            "created_at": "2099-12-31",
            "mood": 3,
        },
    )
    assert resp.status_code == 400
    assert "future" in resp.json()["detail"].lower()


def test_create_mood_invalid_date_format(mock_client):
    client, session = mock_client
    
    resp = client.post(
        "/moods",
        headers={"Authorization": f"Bearer {session.token}"},
        json={
            "created_at": "2026-13-45",
            "mood": 3,
        },
    )
    assert resp.status_code == 400
    assert "date" in resp.json()["detail"].lower()


def test_create_mood_no_auth(client):
    resp = client.post(
        "/moods",
        json={
            "created_at": "2026-11-10",
            "mood": 4,
        },
    )
    assert resp.status_code == 401


@pytest.mark.live
def test_create_mood_invalid_range(client, register):
    email, user, token = register()
    
    resp = client.post(
        "/moods",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "created_at": "2026-11-10",
            "mood": 6,
        },
    )
    assert resp.status_code == 422

    resp = client.post(
        "/moods",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "created_at": "2026-11-10",
            "mood": 0,
        },
    )
    assert resp.status_code == 422


@pytest.mark.live
def test_create_mood_description_too_long(client, register):
    email, user, token = register()
    
    resp = client.post(
        "/moods",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "created_at": "2026-11-10",
            "mood": 3,
            "description": "a" * 501,
        },
    )
    assert resp.status_code == 422
