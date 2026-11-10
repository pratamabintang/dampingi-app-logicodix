import uuid

from conftest import OTHER_AUTHOR, journal_row, journals_profile

AUTH = {"Authorization": "Bearer offline-token"}

PROFILE = journals_profile()

OTHER = OTHER_AUTHOR

OTHER_ID = "00000000-0000-4000-8000-0000000000f2"
MY_ID = "00000000-0000-4000-8000-0000000000f3"


def _journal(user_id, day, title="A day", content="As written.", id=None):
    row = journal_row(user_id, day, title, content)
    if id is not None:
        row["id"] = id
    return row


def test_a_mother_writes_todays_journal_and_reads_it_back(
    mock_client, journals_table
):
    client, _ = mock_client
    journals_table(PROFILE)

    written = client.post(
        "/journals",
        headers=AUTH,
        json={"title": "A good day", "content": "We walked to the park."},
    )

    assert written.status_code == 201, written.text
    body = written.json()
    assert body["id"]
    uuid.UUID(body["id"])
    assert body["title"] == "A good day"
    assert body["content"] == "We walked to the park."
    assert len(body["created_at"]) == 10

    read = client.get(f"/journals/{body['id']}", headers=AUTH)

    assert read.status_code == 200, read.text
    assert read.json() == body


def test_a_companion_passes_the_real_gate(
    mock_client, journals_table, real_gate
):
    client, _ = mock_client
    journals_table({**PROFILE, "role": "companion"})

    resp = client.post(
        "/journals",
        headers=AUTH,
        json={"title": "Supporting her", "content": "A quiet day."},
    )

    assert resp.status_code == 201, resp.text


def test_a_professional_is_refused_by_the_real_gate(
    mock_client, journals_table, real_gate
):
    client, _ = mock_client
    journals_table({**PROFILE, "role": "professional"})

    resp = client.post(
        "/journals",
        headers=AUTH,
        json={"title": "Notes", "content": "Clinical notes."},
    )

    assert resp.status_code == 403, resp.text
    detail = resp.json()["detail"]
    assert "mother" in detail and "companion" in detail


def test_another_authors_journal_is_not_found(mock_client, journals_table):
    client, _ = mock_client
    journals_table(
        PROFILE,
        journals=[_journal(OTHER, "2026-10-30", "Not yours", "Private.", OTHER_ID)],
    )

    resp = client.get(f"/journals/{OTHER_ID}", headers=AUTH)

    assert resp.status_code == 404, resp.text
    assert resp.status_code != 403


def test_two_authors_hold_their_own_journal_on_the_same_day(
    mock_client, journals_table, real_gate, as_author
):
    client, _ = mock_client
    journals_table(
        {**PROFILE, "role": "mother"},
        journals=[
            _journal(OTHER, "2026-10-30", "Theirs", "Their day.", OTHER_ID),
            _journal(PROFILE["user_id"], "2026-10-30", "Mine", "My day.", MY_ID),
        ],
    )

    as_author(PROFILE["user_id"])
    first = client.get(f"/journals/{MY_ID}", headers=AUTH)
    assert first.status_code == 200, first.text
    assert first.json()["title"] == "Mine"

    as_author(OTHER)
    second = client.get(f"/journals/{OTHER_ID}", headers=AUTH)
    assert second.status_code == 200, second.text
    assert second.json()["title"] == "Theirs"


def test_a_second_journal_for_the_same_day_is_a_conflict(
    mock_client, journals_table
):
    client, _ = mock_client
    journals_table(PROFILE)

    first = client.post(
        "/journals",
        headers=AUTH,
        json={"title": "First", "content": "Once today."},
    )
    assert first.status_code == 201, first.text

    resp = client.post(
        "/journals",
        headers=AUTH,
        json={"title": "Again", "content": "Twice today."},
    )

    assert resp.status_code == 409, resp.text
    assert first.json()["created_at"] in resp.json()["detail"]
    assert "id" not in resp.json()


def test_a_foreign_key_violation_is_not_reported_as_a_duplicate(
    mock_client, journals_table
):
    import httpx

    client, _ = mock_client

    def orphan():
        return httpx.Response(
            409,
            json={
                "code": "23503",
                "details": "Key (user_id)=(...) is not present in table profiles.",
                "message": "insert or update violates foreign key constraint",
            },
        )

    journals_table(PROFILE, fail_insert=orphan)

    resp = client.post(
        "/journals",
        headers=AUTH,
        json={"title": "Orphan", "content": "No such Author."},
    )

    assert resp.status_code != 409, resp.text
    assert resp.status_code == 503, resp.text


def test_a_soft_deleted_profile_may_not_write(mock_client, journals_table):
    client, _ = mock_client
    journals_table(
        {**PROFILE, "deleted_at": "2026-10-30T00:00:00+00:00"}
    )

    resp = client.post(
        "/journals",
        headers=AUTH,
        json={"title": "Ghost", "content": "Should not exist."},
    )

    assert resp.status_code == 404, resp.text


def test_a_malformed_date_is_refused(mock_client, journals_table):
    client, _ = mock_client
    journals_table(PROFILE)

    resp = client.post(
        "/journals",
        headers=AUTH,
        json={"title": "Typo", "content": "x", "created_at": "2026-13-45"},
    )

    assert resp.status_code == 400, resp.text
    assert "date" in resp.json()["detail"].lower()


def test_a_future_date_is_refused(mock_client, journals_table):
    client, _ = mock_client
    journals_table(PROFILE)

    resp = client.post(
        "/journals",
        headers=AUTH,
        json={"title": "Tomorrow", "content": "x", "created_at": "2099-12-31"},
    )

    assert resp.status_code == 400, resp.text
    assert "future" in resp.json()["detail"].lower()


def test_a_past_date_is_accepted(mock_client, journals_table):
    client, _ = mock_client
    journals_table(PROFILE)

    resp = client.post(
        "/journals",
        headers=AUTH,
        json={"title": "Last week", "content": "x", "created_at": "2026-10-25"},
    )

    assert resp.status_code == 201, resp.text
    assert resp.json()["created_at"] == "2026-10-25"


def test_backfilling_the_same_past_day_twice_is_a_conflict(
    mock_client, journals_table
):
    client, _ = mock_client
    journals_table(PROFILE)

    first = client.post(
        "/journals",
        headers=AUTH,
        json={"title": "Catching up", "content": "x", "created_at": "2026-10-25"},
    )
    assert first.status_code == 201, first.text

    second = client.post(
        "/journals",
        headers=AUTH,
        json={"title": "Again", "content": "y", "created_at": "2026-10-25"},
    )

    assert second.status_code == 409, second.text
    assert "2026-10-25" in second.json()["detail"]


def test_two_authors_may_both_backfill_the_same_past_day(
    mock_client, journals_table, real_gate, as_author
):
    client, _ = mock_client
    journals_table(PROFILE)

    as_author(PROFILE["user_id"])
    mine = client.post(
        "/journals",
        headers=AUTH,
        json={"title": "Mine", "content": "x", "created_at": "2026-10-25"},
    )
    assert mine.status_code == 201, mine.text

    as_author(OTHER)
    theirs = client.post(
        "/journals",
        headers=AUTH,
        json={"title": "Theirs", "content": "y", "created_at": "2026-10-25"},
    )
    assert theirs.status_code == 201, theirs.text


def test_an_empty_title_is_refused(mock_client, journals_table):
    client, _ = mock_client
    journals_table(PROFILE)

    resp = client.post(
        "/journals", headers=AUTH, json={"title": "", "content": "x"}
    )

    assert resp.status_code == 422, resp.text


def test_an_overlong_title_is_refused(mock_client, journals_table):
    client, _ = mock_client
    journals_table(PROFILE)

    resp = client.post(
        "/journals", headers=AUTH, json={"title": "a" * 256, "content": "x"}
    )

    assert resp.status_code == 422, resp.text


def test_an_empty_content_is_refused(mock_client, journals_table):
    client, _ = mock_client
    journals_table(PROFILE)

    resp = client.post(
        "/journals", headers=AUTH, json={"title": "x", "content": ""}
    )

    assert resp.status_code == 422, resp.text


def test_overlong_content_is_refused(mock_client, journals_table):
    client, _ = mock_client
    journals_table(PROFILE)

    resp = client.post(
        "/journals", headers=AUTH, json={"title": "x", "content": "a" * 10_001}
    )

    assert resp.status_code == 422, resp.text


def test_an_unknown_field_is_refused(mock_client, journals_table):
    client, _ = mock_client
    journals_table(PROFILE)

    resp = client.post(
        "/journals",
        headers=AUTH,
        json={"title": "x", "content": "y", "mood": 4},
    )

    assert resp.status_code == 422, resp.text


def test_no_token_is_refused(offline_env):
    from fastapi.testclient import TestClient

    import app.main as main

    resp = TestClient(main.app).post(
        "/journals", json={"title": "x", "content": "y"}
    )

    assert resp.status_code == 401


def test_an_unusable_timezone_falls_back_to_utc(mock_client, journals_table):
    client, _ = mock_client
    journals_table({**PROFILE, "timezone": "Not/AZone"})

    resp = client.post(
        "/journals",
        headers=AUTH,
        json={"title": "Fallback", "content": "Still works."},
    )

    assert resp.status_code == 201, resp.text
    assert len(resp.json()["created_at"]) == 10


def test_the_day_is_the_authors_local_one(mock_client, journals_table):
    client, _ = mock_client

    def day_for(zone: str) -> str:
        journals_table({**PROFILE, "timezone": zone})
        resp = client.post(
            "/journals", headers=AUTH, json={"title": "Day", "content": "x"}
        )
        assert resp.status_code == 201, resp.text
        return resp.json()["created_at"]

    assert day_for("Pacific/Kiritimati") != day_for("Etc/GMT+12")
