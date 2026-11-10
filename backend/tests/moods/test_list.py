import pytest


@pytest.mark.live
def test_get_mood(client, register):
    email, user, token = register()
    
    client.post(
        "/moods",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "created_at": "2026-11-10",
            "mood": 4,
            "description": "Found clarity",
        },
    )
    
    resp = client.get(
        "/moods/2026-11-10",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["user_id"] == user["id"]
    assert body["mood"] == 4
    assert body["created_at"] == "2026-11-10"
    assert body["description"] == "Found clarity"


@pytest.mark.live
def test_get_mood_not_found(client, register):
    email, user, token = register()
    
    resp = client.get(
        "/moods/2026-11-10",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 404


@pytest.mark.live
def test_get_mood_invalid_date_format(client, register):
    email, user, token = register()
    
    resp = client.get(
        "/moods/2026-13-45",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 400
    assert "date" in resp.json()["detail"].lower()


def test_get_mood_no_auth(client):
    resp = client.get("/moods/2026-11-10")
    assert resp.status_code == 401


@pytest.mark.live
def test_list_moods(client, register):
    email, user, token = register()
    
    client.post(
        "/moods",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "created_at": "2026-11-10",
            "mood": 5,
            "description": "Entry 0",
        },
    )

    resp = client.get(
        "/moods",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["count"] == 1
    assert len(body["moods"]) == 1
    assert body["moods"][0]["created_at"] == "2026-11-10"
    assert body["moods"][0]["mood"] == 5
    assert body["moods"][0]["description"] == "Entry 0"


@pytest.mark.live
def test_list_moods_with_range(client, register):
    email, user, token = register()
    
    client.post(
        "/moods",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "created_at": "2026-11-10",
            "mood": 3,
        },
    )

    resp = client.get(
        "/moods",
        headers={"Authorization": f"Bearer {token}"},
        params={
            "start_date": "2026-11-10",
            "end_date": "2026-11-10",
        },
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["count"] == 1
