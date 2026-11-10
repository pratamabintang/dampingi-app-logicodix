import pytest

from conftest import captured, supabase_json

PROFILE = {**captured("profiles-select-2026-11-10"), "role": "mother"}


@pytest.mark.live
def test_create_mood(client, register):
    email, user, token = register()
    
    resp = client.post(
        "/moods",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "created_at": "2026-10-30",
            "mood": 4,
        },
    )
    assert resp.status_code == 201
    body = resp.json()
    assert body["user_id"] == user["id"]
    assert body["mood"] == 4
    assert body["created_at"] == "2026-10-30"
    assert body["description"] is None


@pytest.mark.live
def test_create_mood_with_description(client, register):
    email, user, token = register()
    
    resp = client.post(
        "/moods",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "created_at": "2026-10-30",
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
            "created_at": "2026-10-30",
            "mood": 4,
        },
    )
    assert resp.status_code == 401


def test_a_second_mood_for_the_same_day_is_a_conflict(mock_client, moods_table):
    client, session = mock_client
    moods_table(PROFILE)

    first = client.post(
        "/moods",
        headers={"Authorization": f"Bearer {session.token}"},
        json={"created_at": "2026-10-30", "mood": 4},
    )
    assert first.status_code == 201, first.text

    second = client.post(
        "/moods",
        headers={"Authorization": f"Bearer {session.token}"},
        json={"created_at": "2026-10-30", "mood": 2},
    )

    assert second.status_code == 409, second.text
    assert "2026-10-30" in second.json()["detail"]


def test_a_foreign_key_violation_is_not_reported_as_a_duplicate(
    mock_client, upstream
):
    import httpx

    client, session = mock_client

    def profile_get(request):
        asked = request.url.params["select"].split(",")
        return supabase_json(
            200, [{k: PROFILE[k] for k in asked if k in PROFILE}]
        )

    def orphan(_request):
        return httpx.Response(
            409,
            json={
                "code": "23503",
                "details": "Key (user_id)=(...) is not present in table users.",
                "message": "insert or update violates foreign key constraint",
            },
        )

    upstream(
        {
            ("GET", "/rest/v1/profiles"): profile_get,
            ("POST", "/rest/v1/moods"): orphan,
        }
    )

    resp = client.post(
        "/moods",
        headers={"Authorization": f"Bearer {session.token}"},
        json={"created_at": "2026-10-30", "mood": 4},
    )

    assert resp.status_code == 503, resp.text


def test_an_unreachable_upstream_is_503(mock_client, upstream):
    import httpx

    client, session = mock_client

    def profile_get(request):
        asked = request.url.params["select"].split(",")
        return supabase_json(
            200, [{k: PROFILE[k] for k in asked if k in PROFILE}]
        )

    def unreachable(_request):
        raise httpx.ConnectError("connection refused")

    upstream(
        {
            ("GET", "/rest/v1/profiles"): profile_get,
            ("POST", "/rest/v1/moods"): unreachable,
        }
    )

    resp = client.post(
        "/moods",
        headers={"Authorization": f"Bearer {session.token}"},
        json={"created_at": "2026-10-30", "mood": 4},
    )

    assert resp.status_code == 503, resp.text
    assert "unreachable" in resp.text.lower()


def test_a_deleted_profile_may_not_record_a_mood(mock_client, moods_table):
    client, session = mock_client
    moods_table(
        {**PROFILE, "deleted_at": "2026-10-30T00:00:00+00:00"}
    )

    resp = client.post(
        "/moods",
        headers={"Authorization": f"Bearer {session.token}"},
        json={"created_at": "2026-10-30", "mood": 4},
    )

    assert resp.status_code == 404, resp.text


def test_a_missing_profile_is_404(mock_client, upstream):
    client, session = mock_client
    upstream({("GET", "/rest/v1/profiles"): supabase_json(200, [])})

    resp = client.post(
        "/moods",
        headers={"Authorization": f"Bearer {session.token}"},
        json={"created_at": "2026-10-30", "mood": 4},
    )

    assert resp.status_code == 404, resp.text


def test_a_duplicate_is_refused_even_for_a_backfilled_past_day(
    mock_client, moods_table
):
    client, session = mock_client
    moods_table(PROFILE)
    headers = {"Authorization": f"Bearer {session.token}"}
    day = {"created_at": "2026-10-25", "mood": 3}

    first = client.post("/moods", headers=headers, json=day)
    assert first.status_code == 201, first.text

    second = client.post("/moods", headers=headers, json={**day, "mood": 5})

    assert second.status_code == 409, second.text
    assert "2026-10-25" in second.json()["detail"]


@pytest.mark.live
def test_create_mood_invalid_range(client, register):
    email, user, token = register()
    
    resp = client.post(
        "/moods",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "created_at": "2026-10-30",
            "mood": 6,
        },
    )
    assert resp.status_code == 422

    resp = client.post(
        "/moods",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "created_at": "2026-10-30",
            "mood": 0,
        },
    )
    assert resp.status_code == 422


@pytest.mark.live
def test_a_second_mood_for_the_same_day_conflicts_on_the_real_table(
    client, register
):
    _, _, token = register()
    headers = {"Authorization": f"Bearer {token}"}
    day = {"created_at": "2026-10-30", "mood": 4}

    first = client.post("/moods", headers=headers, json=day)
    assert first.status_code == 201, first.text

    second = client.post("/moods", headers=headers, json={**day, "mood": 2})

    assert second.status_code == 409, second.text
    assert "2026-10-30" in second.json()["detail"]


@pytest.mark.live
def test_a_duplicate_backfilled_past_day_is_a_conflict(client, register):
    _, _, token = register()
    headers = {"Authorization": f"Bearer {token}"}
    day = {"created_at": "2026-10-25", "mood": 3}

    first = client.post("/moods", headers=headers, json=day)
    assert first.status_code == 201, first.text

    second = client.post("/moods", headers=headers, json={**day, "mood": 5})

    assert second.status_code == 409, second.text
    assert "2026-10-25" in second.json()["detail"]


@pytest.mark.live
def test_create_mood_description_too_long(client, register):
    email, user, token = register()
    
    resp = client.post(
        "/moods",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "created_at": "2026-10-30",
            "mood": 3,
            "description": "a" * 501,
        },
    )
    assert resp.status_code == 422
