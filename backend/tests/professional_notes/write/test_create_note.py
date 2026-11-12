import pytest

from conftest import (
    CONNECTIONS_COMPANION,
    CONNECTIONS_MOTHER,
    CONNECTIONS_OTHER_MOTHER,
    CONNECTIONS_OTHER_PROFESSIONAL,
    CONNECTIONS_PROFESSIONAL,
    connection_row,
)

AUTH = {"Authorization": "Bearer offline-token"}


def _client(mock_client, as_author, user_id=CONNECTIONS_PROFESSIONAL):
    as_author(user_id)
    return mock_client[0]


def _active(mother=CONNECTIONS_MOTHER, professional=CONNECTIONS_PROFESSIONAL):
    return connection_row(mother, professional, counterpart_role="professional")


def test_a_professional_writes_a_note(mock_client, professional_notes_table, as_author):
    client = _client(mock_client, as_author)
    connection = _active()
    table = professional_notes_table(connections=[connection])

    resp = client.post(
        "/professional-notes",
        headers=AUTH,
        json={"connection_id": connection["id"], "content": "Sleep is improving."},
    )

    assert resp.status_code == 201, resp.text
    body = resp.json()
    assert body["connection_id"] == connection["id"]
    assert body["professional_id"] == CONNECTIONS_PROFESSIONAL
    assert body["mother_id"] == CONNECTIONS_MOTHER
    assert body["content"] == "Sleep is improving."
    assert body["created_at"]
    assert body["updated_at"]
    assert "deleted_at" not in body
    assert table.professional_notes[0]["content"] == "Sleep is improving."


def test_content_is_trimmed(mock_client, professional_notes_table, as_author):
    client = _client(mock_client, as_author)
    connection = _active()
    professional_notes_table(connections=[connection])

    resp = client.post(
        "/professional-notes",
        headers=AUTH,
        json={"connection_id": connection["id"], "content": "  trimmed  "},
    )

    assert resp.status_code == 201, resp.text
    assert resp.json()["content"] == "trimmed"


def test_another_professionals_connection_is_404(
    mock_client, professional_notes_table, as_author
):
    client = _client(mock_client, as_author)
    connection = _active(professional=CONNECTIONS_OTHER_PROFESSIONAL)
    table = professional_notes_table(connections=[connection])

    resp = client.post(
        "/professional-notes",
        headers=AUTH,
        json={"connection_id": connection["id"], "content": "Not mine."},
    )

    assert resp.status_code == 404, resp.text
    assert resp.json()["detail"] == "Connection not found or not active"
    assert table.professional_notes == []


def test_an_ended_connection_is_404(
    mock_client, professional_notes_table, as_author
):
    client = _client(mock_client, as_author)
    connection = _active()
    connection["ended_at"] = "2026-11-18T12:00:00+00:00"
    professional_notes_table(connections=[connection])

    resp = client.post(
        "/professional-notes",
        headers=AUTH,
        json={"connection_id": connection["id"], "content": "Too late."},
    )

    assert resp.status_code == 404, resp.text


def test_an_unknown_connection_is_404(
    mock_client, professional_notes_table, as_author
):
    client = _client(mock_client, as_author)
    professional_notes_table()

    resp = client.post(
        "/professional-notes",
        headers=AUTH,
        json={
            "connection_id": "00000000-0000-4000-8000-0000000000ff",
            "content": "Nowhere.",
        },
    )

    assert resp.status_code == 404, resp.text


@pytest.mark.parametrize(
    "user_id",
    [CONNECTIONS_COMPANION, CONNECTIONS_MOTHER, CONNECTIONS_OTHER_MOTHER],
    ids=["companion", "mother", "other-mother"],
)
def test_non_professionals_cannot_write(
    mock_client, professional_notes_table, as_author, user_id
):
    client = _client(mock_client, as_author, user_id)
    connection = _active()
    professional_notes_table(connections=[connection])

    resp = client.post(
        "/professional-notes",
        headers=AUTH,
        json={"connection_id": connection["id"], "content": "Forbidden."},
    )

    assert resp.status_code == 403, resp.text


@pytest.mark.parametrize(
    "payload",
    [
        {"connection_id": "00000000-0000-4000-8000-0000000000a1", "content": ""},
        {"connection_id": "00000000-0000-4000-8000-0000000000a1", "content": "   "},
        {"connection_id": "00000000-0000-4000-8000-0000000000a1", "content": "x" * 10001},
        {
            "connection_id": "00000000-0000-4000-8000-0000000000a1",
            "content": "ok",
            "title": "extra",
        },
        {"content": "no connection"},
    ],
    ids=["empty", "blank", "too-long", "extra-field", "missing-connection"],
)
def test_invalid_create_payloads_are_422(
    mock_client, professional_notes_table, as_author, payload
):
    client = _client(mock_client, as_author)
    professional_notes_table()

    resp = client.post("/professional-notes", headers=AUTH, json=payload)

    assert resp.status_code == 422, resp.text
