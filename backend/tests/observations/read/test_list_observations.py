import pytest

from conftest import (
    CONNECTIONS_COMPANION,
    CONNECTIONS_MOTHER,
    CONNECTIONS_OTHER_COMPANION,
    connection_row,
    observation_row,
)

AUTH = {"Authorization": "Bearer offline-token"}
COMPLETED_AT = "2026-11-18T09:00:00+00:00"
ANSWERS = [
    {"question_id": "q1", "option_id": "q1o1"},
    {"question_id": "q2", "option_id": "q2o1"},
]


def _client(mock_client, as_author):
    as_author(CONNECTIONS_COMPANION)
    return mock_client[0]


def _completed(connection_id, day="2026-11-10", created_at=COMPLETED_AT):
    return observation_row(
        connection_id,
        answers=ANSWERS,
        day=day,
        completed_at=f"{day}T09:00:00+00:00",
        created_at=created_at,
    )


def _draft(connection_id, created_at="2026-11-18T10:00:00+00:00"):
    return observation_row(connection_id, created_at=created_at)


def _two_authors(observations_table):
    mine = connection_row(CONNECTIONS_MOTHER, CONNECTIONS_COMPANION)
    theirs = connection_row(
        CONNECTIONS_MOTHER, CONNECTIONS_OTHER_COMPANION
    )
    my_draft = _draft(mine["id"])
    my_done = _completed(mine["id"], created_at="2026-11-17T09:00:00+00:00")
    their_draft = _draft(theirs["id"])
    observations_table(
        connections=[mine, theirs],
        observations=[my_draft, my_done, their_draft],
    )
    return mine, theirs, my_draft, my_done, their_draft


def test_the_list_holds_only_the_authors_observations(
    mock_client, observations_table, as_author
):
    client = _client(mock_client, as_author)
    _, _, my_draft, my_done, _ = _two_authors(observations_table)

    resp = client.get("/observations", headers=AUTH)

    assert resp.status_code == 200, resp.text
    body = resp.json()
    ids = {item["id"] for item in body["observations"]}
    assert ids == {my_draft["id"], my_done["id"]}
    assert body["count"] == 2
    assert body["total"] == 2
    assert body["offset"] == 0
    assert body["limit"] == 2


def test_the_list_is_newest_first(
    mock_client, observations_table, as_author
):
    client = _client(mock_client, as_author)
    mine, _, my_draft, my_done, _ = _two_authors(observations_table)

    resp = client.get("/observations", headers=AUTH)

    assert resp.status_code == 200, resp.text
    assert [item["id"] for item in resp.json()["observations"]] == [
        my_draft["id"],
        my_done["id"],
    ]


def test_filtering_by_connection(mock_client, observations_table, as_author):
    client = _client(mock_client, as_author)
    mine, theirs, my_draft, my_done, their_draft = _two_authors(
        observations_table
    )

    resp = client.get(
        "/observations",
        headers=AUTH,
        params={"connection_id": mine["id"]},
    )

    assert resp.status_code == 200, resp.text
    ids = {item["id"] for item in resp.json()["observations"]}
    assert ids == {my_draft["id"], my_done["id"]}

    resp = client.get(
        "/observations",
        headers=AUTH,
        params={"connection_id": theirs["id"]},
    )

    assert resp.status_code == 200, resp.text
    assert resp.json()["observations"] == []


def test_filtering_by_day(mock_client, observations_table, as_author):
    client = _client(mock_client, as_author)
    _two_authors(observations_table)

    resp = client.get(
        "/observations", headers=AUTH, params={"day": "2026-11-10"}
    )

    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["count"] == 1
    assert body["observations"][0]["day"] == "2026-11-10"


def test_filtering_by_status(mock_client, observations_table, as_author):
    client = _client(mock_client, as_author)
    _, _, my_draft, my_done, _ = _two_authors(observations_table)

    drafts = client.get(
        "/observations", headers=AUTH, params={"status": "draft"}
    )
    completed = client.get(
        "/observations", headers=AUTH, params={"status": "completed"}
    )

    assert drafts.status_code == 200, drafts.text
    assert [item["id"] for item in drafts.json()["observations"]] == [
        my_draft["id"]
    ]
    assert completed.status_code == 200, completed.text
    assert [item["id"] for item in completed.json()["observations"]] == [
        my_done["id"]
    ]


def test_filters_combine(mock_client, observations_table, as_author):
    client = _client(mock_client, as_author)
    mine, _, _, my_done, _ = _two_authors(observations_table)

    resp = client.get(
        "/observations",
        headers=AUTH,
        params={
            "connection_id": mine["id"],
            "day": "2026-11-10",
            "status": "completed",
        },
    )

    assert resp.status_code == 200, resp.text
    assert [item["id"] for item in resp.json()["observations"]] == [
        my_done["id"]
    ]


def test_an_ended_connection_stays_in_history(
    mock_client, observations_table, as_author
):
    client = _client(mock_client, as_author)
    ended = connection_row(
        CONNECTIONS_MOTHER,
        CONNECTIONS_COMPANION,
        ended_at="2026-11-17T12:00:00+00:00",
    )
    done = _completed(ended["id"])
    observations_table(connections=[ended], observations=[done])

    resp = client.get("/observations", headers=AUTH)

    assert resp.status_code == 200, resp.text
    assert [item["id"] for item in resp.json()["observations"]] == [
        done["id"]
    ]


def test_pagination_uses_a_real_total(
    mock_client, observations_table, as_author
):
    client = _client(mock_client, as_author)
    connection = connection_row(CONNECTIONS_MOTHER, CONNECTIONS_COMPANION)
    rows = [
        _draft(connection["id"], created_at="2026-11-18T10:00:00+00:00"),
        _draft(connection["id"], created_at="2026-11-18T09:00:00+00:00"),
        _draft(connection["id"], created_at="2026-11-18T08:00:00+00:00"),
    ]
    observations_table(connections=[connection], observations=rows)

    resp = client.get(
        "/observations", headers=AUTH, params={"offset": 1, "limit": 1}
    )

    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["count"] == 1
    assert body["offset"] == 1
    assert body["limit"] == 1
    assert body["total"] == 3
    assert body["observations"][0]["id"] == rows[1]["id"]


@pytest.mark.parametrize(
    "params",
    [
        {"status": "pending"},
        {"day": "2026-2-30"},
        {"connection_id": "not-a-uuid"},
        {"limit": 0},
        {"limit": 101},
        {"offset": -1},
    ],
    ids=["bad-status", "bad-day", "bad-connection", "limit-low",
         "limit-high", "offset-negative"],
)
def test_invalid_list_parameters_are_422(
    mock_client, observations_table, as_author, params
):
    client = _client(mock_client, as_author)
    connection = connection_row(CONNECTIONS_MOTHER, CONNECTIONS_COMPANION)
    observations_table(connections=[connection], observations=[])

    resp = client.get("/observations", headers=AUTH, params=params)

    assert resp.status_code == 422, resp.text
