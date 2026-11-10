import uuid

from conftest import (
    CONNECTIONS_COMPANION,
    CONNECTIONS_MOTHER,
    connection_row,
    connections_profiles,
)

AUTH = {"Authorization": "Bearer offline-token"}


def _as_companion(mock_client):
    import app.main as main
    from app.auth import service
    from app.auth.router import verified_session

    client, _ = mock_client
    main.app.dependency_overrides[verified_session] = lambda: service.Session(
        user_id=CONNECTIONS_COMPANION,
        email="companion@offline.test",
        token="offline-token",
    )
    return client


def _connected_table(observations_table):
    connection = connection_row(
        CONNECTIONS_MOTHER, CONNECTIONS_COMPANION, "companion"
    )
    return observations_table(
        profiles=connections_profiles(),
        connections=[connection],
    ), connection


def test_a_companion_creates_a_draft_observation(
    mock_client, observations_table
):
    client = _as_companion(mock_client)
    _, connection = _connected_table(observations_table)

    resp = client.post(
        "/observations",
        headers=AUTH,
        json={
            "mother_id": CONNECTIONS_MOTHER,
            "questions": [
                {
                    "prompt": "How did she sleep last night?",
                    "options": [{"label": "Well"}, {"label": "Poorly"}],
                }
            ],
        },
    )

    assert resp.status_code == 201, resp.text
    body = resp.json()
    assert uuid.UUID(body["id"])
    assert body["connection_id"] == connection["id"]
    assert body["companion_id"] == CONNECTIONS_COMPANION
    assert body["mother_id"] == CONNECTIONS_MOTHER
    assert body["answers"] is None
    assert body["day"] is None
    assert body["completed_at"] is None
    assert body["created_at"]
    assert body["questions"] == [
        {
            "id": "q1",
            "prompt": "How did she sleep last night?",
            "options": [
                {"id": "q1o1", "label": "Well"},
                {"id": "q1o2", "label": "Poorly"},
            ],
        }
    ]


def test_question_and_option_ids_are_deterministic(
    mock_client, observations_table
):
    client = _as_companion(mock_client)
    _connected_table(observations_table)

    resp = client.post(
        "/observations",
        headers=AUTH,
        json={
            "mother_id": CONNECTIONS_MOTHER,
            "questions": [
                {
                    "prompt": "First?",
                    "options": [{"label": "A"}, {"label": "B"}],
                },
                {
                    "prompt": "Second?",
                    "options": [{"label": "C"}, {"label": "D"}, {"label": "E"}],
                },
            ],
        },
    )

    assert resp.status_code == 201, resp.text
    questions = resp.json()["questions"]
    assert [q["id"] for q in questions] == ["q1", "q2"]
    assert [o["id"] for o in questions[0]["options"]] == ["q1o1", "q1o2"]
    assert [o["id"] for o in questions[1]["options"]] == [
        "q2o1",
        "q2o2",
        "q2o3",
    ]


def test_prompts_and_labels_are_trimmed(mock_client, observations_table):
    client = _as_companion(mock_client)
    _connected_table(observations_table)

    resp = client.post(
        "/observations",
        headers=AUTH,
        json={
            "mother_id": CONNECTIONS_MOTHER,
            "questions": [
                {
                    "prompt": "  Question?  ",
                    "options": [{"label": "  A  "}, {"label": " B "}],
                }
            ],
        },
    )

    assert resp.status_code == 201, resp.text
    question = resp.json()["questions"][0]
    assert question["prompt"] == "Question?"
    assert [option["label"] for option in question["options"]] == ["A", "B"]


def test_a_draft_can_be_created_before_answers_or_a_day(
    mock_client, observations_table
):
    client = _as_companion(mock_client)
    _connected_table(observations_table)
    payload = {
        "mother_id": CONNECTIONS_MOTHER,
        "questions": [
            {"prompt": "Question?", "options": [{"label": "A"}, {"label": "B"}]}
        ],
    }

    first = client.post("/observations", headers=AUTH, json=payload)
    second = client.post("/observations", headers=AUTH, json=payload)

    assert first.status_code == 201, first.text
    assert second.status_code == 201, second.text
    assert first.json()["id"] != second.json()["id"]
    assert first.json()["day"] is None
    assert second.json()["day"] is None


def test_a_reconnected_pair_uses_the_active_connection(
    mock_client, observations_table
):
    client = _as_companion(mock_client)
    ended = connection_row(
        CONNECTIONS_MOTHER,
        CONNECTIONS_COMPANION,
        "companion",
        ended_at="2026-11-16T12:00:00+00:00",
    )
    active = connection_row(
        CONNECTIONS_MOTHER, CONNECTIONS_COMPANION, "companion"
    )
    observations_table(
        profiles=connections_profiles(),
        connections=[ended, active],
    )

    resp = client.post(
        "/observations",
        headers=AUTH,
        json={
            "mother_id": CONNECTIONS_MOTHER,
            "questions": [
                {
                    "prompt": "Question?",
                    "options": [{"label": "A"}, {"label": "B"}],
                }
            ],
        },
    )

    assert resp.status_code == 201, resp.text
    assert resp.json()["connection_id"] == active["id"]
