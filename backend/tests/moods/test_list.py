import pytest

from conftest import OTHER_AUTHOR, captured, mood_row

PROFILE = {**captured("profiles-select-2026-11-10"), "role": "mother"}

MOOD_ID = "00000000-0000-4000-8000-0000000000b1"


def test_a_mood_can_be_read_by_its_id(mock_client, moods_table):
    client, session = mock_client
    moods_table(
        PROFILE,
        moods=[
            {
                **mood_row(session.user_id, "2026-10-30", mood=4, description="Captured."),
                "id": MOOD_ID,
            }
        ],
    )

    resp = client.get(
        f"/moods/{MOOD_ID}",
        headers={"Authorization": f"Bearer {session.token}"},
    )

    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["id"] == MOOD_ID
    assert body["user_id"] == session.user_id
    assert body["created_at"] == "2026-10-30"
    assert body["mood"] == 4
    assert body["description"] == "Captured."


@pytest.mark.live
def test_get_mood(client, register):
    _, user, token = register()
    headers = {"Authorization": f"Bearer {token}"}

    created = client.post(
        "/moods",
        headers=headers,
        json={
            "created_at": "2026-10-30",
            "mood": 4,
            "description": "Found clarity",
        },
    )
    assert created.status_code == 201, created.text
    mood_id = created.json()["id"]

    resp = client.get(f"/moods/{mood_id}", headers=headers)
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["id"] == mood_id
    assert body["user_id"] == user["id"]
    assert body["mood"] == 4
    assert body["created_at"] == "2026-10-30"
    assert body["description"] == "Found clarity"


@pytest.mark.live
def test_get_mood_not_found(client, register):
    _, _, token = register()

    resp = client.get(
        "/moods/00000000-0000-4000-8000-00000000dead",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 404, resp.text


@pytest.mark.live
def test_get_mood_malformed_id(client, register):
    _, _, token = register()

    resp = client.get(
        "/moods/not-a-uuid",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 422, resp.text


def test_an_unknown_well_formed_id_is_not_found(mock_client, moods_table):
    client, session = mock_client
    moods_table(PROFILE)

    resp = client.get(
        "/moods/00000000-0000-4000-8000-00000000dead",
        headers={"Authorization": f"Bearer {session.token}"},
    )

    assert resp.status_code == 404, resp.text


def test_a_malformed_id_is_a_validation_error(mock_client, moods_table):
    client, session = mock_client
    recorded = moods_table(PROFILE)

    resp = client.get(
        "/moods/not-a-uuid",
        headers={"Authorization": f"Bearer {session.token}"},
    )

    assert resp.status_code == 422, resp.text
    assert not [
        r for r in recorded.requests if r.url.path.endswith("/rest/v1/moods")
    ]


def test_another_mothers_mood_id_is_not_found(
    mock_client, moods_table, real_moods_gate, as_author
):
    client, _ = mock_client
    moods_table(
        PROFILE,
        moods=[
            {
                **mood_row(PROFILE["user_id"], "2026-10-30", mood=4),
                "id": MOOD_ID,
            }
        ],
    )

    as_author(OTHER_AUTHOR)
    resp = client.get(
        f"/moods/{MOOD_ID}",
        headers={"Authorization": "Bearer offline-token"},
    )

    assert resp.status_code == 404, resp.text
    assert resp.status_code != 403

    as_author(PROFILE["user_id"])
    read = client.get(
        f"/moods/{MOOD_ID}",
        headers={"Authorization": "Bearer offline-token"},
    )
    assert read.status_code == 200, read.text
    assert read.json()["id"] == MOOD_ID


@pytest.mark.parametrize("role", ["professional", "companion"])
def test_a_non_mother_role_is_refused(
    mock_client, moods_table, real_moods_gate, role
):
    client, _ = mock_client
    moods_table({**PROFILE, "role": role})
    headers = {"Authorization": "Bearer offline-token"}

    listed = client.get("/moods", headers=headers)
    created = client.post(
        "/moods",
        headers=headers,
        json={"created_at": "2026-10-30", "mood": 4},
    )

    assert listed.status_code == 403, listed.text
    assert created.status_code == 403, created.text


def test_get_mood_no_auth(client):
    resp = client.get(f"/moods/{MOOD_ID}")
    assert resp.status_code == 401


@pytest.mark.live
def test_another_mothers_mood_id_is_not_found_on_the_real_project(
    client, register
):
    _, _, alice = register()
    _, _, bob = register()
    created = client.post(
        "/moods",
        headers={"Authorization": f"Bearer {alice}"},
        json={"created_at": "2026-10-30", "mood": 4},
    )
    assert created.status_code == 201, created.text
    mood_id = created.json()["id"]

    resp = client.get(
        f"/moods/{mood_id}",
        headers={"Authorization": f"Bearer {bob}"},
    )

    assert resp.status_code == 404, resp.text
    assert resp.status_code != 403

    mine = client.get(
        f"/moods/{mood_id}",
        headers={"Authorization": f"Bearer {alice}"},
    )
    assert mine.status_code == 200, mine.text


@pytest.mark.live
def test_list_moods(client, register):
    _, _, token = register()
    headers = {"Authorization": f"Bearer {token}"}

    created_ids = []
    for i in range(3):
        created = client.post(
            "/moods",
            headers=headers,
            json={
                "created_at": f"2026-10-{27 + i}",
                "mood": [4, 3, 5][i],
                "description": f"Entry {i}",
            },
        )
        assert created.status_code == 201, created.text
        created_ids.append(created.json()["id"])

    resp = client.get("/moods", headers=headers)
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["count"] == 3
    assert len(body["moods"]) == 3
    assert [m["id"] for m in body["moods"]] == list(reversed(created_ids))
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


def test_every_listed_mood_carries_its_id(mock_client, moods_table):
    client, session = mock_client
    first_id = "00000000-0000-4000-8000-0000000000c1"
    second_id = "00000000-0000-4000-8000-0000000000c2"
    moods_table(
        PROFILE,
        moods=[
            {**mood_row(session.user_id, "2026-10-29", mood=3), "id": first_id},
            {**mood_row(session.user_id, "2026-10-30", mood=4), "id": second_id},
        ],
    )

    resp = client.get(
        "/moods",
        headers={"Authorization": f"Bearer {session.token}"},
    )

    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert [m["id"] for m in body["moods"]] == [second_id, first_id]
    assert [m["created_at"] for m in body["moods"]] == [
        "2026-10-30",
        "2026-10-29",
    ]


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
