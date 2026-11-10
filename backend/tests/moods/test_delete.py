import pytest


@pytest.mark.live
def test_delete_mood(client, register):
    email, user, token = register()
    
    client.post(
        "/moods",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "created_at": "2026-11-10",
            "mood": "good",
        },
    )
    
    resp = client.delete(
        "/moods/2026-11-10",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 204
    
    resp = client.get(
        "/moods/2026-11-10",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 404


@pytest.mark.live
def test_delete_mood_idempotent(client, register):
    email, user, token = register()
    
    resp = client.delete(
        "/moods/2026-11-10",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 204


def test_delete_mood_no_auth(client):
    resp = client.delete("/moods/2026-11-10")
    assert resp.status_code == 401
