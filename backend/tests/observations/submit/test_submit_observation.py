from datetime import datetime, timedelta, timezone

import pytest

from conftest import (
    CONNECTIONS_COMPANION,
    CONNECTIONS_MOTHER,
    CONNECTIONS_OTHER_COMPANION,
    connection_row,
    connections_profiles,
    observation_row,
)

AUTH = {"Authorization": "Bearer offline-token"}
TODAY = datetime.now(timezone.utc).date()


def _client(mock_client, as_author, user_id=CONNECTIONS_COMPANION):
    as_author(user_id)
    return mock_client[0]


def _state(observations_table, *, connections=None, profiles=None,
           observations=None):
    return observations_table(
        profiles=profiles or connections_profiles(),
        connections=connections or [
            connection_row(CONNECTIONS_MOTHER, CONNECTIONS_COMPANION)
        ],
        observations=observations or [],
    )


def _answers(*pairs):
    return [
        {"question_id": question_id, "option_id": option_id}
        for question_id, option_id in pairs
    ]


def _payload(day=None, answers=None):
    return {
        "answers": answers or _answers(("q1", "q1o1"), ("q2", "q2o1")),
        "day": (day or TODAY).isoformat(),
    }


def test_a_draft_is_completed_once(mock_client, observations_table, as_author):
    client = _client(mock_client, as_author)
    connection = connection_row(CONNECTIONS_MOTHER, CONNECTIONS_COMPANION)
    draft = observation_row(connection["id"])
    _state(observations_table, connections=[connection], observations=[draft])

    resp = client.patch(
        f"/observations/{draft['id']}", headers=AUTH, json=_payload()
    )

    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["id"] == draft["id"]
    assert body["connection_id"] == connection["id"]
    assert body["companion_id"] == CONNECTIONS_COMPANION
    assert body["mother_id"] == CONNECTIONS_MOTHER
    assert body["status"] == "completed"
    assert body["day"] == TODAY.isoformat()
    assert body["completed_at"]
    assert body["answers"] == _answers(("q1", "q1o1"), ("q2", "q2o1"))


def test_answers_are_stored_in_question_order(
    mock_client, observations_table, as_author
):
    client = _client(mock_client, as_author)
    connection = connection_row(CONNECTIONS_MOTHER, CONNECTIONS_COMPANION)
    draft = observation_row(connection["id"])
    _state(observations_table, connections=[connection], observations=[draft])

    resp = client.patch(
        f"/observations/{draft['id']}",
        headers=AUTH,
        json=_payload(answers=_answers(("q2", "q2o2"), ("q1", "q1o2"))),
    )

    assert resp.status_code == 200, resp.text
    assert resp.json()["answers"] == _answers(
        ("q1", "q1o2"), ("q2", "q2o2")
    )


def test_a_past_day_may_be_backfilled(
    mock_client, observations_table, as_author
):
    client = _client(mock_client, as_author)
    connection = connection_row(CONNECTIONS_MOTHER, CONNECTIONS_COMPANION)
    draft = observation_row(connection["id"])
    _state(observations_table, connections=[connection], observations=[draft])

    resp = client.patch(
        f"/observations/{draft['id']}",
        headers=AUTH,
        json=_payload(day=TODAY - timedelta(days=3)),
    )

    assert resp.status_code == 200, resp.text
    assert resp.json()["day"] == (TODAY - timedelta(days=3)).isoformat()


def test_a_future_day_is_400(mock_client, observations_table, as_author):
    client = _client(mock_client, as_author)
    connection = connection_row(CONNECTIONS_MOTHER, CONNECTIONS_COMPANION)
    draft = observation_row(connection["id"])
    stored = _state(
        observations_table, connections=[connection], observations=[draft]
    )

    resp = client.patch(
        f"/observations/{draft['id']}",
        headers=AUTH,
        json=_payload(day=TODAY + timedelta(days=1)),
    )

    assert resp.status_code == 400, resp.text
    assert stored.observations[0]["completed_at"] is None


@pytest.mark.parametrize(
    "answers",
    [
        _answers(("q1", "q1o1")),
        _answers(("q1", "q1o1"), ("q1", "q1o2"), ("q2", "q2o1")),
        _answers(("q1", "q1o1"), ("q9", "q9o1")),
        _answers(("q1", "q1o1"), ("q2", "q1o1")),
        _answers(("q1", "q1o9"), ("q2", "q2o1")),
        [],
    ],
    ids=[
        "missing-question",
        "duplicate-question",
        "unknown-question",
        "wrong-question-option",
        "unknown-option",
        "empty",
    ],
)
def test_invalid_answers_are_422(
    mock_client, observations_table, as_author, answers
):
    client = _client(mock_client, as_author)
    connection = connection_row(CONNECTIONS_MOTHER, CONNECTIONS_COMPANION)
    draft = observation_row(connection["id"])
    stored = _state(
        observations_table, connections=[connection], observations=[draft]
    )

    resp = client.patch(
        f"/observations/{draft['id']}",
        headers=AUTH,
        json={"answers": answers, "day": TODAY.isoformat()},
    )

    assert resp.status_code == 422, resp.text
    assert stored.observations[0]["completed_at"] is None


def test_a_completed_observation_cannot_be_submitted_again(
    mock_client, observations_table, as_author
):
    client = _client(mock_client, as_author)
    connection = connection_row(CONNECTIONS_MOTHER, CONNECTIONS_COMPANION)
    done = observation_row(
        connection["id"],
        answers=_answers(("q1", "q1o1"), ("q2", "q2o1")),
        day=(TODAY - timedelta(days=1)).isoformat(),
        completed_at="2026-11-17T09:00:00+00:00",
    )
    _state(observations_table, connections=[connection], observations=[done])

    resp = client.patch(
        f"/observations/{done['id']}", headers=AUTH, json=_payload()
    )

    assert resp.status_code == 409, resp.text
    assert "already" in resp.json()["detail"].lower()


def test_a_second_completed_observation_for_the_same_day_is_409(
    mock_client, observations_table, as_author
):
    client = _client(mock_client, as_author)
    connection = connection_row(CONNECTIONS_MOTHER, CONNECTIONS_COMPANION)
    done = observation_row(
        connection["id"],
        answers=_answers(("q1", "q1o1"), ("q2", "q2o1")),
        day=TODAY.isoformat(),
        completed_at="2026-11-18T09:00:00+00:00",
    )
    draft = observation_row(connection["id"])
    stored = _state(
        observations_table,
        connections=[connection],
        observations=[done, draft],
    )

    resp = client.patch(
        f"/observations/{draft['id']}", headers=AUTH, json=_payload()
    )

    assert resp.status_code == 409, resp.text
    assert TODAY.isoformat() in resp.json()["detail"]
    assert stored.observations[1]["completed_at"] is None


def test_an_ended_connection_does_not_strand_a_draft(
    mock_client, observations_table, as_author
):
    client = _client(mock_client, as_author)
    connection = connection_row(
        CONNECTIONS_MOTHER,
        CONNECTIONS_COMPANION,
        ended_at="2026-11-17T12:00:00+00:00",
    )
    draft = observation_row(connection["id"])
    _state(observations_table, connections=[connection], observations=[draft])

    resp = client.patch(
        f"/observations/{draft['id']}", headers=AUTH, json=_payload()
    )

    assert resp.status_code == 200, resp.text


def test_a_tombstoned_mother_does_not_block_completion(
    mock_client, observations_table, as_author
):
    profiles = connections_profiles()
    profiles[CONNECTIONS_MOTHER] = {
        **profiles[CONNECTIONS_MOTHER],
        "deleted_at": "2026-11-17T00:00:00+00:00",
    }
    client = _client(mock_client, as_author)
    connection = connection_row(CONNECTIONS_MOTHER, CONNECTIONS_COMPANION)
    draft = observation_row(connection["id"])
    _state(
        observations_table,
        connections=[connection],
        observations=[draft],
        profiles=profiles,
    )

    resp = client.patch(
        f"/observations/{draft['id']}", headers=AUTH, json=_payload()
    )

    assert resp.status_code == 200, resp.text


def test_a_tombstoned_companion_is_404(
    mock_client, observations_table, as_author
):
    profiles = connections_profiles()
    profiles[CONNECTIONS_COMPANION] = {
        **profiles[CONNECTIONS_COMPANION],
        "deleted_at": "2026-11-17T00:00:00+00:00",
    }
    client = _client(mock_client, as_author)
    connection = connection_row(CONNECTIONS_MOTHER, CONNECTIONS_COMPANION)
    draft = observation_row(connection["id"])
    _state(
        observations_table,
        connections=[connection],
        observations=[draft],
        profiles=profiles,
    )

    resp = client.patch(
        f"/observations/{draft['id']}", headers=AUTH, json=_payload()
    )

    assert resp.status_code == 404, resp.text


def test_an_observation_of_another_author_is_404(
    mock_client, observations_table, as_author
):
    client = _client(mock_client, as_author)
    connection = connection_row(
        CONNECTIONS_MOTHER, CONNECTIONS_OTHER_COMPANION
    )
    draft = observation_row(connection["id"])
    _state(observations_table, connections=[connection], observations=[draft])

    resp = client.patch(
        f"/observations/{draft['id']}", headers=AUTH, json=_payload()
    )

    assert resp.status_code == 404, resp.text


def test_an_unknown_observation_is_404(
    mock_client, observations_table, as_author
):
    client = _client(mock_client, as_author)
    _state(observations_table)

    resp = client.patch(
        "/observations/00000000-0000-4000-8000-0000000000ff",
        headers=AUTH,
        json=_payload(),
    )

    assert resp.status_code == 404, resp.text


@pytest.mark.parametrize(
    "body",
    [
        {"answers": _answers(("q1", "q1o1"), ("q2", "q2o1"))},
        {"day": TODAY.isoformat()},
        {
            **_payload(),
            "completed_at": "2026-11-18T09:00:00+00:00",
        },
        {**_payload(), "status": "completed"},
        {"answers": [], "day": TODAY.isoformat()},
        {"answers": _answers(("q1", "q1o1")), "day": "2026-2-30"},
    ],
    ids=["no-day", "no-answers", "completed-at", "status", "empty", "bad-date"],
)
def test_invalid_submission_bodies_are_422(
    mock_client, observations_table, as_author, body
):
    client = _client(mock_client, as_author)
    connection = connection_row(CONNECTIONS_MOTHER, CONNECTIONS_COMPANION)
    draft = observation_row(connection["id"])
    _state(observations_table, connections=[connection], observations=[draft])

    resp = client.patch(
        f"/observations/{draft['id']}", headers=AUTH, json=body
    )

    assert resp.status_code == 422, resp.text
