import pytest

from conftest import (
    CONNECTIONS_COMPANION,
    CONNECTIONS_MOTHER,
    CONNECTIONS_OTHER_COMPANION,
    CONNECTIONS_PROFESSIONAL,
    connection_row,
    connections_profiles,
)

AUTH = {"Authorization": "Bearer offline-token"}
OTHER_MOTHER = "00000000-0000-4000-8000-0000000000ff"


def _client(mock_client, as_author, user_id, token="offline-token"):
    as_author(user_id, token=token)
    return mock_client[0]


def _table(observations_table, *, profiles=None, connections=None, extra_routes=None):
    return observations_table(
        profiles=profiles or connections_profiles(),
        connections=connections or [],
        extra_routes=extra_routes,
    )


def _question(prompt="Question?", options=("A", "B")):
    return {
        "prompt": prompt,
        "options": [{"label": label} for label in options],
    }


def _payload(**overrides):
    return {
        "mother_id": CONNECTIONS_MOTHER,
        "questions": [_question()],
        **overrides,
    }


def _connected(mother_id=CONNECTIONS_MOTHER, counterpart_role="companion"):
    return connection_row(mother_id, CONNECTIONS_COMPANION, counterpart_role)


def _assert_no_rows(stored):
    assert stored.observations == []


@pytest.fixture
def unauthenticated_client(mock_client):
    import app.main as main
    from app.auth.router import verified_session

    main.app.dependency_overrides.pop(verified_session, None)
    client, _ = mock_client
    return client


def test_an_unauthenticated_call_is_401(
    unauthenticated_client, observations_table
):
    stored = _table(observations_table)

    resp = unauthenticated_client.post("/observations", json=_payload())

    assert resp.status_code == 401, resp.text
    _assert_no_rows(stored)


@pytest.mark.parametrize(
    "caller", [CONNECTIONS_MOTHER, CONNECTIONS_PROFESSIONAL]
)
def test_a_non_companion_is_403(
    mock_client, observations_table, as_author, caller
):
    client = _client(mock_client, as_author, caller)
    stored = _table(observations_table)

    resp = client.post("/observations", headers=AUTH, json=_payload())

    assert resp.status_code == 403, resp.text
    _assert_no_rows(stored)


def test_the_role_comes_from_the_profile_not_the_token(
    mock_client, observations_table, as_author
):
    client = _client(
        mock_client, as_author, CONNECTIONS_MOTHER, token="forged.companion"
    )
    stored = _table(observations_table)

    resp = client.post("/observations", headers=AUTH, json=_payload())

    assert resp.status_code == 403, resp.text
    _assert_no_rows(stored)


def test_a_tombstoned_companion_is_404(
    mock_client, observations_table, as_author
):
    client = _client(mock_client, as_author, CONNECTIONS_COMPANION)
    profiles = connections_profiles()
    profiles[CONNECTIONS_COMPANION] = {
        **profiles[CONNECTIONS_COMPANION],
        "deleted_at": "2026-11-04T00:00:00+00:00",
    }
    stored = _table(
        observations_table, profiles=profiles, connections=[_connected()]
    )

    resp = client.post("/observations", headers=AUTH, json=_payload())

    assert resp.status_code == 404, resp.text
    _assert_no_rows(stored)


def test_an_unknown_mother_is_404(mock_client, observations_table, as_author):
    client = _client(mock_client, as_author, CONNECTIONS_COMPANION)
    stored = _table(
        observations_table,
        connections=[connection_row(OTHER_MOTHER, CONNECTIONS_COMPANION)],
    )

    resp = client.post(
        "/observations", headers=AUTH, json=_payload(mother_id=OTHER_MOTHER)
    )

    assert resp.status_code == 404, resp.text
    _assert_no_rows(stored)


def test_a_tombstoned_mother_is_404(
    mock_client, observations_table, as_author
):
    client = _client(mock_client, as_author, CONNECTIONS_COMPANION)
    profiles = connections_profiles()
    profiles[CONNECTIONS_MOTHER] = {
        **profiles[CONNECTIONS_MOTHER],
        "deleted_at": "2026-11-04T00:00:00+00:00",
    }
    stored = _table(
        observations_table, profiles=profiles, connections=[_connected()]
    )

    resp = client.post("/observations", headers=AUTH, json=_payload())

    assert resp.status_code == 404, resp.text
    _assert_no_rows(stored)


def test_a_mother_without_an_active_connection_is_404(
    mock_client, observations_table, as_author
):
    client = _client(mock_client, as_author, CONNECTIONS_COMPANION)
    stored = _table(observations_table)

    resp = client.post("/observations", headers=AUTH, json=_payload())

    assert resp.status_code == 404, resp.text
    _assert_no_rows(stored)


@pytest.mark.parametrize(
    "connection",
    [
        connection_row(CONNECTIONS_MOTHER, CONNECTIONS_OTHER_COMPANION),
        connection_row(
            CONNECTIONS_MOTHER, CONNECTIONS_COMPANION, "professional"
        ),
    ],
    ids=["another-companion", "wrong-role"],
)
def test_a_connection_that_does_not_name_this_companion_is_404(
    mock_client, observations_table, as_author, connection
):
    client = _client(mock_client, as_author, CONNECTIONS_COMPANION)
    stored = _table(observations_table, connections=[connection])

    resp = client.post("/observations", headers=AUTH, json=_payload())

    assert resp.status_code == 404, resp.text
    _assert_no_rows(stored)


def test_an_ended_connection_is_404(
    mock_client, observations_table, as_author
):
    client = _client(mock_client, as_author, CONNECTIONS_COMPANION)
    stored = _table(
        observations_table,
        connections=[
            connection_row(
                CONNECTIONS_MOTHER,
                CONNECTIONS_COMPANION,
                "companion",
                ended_at="2026-11-16T12:00:00+00:00",
            )
        ],
    )

    resp = client.post("/observations", headers=AUTH, json=_payload())

    assert resp.status_code == 404, resp.text
    _assert_no_rows(stored)


def test_unknown_unconnected_and_ended_are_indistinguishable(
    mock_client, observations_table, as_author
):
    client = _client(mock_client, as_author, CONNECTIONS_COMPANION)

    unknown = _table(
        observations_table,
        connections=[connection_row(OTHER_MOTHER, CONNECTIONS_COMPANION)],
    )
    unknown_resp = client.post(
        "/observations", headers=AUTH, json=_payload(mother_id=OTHER_MOTHER)
    )

    unconnected = _table(observations_table)
    unconnected_resp = client.post(
        "/observations", headers=AUTH, json=_payload()
    )

    ended = _table(
        observations_table,
        connections=[
            connection_row(
                CONNECTIONS_MOTHER,
                CONNECTIONS_COMPANION,
                "companion",
                ended_at="2026-11-16T12:00:00+00:00",
            )
        ],
    )
    ended_resp = client.post("/observations", headers=AUTH, json=_payload())

    responses = [unknown_resp, unconnected_resp, ended_resp]
    assert {resp.status_code for resp in responses} == {404}
    assert len({resp.json()["detail"] for resp in responses}) == 1
    for stored in (unknown, unconnected, ended):
        _assert_no_rows(stored)


def _many_questions(count):
    return [_question(prompt=f"Question {index}?") for index in range(count)]


def _many_options(count):
    return [f"Option {index}" for index in range(count)]


REFUSALS = {
    "zero questions": _payload(questions=[]),
    "too many questions": _payload(questions=_many_questions(51)),
    "no options": _payload(questions=[_question(options=())]),
    "one option": _payload(questions=[_question(options=("Only",))]),
    "too many options": _payload(
        questions=[_question(options=_many_options(11))]
    ),
    "empty prompt": _payload(questions=[_question(prompt="")]),
    "whitespace prompt": _payload(questions=[_question(prompt="   ")]),
    "empty label": _payload(questions=[_question(options=("", "B"))]),
    "whitespace label": _payload(
        questions=[_question(options=("   ", "B"))]
    ),
    "prompt too long": _payload(questions=[_question(prompt="a" * 1_001)]),
    "label too long": _payload(
        questions=[_question(options=("a" * 501, "B"))]
    ),
    "answers": _payload(answers=[{"question_id": "q1", "option_id": "q1o1"}]),
    "day": _payload(day="2026-11-04"),
    "completed_at": _payload(completed_at="2026-11-04T09:00:00+00:00"),
    "status": _payload(status="draft"),
    "companion_id": _payload(companion_id=CONNECTIONS_COMPANION),
    "question id": _payload(
        questions=[{**_question(), "id": "q9"}]
    ),
    "option id": _payload(
        questions=[{**_question(), "options": [{"id": "o9", "label": "A"}, {"label": "B"}]}]
    ),
}


@pytest.mark.parametrize("name,payload", REFUSALS.items())
def test_invalid_requests_are_422_and_write_no_row(
    mock_client, observations_table, as_author, name, payload
):
    client = _client(mock_client, as_author, CONNECTIONS_COMPANION)
    stored = _table(observations_table, connections=[_connected()])

    resp = client.post("/observations", headers=AUTH, json=payload)

    assert resp.status_code == 422, f"{name}: {resp.text}"
    _assert_no_rows(stored)


def test_an_insert_transport_failure_is_503_and_writes_no_row(
    mock_client, observations_table, as_author
):
    import httpx

    client = _client(mock_client, as_author, CONNECTIONS_COMPANION)

    def unreachable(_request):
        raise httpx.ConnectError("connection refused")

    stored = _table(
        observations_table,
        connections=[_connected()],
        extra_routes={("POST", "/rest/v1/observations"): unreachable},
    )

    resp = client.post("/observations", headers=AUTH, json=_payload())

    assert resp.status_code == 503, resp.text
    assert "unreachable" in resp.text.lower()
    _assert_no_rows(stored)
