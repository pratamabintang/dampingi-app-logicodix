from conftest import (
    CONNECTIONS_COMPANION,
    CONNECTIONS_MOTHER,
    CONNECTIONS_OTHER_MOTHER,
    CONNECTIONS_PROFESSIONAL,
    connection_row,
    connections_profiles,
)

AUTH = {"Authorization": "Bearer offline-token"}


def _as(user_id, mock_client):
    import app.main as main
    from app.auth import service
    from app.auth.router import verified_session

    client, _ = mock_client
    main.app.dependency_overrides[verified_session] = lambda: service.Session(
        user_id=user_id, email="offline@gmail.com", token="offline-token"
    )
    return client


def test_a_mother_sees_her_companion_and_professional(
    mock_client, connections_table
):
    client = _as(CONNECTIONS_MOTHER, mock_client)
    connections_table(
        connections=[
            connection_row(CONNECTIONS_MOTHER, CONNECTIONS_COMPANION, "companion"),
            connection_row(CONNECTIONS_MOTHER, CONNECTIONS_PROFESSIONAL, "professional"),
        ]
    )

    resp = client.get("/connections", headers=AUTH)

    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body.keys() == {"connections", "count", "offset", "limit", "total"}
    assert body["count"] == 2
    roles = {item["counterpart"]["role"] for item in body["connections"]}
    assert roles == {"companion", "professional"}
    for item in body["connections"]:
        assert item.keys() == {"id", "connected_at", "counterpart"}
        assert item["counterpart"].keys() == {"name", "role"}
        assert item["id"]
        assert item["connected_at"]

    names = {item["counterpart"]["name"] for item in body["connections"]}
    assert names == {"Budi", "Dr. Ratna"}


def test_a_professional_sees_the_mothers_on_their_caseload(
    mock_client, connections_table
):
    client = _as(CONNECTIONS_PROFESSIONAL, mock_client)
    connections_table(
        connections=[
            connection_row(CONNECTIONS_MOTHER, CONNECTIONS_PROFESSIONAL, "professional"),
            connection_row(
                CONNECTIONS_OTHER_MOTHER, CONNECTIONS_PROFESSIONAL, "professional"
            ),
        ]
    )

    resp = client.get("/connections", headers=AUTH)

    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["count"] == 2
    assert body["total"] == 2
    assert {item["counterpart"]["role"] for item in body["connections"]} == {"mother"}
    names = {item["counterpart"]["name"] for item in body["connections"]}
    assert names == {"Ani", "Sari"}


def test_a_companion_sees_their_single_mother(mock_client, connections_table):
    client = _as(CONNECTIONS_COMPANION, mock_client)
    connections_table(
        connections=[
            connection_row(CONNECTIONS_MOTHER, CONNECTIONS_COMPANION, "companion")
        ]
    )

    resp = client.get("/connections", headers=AUTH)

    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["count"] == 1
    assert body["connections"][0]["counterpart"] == {"name": "Ani", "role": "mother"}


def test_an_ended_connection_appears_in_neither_list(
    mock_client, connections_table
):
    mother_client = _as(CONNECTIONS_MOTHER, mock_client)
    connections_table(
        connections=[
            connection_row(
                CONNECTIONS_MOTHER,
                CONNECTIONS_COMPANION,
                "companion",
                ended_at="2026-11-15T13:00:00+00:00",
            )
        ]
    )

    mother_list = mother_client.get("/connections", headers=AUTH)
    assert mother_list.status_code == 200, mother_list.text
    assert mother_list.json()["connections"] == []

    companion_client = _as(CONNECTIONS_COMPANION, mock_client)
    companion_list = companion_client.get("/connections", headers=AUTH)
    assert companion_list.status_code == 200, companion_list.text
    assert companion_list.json()["connections"] == []


def test_no_item_contains_the_counterpart_s_email(mock_client, connections_table):
    client = _as(CONNECTIONS_MOTHER, mock_client)
    connections_table(
        connections=[
            connection_row(CONNECTIONS_MOTHER, CONNECTIONS_COMPANION, "companion")
        ]
    )

    resp = client.get("/connections", headers=AUTH)

    assert resp.status_code == 200, resp.text
    for item in resp.json()["connections"]:
        assert item.keys() == {"id", "connected_at", "counterpart"}
        assert item["counterpart"].keys() == {"name", "role"}


def test_another_profile_s_connections_never_appear(
    mock_client, connections_table
):
    client = _as(CONNECTIONS_MOTHER, mock_client)
    connections_table(
        connections=[
            connection_row(CONNECTIONS_MOTHER, CONNECTIONS_COMPANION, "companion"),
            connection_row(
                CONNECTIONS_OTHER_MOTHER, CONNECTIONS_PROFESSIONAL, "professional"
            ),
        ]
    )

    resp = client.get("/connections", headers=AUTH)

    assert resp.status_code == 200, resp.text
    names = {item["counterpart"]["name"] for item in resp.json()["connections"]}
    assert names == {"Budi"}


def test_a_soft_deleted_end_is_filtered_for_the_survivor(
    mock_client, connections_table
):
    client = _as(CONNECTIONS_MOTHER, mock_client)
    profiles = connections_profiles()
    profiles[CONNECTIONS_COMPANION] = {
        **profiles[CONNECTIONS_COMPANION],
        "deleted_at": "2026-11-14T10:00:00+00:00",
    }
    connections_table(
        profiles=profiles,
        connections=[
            connection_row(CONNECTIONS_MOTHER, CONNECTIONS_COMPANION, "companion"),
            connection_row(
                CONNECTIONS_MOTHER, CONNECTIONS_PROFESSIONAL, "professional"
            ),
        ],
    )

    resp = client.get("/connections", headers=AUTH)

    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["count"] == 1
    assert body["total"] == 1
    assert body["connections"][0]["counterpart"]["name"] == "Dr. Ratna"


def test_offset_and_limit_page_the_list(mock_client, connections_table):
    client = _as(CONNECTIONS_PROFESSIONAL, mock_client)
    connections_table(
        connections=[
            connection_row(
                CONNECTIONS_MOTHER,
                CONNECTIONS_PROFESSIONAL,
                "professional",
                connected_at="2026-11-15T10:00:00+00:00",
            ),
            connection_row(
                CONNECTIONS_OTHER_MOTHER,
                CONNECTIONS_PROFESSIONAL,
                "professional",
                connected_at="2026-11-15T12:00:00+00:00",
            ),
        ]
    )

    resp = client.get(
        "/connections", headers=AUTH, params={"offset": 1, "limit": 1}
    )

    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert [item["counterpart"]["name"] for item in body["connections"]] == ["Ani"]
    assert body["count"] == 1
    assert body["offset"] == 1
    assert body["limit"] == 1
    assert body["total"] == 2


def test_the_list_is_newest_first(mock_client, connections_table):
    client = _as(CONNECTIONS_PROFESSIONAL, mock_client)
    connections_table(
        connections=[
            connection_row(
                CONNECTIONS_MOTHER,
                CONNECTIONS_PROFESSIONAL,
                "professional",
                connected_at="2026-11-15T10:00:00+00:00",
            ),
            connection_row(
                CONNECTIONS_OTHER_MOTHER,
                CONNECTIONS_PROFESSIONAL,
                "professional",
                connected_at="2026-11-15T12:00:00+00:00",
            ),
        ]
    )

    resp = client.get("/connections", headers=AUTH)

    assert resp.status_code == 200, resp.text
    listed = [item["counterpart"]["name"] for item in resp.json()["connections"]]
    assert listed == ["Sari", "Ani"]


def test_an_unauthenticated_request_is_rejected(mock_client, connections_table):
    import app.main as main
    from app.auth.router import verified_session

    client, _ = mock_client
    connections_table()
    main.app.dependency_overrides.pop(verified_session, None)

    resp = client.get("/connections", headers={})

    assert resp.status_code == 401, resp.text


def test_a_deleted_profile_cannot_list_connections(
    mock_client, connections_table
):
    client = _as(CONNECTIONS_MOTHER, mock_client)
    profiles = connections_profiles()
    profiles[CONNECTIONS_MOTHER] = {
        **profiles[CONNECTIONS_MOTHER],
        "deleted_at": "2026-11-14T10:00:00+00:00",
    }
    connections_table(
        profiles=profiles,
        connections=[
            connection_row(CONNECTIONS_MOTHER, CONNECTIONS_COMPANION, "companion")
        ],
    )

    resp = client.get("/connections", headers=AUTH)

    assert resp.status_code == 404, resp.text
