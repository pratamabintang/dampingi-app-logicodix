from conftest import (
    CONNECTIONS_COMPANION,
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


def _active(mother=CONNECTIONS_MOTHER, professional=CONNECTIONS_PROFESSIONAL):
    return connection_row(mother, professional, counterpart_role="professional")


def test_delete_stamps_and_hides_the_note(
    mock_client, professional_notes_table, as_author
):
    client = _client(mock_client, as_author)
    connection = _active()
    note = professional_note_row(connection["id"])
    table = professional_notes_table(
        connections=[connection], professional_notes=[note]
    )

    resp = client.delete(f"/professional-notes/{note['id']}", headers=AUTH)

    assert resp.status_code == 204, resp.text
    assert table.professional_notes[0]["deleted_at"] is not None

    read = client.get(f"/professional-notes/{note['id']}", headers=AUTH)
    assert read.status_code == 404, read.text


def test_the_mother_cannot_delete(
    mock_client, professional_notes_table, as_author
):
    client = _client(mock_client, as_author, CONNECTIONS_MOTHER)
    connection = _active()
    note = professional_note_row(connection["id"])
    table = professional_notes_table(
        connections=[connection], professional_notes=[note]
    )

    resp = client.delete(f"/professional-notes/{note['id']}", headers=AUTH)

    assert resp.status_code == 403, resp.text
    assert table.professional_notes[0]["deleted_at"] is None


def test_another_professional_sees_404(
    mock_client, professional_notes_table, as_author
):
    client = _client(mock_client, as_author, CONNECTIONS_OTHER_PROFESSIONAL)
    connection = _active()
    note = professional_note_row(connection["id"])
    table = professional_notes_table(
        connections=[connection], professional_notes=[note]
    )

    resp = client.delete(f"/professional-notes/{note['id']}", headers=AUTH)

    assert resp.status_code == 404, resp.text
    assert table.professional_notes[0]["deleted_at"] is None


def test_a_companion_cannot_delete(
    mock_client, professional_notes_table, as_author
):
    client = _client(mock_client, as_author, CONNECTIONS_COMPANION)
    connection = _active()
    note = professional_note_row(connection["id"])
    professional_notes_table(connections=[connection], professional_notes=[note])

    resp = client.delete(f"/professional-notes/{note['id']}", headers=AUTH)

    assert resp.status_code == 403, resp.text


def test_an_ended_connection_is_409(
    mock_client, professional_notes_table, as_author
):
    client = _client(mock_client, as_author)
    connection = _active()
    connection["ended_at"] = "2026-11-18T12:00:00+00:00"
    note = professional_note_row(connection["id"])
    table = professional_notes_table(
        connections=[connection], professional_notes=[note]
    )

    resp = client.delete(f"/professional-notes/{note['id']}", headers=AUTH)

    assert resp.status_code == 409, resp.text
    assert table.professional_notes[0]["deleted_at"] is None


def test_an_unknown_note_is_404(
    mock_client, professional_notes_table, as_author
):
    client = _client(mock_client, as_author)
    professional_notes_table()

    resp = client.delete(
        "/professional-notes/00000000-0000-4000-8000-0000000000ff",
        headers=AUTH,
    )

    assert resp.status_code == 404, resp.text
