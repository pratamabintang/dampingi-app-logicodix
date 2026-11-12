from conftest import (
    CONNECTIONS_MOTHER,
    CONNECTIONS_OTHER_PROFESSIONAL,
    CONNECTIONS_PROFESSIONAL,
    connection_row,
    professional_note_row,
)

AUTH = {"Authorization": "Bearer offline-token"}


def _client(mock_client, as_author, user_id=CONNECTIONS_PROFESSIONAL):
    as_author(user_id)
    return mock_client[0]


def _active():
    return connection_row(
        CONNECTIONS_MOTHER, CONNECTIONS_PROFESSIONAL,
        counterpart_role="professional",
    )


def test_the_professional_edits_content(
    mock_client, professional_notes_table, as_author
):
    client = _client(mock_client, as_author)
    connection = _active()
    note = professional_note_row(connection["id"])
    original_updated_at = note["updated_at"]
    table = professional_notes_table(
        connections=[connection], professional_notes=[note]
    )

    resp = client.patch(
        f"/professional-notes/{note['id']}",
        headers=AUTH,
        json={"content": "Updated assessment."},
    )

    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["content"] == "Updated assessment."
    assert body["updated_at"] != original_updated_at
    assert table.professional_notes[0]["content"] == "Updated assessment."


def test_the_mother_cannot_edit(
    mock_client, professional_notes_table, as_author
):
    client = _client(mock_client, as_author, CONNECTIONS_MOTHER)
    connection = _active()
    note = professional_note_row(connection["id"])
    professional_notes_table(connections=[connection], professional_notes=[note])

    resp = client.patch(
        f"/professional-notes/{note['id']}",
        headers=AUTH,
        json={"content": "I will change it."},
    )

    assert resp.status_code == 403, resp.text


def test_another_professional_sees_404(
    mock_client, professional_notes_table, as_author
):
    client = _client(mock_client, as_author, CONNECTIONS_OTHER_PROFESSIONAL)
    connection = _active()
    note = professional_note_row(connection["id"])
    professional_notes_table(connections=[connection], professional_notes=[note])

    resp = client.patch(
        f"/professional-notes/{note['id']}",
        headers=AUTH,
        json={"content": "Not mine."},
    )

    assert resp.status_code == 404, resp.text
    assert resp.json()["detail"] == "Professional note not found"


def test_a_soft_deleted_note_is_404(
    mock_client, professional_notes_table, as_author
):
    client = _client(mock_client, as_author)
    connection = _active()
    note = professional_note_row(
        connection["id"], deleted_at="2026-11-19T10:00:00+00:00"
    )
    professional_notes_table(connections=[connection], professional_notes=[note])

    resp = client.patch(
        f"/professional-notes/{note['id']}",
        headers=AUTH,
        json={"content": "Back from the dead."},
    )

    assert resp.status_code == 404, resp.text


def test_an_ended_connection_is_409(
    mock_client, professional_notes_table, as_author
):
    client = _client(mock_client, as_author)
    connection = _active()
    connection["ended_at"] = "2026-11-18T12:00:00+00:00"
    note = professional_note_row(connection["id"])
    professional_notes_table(connections=[connection], professional_notes=[note])

    resp = client.patch(
        f"/professional-notes/{note['id']}",
        headers=AUTH,
        json={"content": "Locked."},
    )

    assert resp.status_code == 409, resp.text
    assert "read-only" in resp.json()["detail"]


def test_an_unknown_note_is_404(
    mock_client, professional_notes_table, as_author
):
    client = _client(mock_client, as_author)
    professional_notes_table()

    resp = client.patch(
        "/professional-notes/00000000-0000-4000-8000-0000000000ff",
        headers=AUTH,
        json={"content": "Nothing."},
    )

    assert resp.status_code == 404, resp.text


def test_invalid_edit_payloads_are_422(
    mock_client, professional_notes_table, as_author
):
    client = _client(mock_client, as_author)
    connection = _active()
    note = professional_note_row(connection["id"])
    professional_notes_table(connections=[connection], professional_notes=[note])

    for payload in ({}, {"content": ""}, {"content": "x" * 10001}):
        resp = client.patch(
            f"/professional-notes/{note['id']}", headers=AUTH, json=payload
        )
        assert resp.status_code == 422, resp.text
