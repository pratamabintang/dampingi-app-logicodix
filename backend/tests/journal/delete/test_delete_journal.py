from conftest import OTHER_AUTHOR, journal_row, journals_profile

AUTH = {"Authorization": "Bearer offline-token"}

PROFILE = journals_profile()

OTHER = OTHER_AUTHOR

DAY = "2026-10-30"


def _journal(user_id=PROFILE["user_id"], day=DAY, title="A day", content="As written."):
    return journal_row(user_id, day, title, content)


def _mother(**overrides):
    return journals_profile(**overrides)


def test_an_author_deletes_their_own_journal(mock_client, journals_table):
    client, _ = mock_client
    journals_table(_mother(), journals=[_journal()])

    resp = client.delete(f"/journals/{DAY}", headers=AUTH)

    assert resp.status_code == 204, resp.text
    assert resp.content == b""
    assert client.get(f"/journals/{DAY}", headers=AUTH).status_code == 404


def test_reading_the_deleted_day_afterwards_is_not_found(
    mock_client, journals_table
):
    client, _ = mock_client
    journals_table(_mother(), journals=[_journal()])

    deleted = client.delete(f"/journals/{DAY}", headers=AUTH)
    assert deleted.status_code == 204, deleted.text

    read = client.get(f"/journals/{DAY}", headers=AUTH)

    assert read.status_code == 404, read.text


def test_the_deleted_journal_leaves_the_list(mock_client, journals_table):
    client, _ = mock_client
    journals_table(
        _mother(),
        journals=[
            _journal(day="2026-10-30", title="Deleted"),
            _journal(day="2026-10-29", title="Kept"),
        ],
    )

    deleted = client.delete("/journals/2026-10-30", headers=AUTH)
    assert deleted.status_code == 204, deleted.text

    listed = client.get("/journals", headers=AUTH)

    assert listed.status_code == 200, listed.text
    body = listed.json()
    assert body["count"] == 1
    assert [j["title"] for j in body["journals"]] == ["Kept"]


def test_deleting_a_day_with_no_journal_is_not_found(mock_client, journals_table):
    client, _ = mock_client
    journals_table(_mother())

    resp = client.delete("/journals/2026-01-01", headers=AUTH)

    assert resp.status_code == 404, resp.text


def test_a_malformed_day_is_refused(mock_client, journals_table):
    client, _ = mock_client
    journals_table(_mother(), journals=[_journal()])

    resp = client.delete("/journals/2026-13-45", headers=AUTH)

    assert resp.status_code == 400, resp.text


def test_another_authors_journal_may_not_be_deleted(
    mock_client, journals_table, real_gate, as_author
):
    client, _ = mock_client
    journals_table(_mother(), journals=[_journal(title="Mine")])

    as_author(OTHER)
    resp = client.delete(f"/journals/{DAY}", headers=AUTH)

    assert resp.status_code == 404, resp.text
    assert resp.status_code != 403

    as_author(PROFILE["user_id"])
    read = client.get(f"/journals/{DAY}", headers=AUTH)
    assert read.status_code == 200, read.text
    assert read.json()["title"] == "Mine"


def test_a_soft_deleted_profile_may_not_delete(mock_client, journals_table):
    client, _ = mock_client
    journals_table(
        _mother(deleted_at="2026-10-30T00:00:00+00:00"), journals=[_journal()]
    )

    resp = client.delete(f"/journals/{DAY}", headers=AUTH)

    assert resp.status_code == 404, resp.text

    read = client.get(f"/journals/{DAY}", headers=AUTH)
    assert read.status_code == 200, "a tombstoned Profile still deleted an entry"


def test_a_professional_is_refused_by_the_real_gate(
    mock_client, journals_table, real_gate
):
    client, _ = mock_client
    journals_table(_mother(role="professional"), journals=[_journal()])

    resp = client.delete(f"/journals/{DAY}", headers=AUTH)

    assert resp.status_code == 403, resp.text
    detail = resp.json()["detail"]
    assert "mother" in detail and "companion" in detail


def test_no_token_is_refused(offline_env):
    from fastapi.testclient import TestClient

    import app.main as main

    resp = TestClient(main.app).delete(f"/journals/{DAY}")

    assert resp.status_code == 401
