from conftest import (
    CONNECTIONS_COMPANION,
    CONNECTIONS_MOTHER,
    CONNECTIONS_OTHER_COMPANION,
    connection_row,
    observation_row,
)

AUTH = {"Authorization": "Bearer offline-token"}


def _client(mock_client, as_author):
    as_author(CONNECTIONS_COMPANION)
    return mock_client[0]


def _table(observations_table, *, connection, observations):
    return observations_table(
        connections=[connection],
        observations=observations,
    )


def test_the_author_reads_a_draft(mock_client, observations_table, as_author):
    client = _client(mock_client, as_author)
    connection = connection_row(CONNECTIONS_MOTHER, CONNECTIONS_COMPANION)
    draft = observation_row(connection["id"])
    _table(observations_table, connection=connection, observations=[draft])

    resp = client.get(f"/observations/{draft['id']}", headers=AUTH)

    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["id"] == draft["id"]
    assert body["connection_id"] == connection["id"]
    assert body["companion_id"] == CONNECTIONS_COMPANION
    assert body["mother_id"] == CONNECTIONS_MOTHER
    assert body["status"] == "draft"
    assert body["answers"] is None
    assert body["day"] is None
    assert body["completed_at"] is None
    assert [question["id"] for question in body["questions"]] == ["q1", "q2"]


def test_a_completed_observation_reports_its_status(
    mock_client, observations_table, as_author
):
    client = _client(mock_client, as_author)
    connection = connection_row(CONNECTIONS_MOTHER, CONNECTIONS_COMPANION)
    done = observation_row(
        connection["id"],
        answers=[
            {"question_id": "q1", "option_id": "q1o1"},
            {"question_id": "q2", "option_id": "q2o1"},
        ],
        day="2026-11-10",
        completed_at="2026-11-10T09:00:00+00:00",
    )
    _table(observations_table, connection=connection, observations=[done])

    resp = client.get(f"/observations/{done['id']}", headers=AUTH)

    assert resp.status_code == 200, resp.text
    assert resp.json()["status"] == "completed"
    assert resp.json()["day"] == "2026-11-10"


def test_another_authors_observation_is_404(
    mock_client, observations_table, as_author
):
    client = _client(mock_client, as_author)
    connection = connection_row(
        CONNECTIONS_MOTHER, CONNECTIONS_OTHER_COMPANION
    )
    theirs = observation_row(connection["id"])
    _table(observations_table, connection=connection, observations=[theirs])

    resp = client.get(f"/observations/{theirs['id']}", headers=AUTH)

    assert resp.status_code == 404, resp.text
    assert resp.json()["detail"] == "Observation not found"


def test_an_unknown_observation_is_404(
    mock_client, observations_table, as_author
):
    client = _client(mock_client, as_author)
    connection = connection_row(CONNECTIONS_MOTHER, CONNECTIONS_COMPANION)
    _table(observations_table, connection=connection, observations=[])

    resp = client.get(
        "/observations/00000000-0000-4000-8000-0000000000ff",
        headers=AUTH,
    )

    assert resp.status_code == 404, resp.text
