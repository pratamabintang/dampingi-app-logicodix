from conftest import OTHER_AUTHOR, journal_row, journals_profile

AUTH = {"Authorization": "Bearer offline-token"}

PROFILE = journals_profile()

OTHER = OTHER_AUTHOR

DAY = "2026-10-30"


def _journal(user_id=PROFILE["user_id"], day=DAY, title="A day", content="As written."):
    return journal_row(user_id, day, title, content)


def _mother(**overrides):
    return journals_profile(**overrides)


def test_the_title_can_be_edited_on_its_own(mock_client, journals_table):
    client, _ = mock_client
    journals_table(_mother(), journals=[_journal(content="Untouched.")])

    resp = client.patch(
        f"/journals/{DAY}", headers=AUTH, json={"title": "A better title"}
    )

    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["title"] == "A better title"
    assert body["content"] == "Untouched."


def test_the_content_can_be_edited_on_its_own(mock_client, journals_table):
    client, _ = mock_client
    journals_table(_mother(), journals=[_journal(title="Untouched")])

    resp = client.patch(
        f"/journals/{DAY}", headers=AUTH, json={"content": "Added afterwards."}
    )

    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["content"] == "Added afterwards."
    assert body["title"] == "Untouched"


def test_both_fields_can_be_edited_together(mock_client, journals_table):
    client, _ = mock_client
    journals_table(_mother(), journals=[_journal()])

    resp = client.patch(
        f"/journals/{DAY}",
        headers=AUTH,
        json={"title": "Rewritten", "content": "The whole entry, again."},
    )

    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["title"] == "Rewritten"
    assert body["content"] == "The whole entry, again."


def test_the_edit_is_stored_and_reads_back(mock_client, journals_table):
    client, _ = mock_client
    journals_table(_mother(), journals=[_journal()])

    edited = client.patch(
        f"/journals/{DAY}", headers=AUTH, json={"title": "Persisted"}
    )
    assert edited.status_code == 200, edited.text

    read = client.get(f"/journals/{DAY}", headers=AUTH)

    assert read.status_code == 200, read.text
    assert read.json()["title"] == "Persisted"


def test_the_day_never_moves(mock_client, journals_table):
    client, _ = mock_client
    journals_table(_mother(), journals=[_journal()])

    resp = client.patch(
        f"/journals/{DAY}", headers=AUTH, json={"title": "Still the same day"}
    )

    assert resp.status_code == 200, resp.text
    assert resp.json()["created_at"] == DAY


def test_a_day_in_the_payload_is_ignored(mock_client, journals_table):
    client, _ = mock_client
    journals_table(_mother(), journals=[_journal()])

    resp = client.patch(
        f"/journals/{DAY}",
        headers=AUTH,
        json={"title": "Moved?", "created_at": "2020-01-01"},
    )

    assert resp.status_code == 200, resp.text
    assert resp.json()["created_at"] == DAY

    stayed = client.get(f"/journals/{DAY}", headers=AUTH)
    assert stayed.status_code == 200, stayed.text
    assert stayed.json()["created_at"] == DAY
    assert client.get("/journals/2020-01-01", headers=AUTH).status_code == 404


def test_an_update_with_no_fields_is_refused(mock_client, journals_table):
    client, _ = mock_client
    journals_table(_mother(), journals=[_journal()])

    resp = client.patch(f"/journals/{DAY}", headers=AUTH, json={})

    assert resp.status_code == 400, resp.text


def test_an_unknown_field_is_refused(mock_client, journals_table):
    client, _ = mock_client
    journals_table(_mother(), journals=[_journal()])

    resp = client.patch(f"/journals/{DAY}", headers=AUTH, json={"mood": 4})

    assert resp.status_code == 422, resp.text


def test_an_empty_title_is_refused(mock_client, journals_table):
    client, _ = mock_client
    journals_table(_mother(), journals=[_journal()])

    resp = client.patch(f"/journals/{DAY}", headers=AUTH, json={"title": ""})

    assert resp.status_code == 422, resp.text


def test_an_overlong_title_is_refused(mock_client, journals_table):
    client, _ = mock_client
    journals_table(_mother(), journals=[_journal()])

    resp = client.patch(
        f"/journals/{DAY}", headers=AUTH, json={"title": "a" * 256}
    )

    assert resp.status_code == 422, resp.text


def test_an_overlong_content_is_refused(mock_client, journals_table):
    client, _ = mock_client
    journals_table(_mother(), journals=[_journal()])

    resp = client.patch(
        f"/journals/{DAY}", headers=AUTH, json={"content": "a" * 10_001}
    )

    assert resp.status_code == 422, resp.text


def test_a_day_with_no_journal_is_not_found(mock_client, journals_table):
    client, _ = mock_client
    journals_table(_mother())

    resp = client.patch(
        "/journals/2026-01-01", headers=AUTH, json={"title": "Nowhere"}
    )

    assert resp.status_code == 404, resp.text


def test_a_malformed_day_is_refused(mock_client, journals_table):
    client, _ = mock_client
    journals_table(_mother(), journals=[_journal()])

    resp = client.patch(
        "/journals/2026-13-45", headers=AUTH, json={"title": "Typo"}
    )

    assert resp.status_code == 400, resp.text


def test_another_authors_journal_is_not_found(
    mock_client, journals_table, real_gate, as_author
):
    client, _ = mock_client
    journals_table(
        _mother(), journals=[_journal(title="Mine", content="Private.")]
    )

    as_author(OTHER)
    resp = client.patch(
        f"/journals/{DAY}", headers=AUTH, json={"title": "Hijacked"}
    )

    assert resp.status_code == 404, resp.text
    assert resp.status_code != 403

    as_author(PROFILE["user_id"])
    read = client.get(f"/journals/{DAY}", headers=AUTH)
    assert read.status_code == 200, read.text
    assert read.json()["title"] == "Mine"
    assert read.json()["content"] == "Private."


def test_a_soft_deleted_profile_may_not_edit(mock_client, journals_table):
    client, _ = mock_client
    journals_table(
        _mother(deleted_at="2026-10-30T00:00:00+00:00"),
        journals=[_journal(title="Before deletion")],
    )

    resp = client.patch(
        f"/journals/{DAY}", headers=AUTH, json={"title": "Ghost edit"}
    )

    assert resp.status_code == 404, resp.text

    read = client.get(f"/journals/{DAY}", headers=AUTH)
    assert read.status_code == 200, read.text
    assert read.json()["title"] == "Before deletion"


def test_a_professional_is_refused_by_the_real_gate(
    mock_client, journals_table, real_gate
):
    client, _ = mock_client
    journals_table(_mother(role="professional"), journals=[_journal()])

    resp = client.patch(
        f"/journals/{DAY}", headers=AUTH, json={"title": "Not mine to edit"}
    )

    assert resp.status_code == 403, resp.text
    detail = resp.json()["detail"]
    assert "mother" in detail and "companion" in detail


def test_no_token_is_refused(offline_env):
    from fastapi.testclient import TestClient

    import app.main as main

    resp = TestClient(main.app).patch(
        f"/journals/{DAY}", json={"title": "Anonymous"}
    )

    assert resp.status_code == 401
