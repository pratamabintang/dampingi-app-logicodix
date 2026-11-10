import pytest

from conftest import captured, mood_row

PROFILE = {**captured("profiles-select-2026-11-10"), "role": "mother"}


@pytest.mark.live
def test_get_mood(client, register):
    email, user, token = register()
    
    client.post(
        "/moods",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "created_at": "2026-10-30",
            "mood": 4,
            "description": "Found clarity",
        },
    )
    
    resp = client.get(
        "/moods/2026-10-30",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["user_id"] == user["id"]
    assert body["mood"] == 4
    assert body["created_at"] == "2026-10-30"
    assert body["description"] == "Found clarity"


@pytest.mark.live
def test_get_mood_not_found(client, register):
    email, user, token = register()
    
    resp = client.get(
        "/moods/2026-10-30",
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
    resp = client.get("/moods/2026-10-30")
    assert resp.status_code == 401


@pytest.mark.live
def test_list_moods(client, register):
    email, user, token = register()
    
    for i in range(3):
        client.post(
            "/moods",
            headers={"Authorization": f"Bearer {token}"},
            json={
                "created_at": f"2026-10-{27 + i}",
                "mood": [4, 3, 5][i],
                "description": f"Entry {i}",
            },
        )
    
    resp = client.get(
        "/moods",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["count"] == 3
    assert len(body["moods"]) == 3
    assert body["moods"][0]["created_at"] == "2026-10-29"
    assert body["moods"][0]["mood"] == 5
    assert body["moods"][0]["description"] == "Entry 2"


@pytest.mark.live
def test_list_moods_with_range(client, register):
    email, user, token = register()
    
    for i in range(5):
        client.post(
            "/moods",
            headers={"Authorization": f"Bearer {token}"},
            json={
                "created_at": f"2026-10-{26 + i}",
                "mood": 3,
            },
        )
    
    resp = client.get(
        "/moods",
        headers={"Authorization": f"Bearer {token}"},
        params={
            "start_date": "2026-10-27",
            "end_date": "2026-10-29",
        },
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["count"] == 3
    assert [m["created_at"] for m in body["moods"]] == [
        "2026-10-29",
        "2026-10-28",
        "2026-10-27",
    ]


@pytest.mark.live
def test_list_moods_with_an_end_date_only(client, register):
    email, user, token = register()

    for i in range(5):
        client.post(
            "/moods",
            headers={"Authorization": f"Bearer {token}"},
            json={"created_at": f"2026-10-{26 + i}", "mood": 3},
        )

    resp = client.get(
        "/moods",
        headers={"Authorization": f"Bearer {token}"},
        params={"end_date": "2026-10-28"},
    )

    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert [m["created_at"] for m in body["moods"]] == [
        "2026-10-28",
        "2026-10-27",
        "2026-10-26",
    ]
    assert body["count"] == 3


def test_a_start_date_filter_excludes_older_moods(mock_client, moods_table):
    client, session = mock_client
    moods_table(
        PROFILE,
        moods=[
            {
                "user_id": session.user_id,
                "created_at": "2026-10-26",
                "mood": 2,
                "description": None,
            },
            {
                "user_id": session.user_id,
                "created_at": "2026-10-29",
                "mood": 4,
                "description": None,
            },
            {
                "user_id": session.user_id,
                "created_at": "2026-10-30",
                "mood": 5,
                "description": None,
            },
        ],
    )

    resp = client.get(
        "/moods",
        headers={"Authorization": f"Bearer {session.token}"},
        params={"start_date": "2026-10-29"},
    )

    assert resp.status_code == 200, resp.text
    body = resp.json()
    # 2026-10-26 is older than the start date and must be excluded.
    assert [m["created_at"] for m in body["moods"]] == ["2026-10-30", "2026-10-29"]
    assert body["count"] == 2


MAX_ROWS = 1000


def _daily_moods(user_id, total):
    from datetime import date, timedelta

    newest = date(2026, 10, 31)
    return [
        mood_row(user_id, (newest - timedelta(days=offset)).isoformat(), mood=3)
        for offset in range(total)
    ]


def test_an_end_date_filter_reaches_past_the_projects_row_cap(
    mock_client, moods_table
):
    client, session = mock_client
    total = MAX_ROWS + 5
    rows = _daily_moods(session.user_id, total)
    moods_table(PROFILE, moods=rows)

    oldest_three = sorted(r["created_at"] for r in rows)[:3]

    resp = client.get(
        "/moods",
        headers={"Authorization": f"Bearer {session.token}"},
        params={"end_date": oldest_three[-1]},
    )

    assert resp.status_code == 200, resp.text
    body = resp.json()
    days = [m["created_at"] for m in body["moods"]]
    assert days, "an end_date past the row cap returned nothing"
    assert set(days) == set(oldest_three)
    assert body["count"] == len(oldest_three)


def test_a_range_with_both_ends_returns_only_that_window(mock_client, moods_table):
    client, session = mock_client
    total = MAX_ROWS + 5
    rows = _daily_moods(session.user_id, total)
    moods_table(PROFILE, moods=rows)

    days = sorted(r["created_at"] for r in rows)
    resp = client.get(
        "/moods",
        headers={"Authorization": f"Bearer {session.token}"},
        params={"start_date": days[0], "end_date": days[-3]},
    )

    assert resp.status_code == 200, resp.text
    body = resp.json()
    got = [m["created_at"] for m in body["moods"]]
    assert got == sorted(days[:-2], reverse=True)
    assert body["count"] == total - 2


def test_the_mood_list_is_not_truncated_by_the_projects_row_cap(
    mock_client, moods_table
):
    client, session = mock_client
    total = MAX_ROWS + 5
    moods_table(PROFILE, moods=_daily_moods(session.user_id, total))

    resp = client.get(
        "/moods",
        headers={"Authorization": f"Bearer {session.token}"},
    )

    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["count"] == total, "the row cap truncated the Author's moods"
    assert len(body["moods"]) == total
    days = [m["created_at"] for m in body["moods"]]
    assert days == sorted(days, reverse=True)
    assert len(set(days)) == total, "paging repeated a page"
