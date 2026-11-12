import pytest

from conftest import (
    CONNECTIONS_COMPANION,
    CONNECTIONS_MOTHER,
    CONNECTIONS_OTHER_MOTHER,
    CONNECTIONS_OTHER_PROFESSIONAL,
    CONNECTIONS_PROFESSIONAL,
    connection_row,
    professional_note_row,
)

AUTH = {"Authorization": "Bearer offline-token"}


def _client(mock_client, as_author, user_id=CONNECTIONS_MOTHER):
    as_author(user_id)
    return mock_client[0]


def _active(mother=CONNECTIONS_MOTHER, professional=CONNECTIONS_PROFESSIONAL):
    return connection_row(mother, professional, counterpart_role="professional")


def test_the_mother_reads_a_note(
    mock_client, professional_notes_table, as_author
):
    client = _client(mock_client, as_author)
    connection = _active()
    note = professional_note_row(connection["id"])
    professional_notes_table(connections=[connection], professional_notes=[note])

    resp = client.get(f"/professional-notes/{note['id']}", headers=AUTH)

    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["id"] == note["id"]
    assert body["connection_id"] == connection["id"]
    assert body["mother_id"] == CONNECTIONS_MOTHER
    assert body["professional_id"] == CONNECTIONS_PROFESSIONAL
    assert body["content"] == note["content"]
    assert "deleted_at" not in body


def test_the_professional_reads_their_own_note(
    mock_client, professional_notes_table, as_author
):
    client = _client(mock_client, as_author, CONNECTIONS_PROFESSIONAL)
    connection = _active()
    note = professional_note_row(connection["id"])
    professional_notes_table(connections=[connection], professional_notes=[note])

    resp = client.get(f"/professional-notes/{note['id']}", headers=AUTH)

    assert resp.status_code == 200, resp.text


def test_an_ended_connection_remains_readable(
    mock_client, professional_notes_table, as_author
):
    client = _client(mock_client, as_author)
    connection = _active()
    connection["ended_at"] = "2026-11-18T12:00:00+00:00"
    note = professional_note_row(connection["id"])
    professional_notes_table(connections=[connection], professional_notes=[note])

    for user_id in (CONNECTIONS_MOTHER, CONNECTIONS_PROFESSIONAL):
        _client(mock_client, as_author, user_id)
        resp = client.get(f"/professional-notes/{note['id']}", headers=AUTH)
        assert resp.status_code == 200, resp.text


def test_another_mothers_note_is_404(
    mock_client, professional_notes_table, as_author
):
    client = _client(mock_client, as_author)
    connection = _active(mother=CONNECTIONS_OTHER_MOTHER)
    note = professional_note_row(connection["id"])
    professional_notes_table(connections=[connection], professional_notes=[note])

    resp = client.get(f"/professional-notes/{note['id']}", headers=AUTH)

    assert resp.status_code == 404, resp.text
    assert resp.json()["detail"] == "Professional note not found"


def test_another_professionals_note_is_404(
    mock_client, professional_notes_table, as_author
):
    client = _client(mock_client, as_author, CONNECTIONS_OTHER_PROFESSIONAL)
    connection = _active()
    note = professional_note_row(connection["id"])
    professional_notes_table(connections=[connection], professional_notes=[note])

    resp = client.get(f"/professional-notes/{note['id']}", headers=AUTH)

    assert resp.status_code == 404, resp.text


def test_a_soft_deleted_note_is_404(
    mock_client, professional_notes_table, as_author
):
    client = _client(mock_client, as_author)
    connection = _active()
    note = professional_note_row(
        connection["id"], deleted_at="2026-11-19T10:00:00+00:00"
    )
    professional_notes_table(connections=[connection], professional_notes=[note])

    resp = client.get(f"/professional-notes/{note['id']}", headers=AUTH)

    assert resp.status_code == 404, resp.text


@pytest.mark.parametrize(
    "user_id",
    [CONNECTIONS_COMPANION],
    ids=["companion"],
)
def test_companions_have_no_read_path(
    mock_client, professional_notes_table, as_author, user_id
):
    client = _client(mock_client, as_author, user_id)
    connection = _active()
    note = professional_note_row(connection["id"])
    professional_notes_table(connections=[connection], professional_notes=[note])

    one = client.get(f"/professional-notes/{note['id']}", headers=AUTH)
    many = client.get("/professional-notes", headers=AUTH)

    assert one.status_code == 403, one.text
    assert many.status_code == 403, many.text


def test_the_mother_lists_notes_across_connections_including_ended(
    mock_client, professional_notes_table, as_author
):
    client = _client(mock_client, as_author)
    current = _active()
    previous = _active(professional=CONNECTIONS_OTHER_PROFESSIONAL)
    previous["ended_at"] = "2026-11-18T12:00:00+00:00"
    other_mother = _active(mother=CONNECTIONS_OTHER_MOTHER)

    current_note = professional_note_row(
        current["id"], created_at="2026-11-19T09:00:00+00:00"
    )
    previous_note = professional_note_row(
        previous["id"], created_at="2026-11-17T09:00:00+00:00"
    )
    stranger = professional_note_row(
        other_mother["id"], created_at="2026-11-18T09:00:00+00:00"
    )
    professional_notes_table(
        connections=[current, previous, other_mother],
        professional_notes=[current_note, previous_note, stranger],
    )

    resp = client.get("/professional-notes", headers=AUTH)

    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert [note["id"] for note in body["notes"]] == [
        current_note["id"],
        previous_note["id"],
    ]
    assert body["count"] == 2
    assert body["total"] == 2


def test_the_professional_lists_only_their_notes(
    mock_client, professional_notes_table, as_author
):
    client = _client(mock_client, as_author, CONNECTIONS_PROFESSIONAL)
    mine = _active()
    theirs = _active(
        mother=CONNECTIONS_OTHER_MOTHER,
        professional=CONNECTIONS_OTHER_PROFESSIONAL,
    )
    my_note = professional_note_row(mine["id"])
    their_note = professional_note_row(theirs["id"])
    professional_notes_table(
        connections=[mine, theirs],
        professional_notes=[my_note, their_note],
    )

    resp = client.get("/professional-notes", headers=AUTH)

    assert resp.status_code == 200, resp.text
    assert [note["id"] for note in resp.json()["notes"]] == [my_note["id"]]


def test_soft_deleted_notes_are_excluded_from_the_list(
    mock_client, professional_notes_table, as_author
):
    client = _client(mock_client, as_author)
    connection = _active()
    visible = professional_note_row(connection["id"])
    gone = professional_note_row(
        connection["id"], deleted_at="2026-11-19T10:00:00+00:00"
    )
    professional_notes_table(
        connections=[connection], professional_notes=[visible, gone]
    )

    resp = client.get("/professional-notes", headers=AUTH)

    assert resp.status_code == 200, resp.text
    assert [note["id"] for note in resp.json()["notes"]] == [visible["id"]]


def test_filtering_by_connection(
    mock_client, professional_notes_table, as_author
):
    client = _client(mock_client, as_author)
    first = _active()
    second = _active(professional=CONNECTIONS_OTHER_PROFESSIONAL)
    first_note = professional_note_row(first["id"])
    second_note = professional_note_row(second["id"])
    professional_notes_table(
        connections=[first, second],
        professional_notes=[first_note, second_note],
    )

    resp = client.get(
        "/professional-notes",
        headers=AUTH,
        params={"connection_id": first["id"]},
    )

    assert resp.status_code == 200, resp.text
    assert [note["id"] for note in resp.json()["notes"]] == [first_note["id"]]


def test_pagination_uses_a_real_total(
    mock_client, professional_notes_table, as_author
):
    client = _client(mock_client, as_author)
    connection = _active()
    rows = [
        professional_note_row(
            connection["id"], created_at=f"2026-11-19T0{hour}:00:00+00:00"
        )
        for hour in (9, 8, 7)
    ]
    professional_notes_table(connections=[connection], professional_notes=rows)

    resp = client.get(
        "/professional-notes", headers=AUTH, params={"offset": 1, "limit": 1}
    )

    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["count"] == 1
    assert body["offset"] == 1
    assert body["limit"] == 1
    assert body["total"] == 3
    assert body["notes"][0]["id"] == rows[1]["id"]


@pytest.mark.parametrize(
    "params",
    [
        {"connection_id": "not-a-uuid"},
        {"limit": 0},
        {"limit": 101},
        {"offset": -1},
    ],
    ids=["bad-connection", "limit-low", "limit-high", "offset-negative"],
)
def test_invalid_list_parameters_are_422(
    mock_client, professional_notes_table, as_author, params
):
    client = _client(mock_client, as_author)
    professional_notes_table()

    resp = client.get("/professional-notes", headers=AUTH, params=params)

    assert resp.status_code == 422, resp.text

def test_one_professionals_caseload_stays_apart_per_connection(
    mock_client, professional_notes_table, as_author
):
    client = _client(mock_client, as_author, CONNECTIONS_PROFESSIONAL)
    first = _active()
    second = _active(mother=CONNECTIONS_OTHER_MOTHER)
    first_note = professional_note_row(first["id"])
    second_note = professional_note_row(second["id"])
    professional_notes_table(
        connections=[first, second],
        professional_notes=[first_note, second_note],
    )

    filtered = client.get(
        "/professional-notes",
        headers=AUTH,
        params={"connection_id": first["id"]},
    )
    assert filtered.status_code == 200, filtered.text
    assert [note["id"] for note in filtered.json()["notes"]] == [first_note["id"]]

    whole_caseload = client.get("/professional-notes", headers=AUTH)
    assert whole_caseload.status_code == 200, whole_caseload.text
    assert {note["id"] for note in whole_caseload.json()["notes"]} == {
        first_note["id"],
        second_note["id"],
    }


def test_a_replacement_professional_does_not_inherit_the_prior_notes(
    mock_client, professional_notes_table, as_author
):
    previous = _active(professional=CONNECTIONS_OTHER_PROFESSIONAL)
    previous["ended_at"] = "2026-11-18T12:00:00+00:00"
    current = _active()  # same Mother, CONNECTIONS_PROFESSIONAL, active
    old_note = professional_note_row(previous["id"])
    professional_notes_table(
        connections=[previous, current],
        professional_notes=[old_note],
    )
    client = mock_client[0]

    as_author(CONNECTIONS_PROFESSIONAL)
    replacement = client.get(f"/professional-notes/{old_note['id']}", headers=AUTH)
    assert replacement.status_code == 404, replacement.text

    as_author(CONNECTIONS_OTHER_PROFESSIONAL)
    author = client.get(f"/professional-notes/{old_note['id']}", headers=AUTH)
    assert author.status_code == 200, author.text

    as_author(CONNECTIONS_MOTHER)
    mother = client.get(f"/professional-notes/{old_note['id']}", headers=AUTH)
    assert mother.status_code == 200, mother.text
