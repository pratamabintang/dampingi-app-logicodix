from conftest import (
    CONNECTIONS_COMPANION,
    CONNECTIONS_MOTHER,
    CONNECTIONS_OTHER_MOTHER,
    CONNECTIONS_PROFESSIONAL,
    connection_row,
    connections_profiles,
    invite_code_row,
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


def test_the_mother_ends_her_connection(mock_client, connections_table):
    mother = _as(CONNECTIONS_MOTHER, mock_client)
    row = connection_row(CONNECTIONS_MOTHER, CONNECTIONS_COMPANION, "companion")
    connections_table(connections=[row])

    resp = mother.delete(f"/connections/{row['id']}", headers=AUTH)

    assert resp.status_code == 204, resp.text

    mother_list = mother.get("/connections", headers=AUTH)
    assert mother_list.status_code == 200, mother_list.text
    assert mother_list.json()["connections"] == []

    companion = _as(CONNECTIONS_COMPANION, mock_client)
    companion_list = companion.get("/connections", headers=AUTH)
    assert companion_list.status_code == 200, companion_list.text
    assert companion_list.json()["connections"] == []


def test_the_companion_ends_their_connection(mock_client, connections_table):
    companion = _as(CONNECTIONS_COMPANION, mock_client)
    row = connection_row(CONNECTIONS_MOTHER, CONNECTIONS_COMPANION, "companion")
    connections_table(connections=[row])

    resp = companion.delete(f"/connections/{row['id']}", headers=AUTH)

    assert resp.status_code == 204, resp.text

    mother = _as(CONNECTIONS_MOTHER, mock_client)
    mother_list = mother.get("/connections", headers=AUTH)
    assert mother_list.json()["connections"] == []


def test_a_third_party_cannot_end_a_connection(mock_client, connections_table):
    outsider = _as(CONNECTIONS_OTHER_MOTHER, mock_client)
    row = connection_row(CONNECTIONS_MOTHER, CONNECTIONS_COMPANION, "companion")
    connections_table(connections=[row])

    resp = outsider.delete(f"/connections/{row['id']}", headers=AUTH)

    assert resp.status_code == 404, resp.text

    for user_id in (CONNECTIONS_MOTHER, CONNECTIONS_COMPANION):
        party = _as(user_id, mock_client)
        listed = party.get("/connections", headers=AUTH)
        assert listed.status_code == 200, listed.text
        assert listed.json()["count"] == 1, (user_id, listed.text)


def test_the_ender_is_not_the_other_end(mock_client, connections_table):
    mother = _as(CONNECTIONS_MOTHER, mock_client)
    row = connection_row(CONNECTIONS_MOTHER, CONNECTIONS_COMPANION, "companion")
    connections_table(connections=[row])

    outsider = _as(CONNECTIONS_OTHER_MOTHER, mock_client)
    refused = outsider.delete(f"/connections/{row['id']}", headers=AUTH)
    assert refused.status_code == 404, refused.text

    mother = _as(CONNECTIONS_MOTHER, mock_client)
    still_ends = mother.delete(f"/connections/{row['id']}", headers=AUTH)
    assert still_ends.status_code == 204, still_ends.text


def test_ending_an_already_ended_connection_returns_404(
    mock_client, connections_table
):
    mother = _as(CONNECTIONS_MOTHER, mock_client)
    row = connection_row(CONNECTIONS_MOTHER, CONNECTIONS_COMPANION, "companion")
    connections_table(connections=[row])

    first = mother.delete(f"/connections/{row['id']}", headers=AUTH)
    assert first.status_code == 204, first.text

    second = mother.delete(f"/connections/{row['id']}", headers=AUTH)
    assert second.status_code == 404, second.text


def test_ending_an_unknown_connection_returns_404(mock_client, connections_table):
    import uuid

    mother = _as(CONNECTIONS_MOTHER, mock_client)
    connections_table(
        connections=[connection_row(CONNECTIONS_MOTHER, CONNECTIONS_COMPANION, "companion")]
    )

    resp = mother.delete(f"/connections/{uuid.uuid4()}", headers=AUTH)

    assert resp.status_code == 404, resp.text


def test_after_a_mother_ends_her_professional_she_can_reconnect(
    mock_client, connections_table
):
    mother = _as(CONNECTIONS_MOTHER, mock_client)
    row = connection_row(CONNECTIONS_MOTHER, CONNECTIONS_PROFESSIONAL, "professional")
    connections_table(connections=[row])

    ended = mother.delete(f"/connections/{row['id']}", headers=AUTH)
    assert ended.status_code == 204, ended.text

    issued = mother.post(
        "/connections/invite-codes", headers=AUTH, json={"target_role": "professional"}
    )
    assert issued.status_code == 201, issued.text

    professional = _as(CONNECTIONS_PROFESSIONAL, mock_client)
    redeemed = professional.post(
        "/connections", headers=AUTH, json={"code": issued.json()["code"]}
    )
    assert redeemed.status_code == 201, redeemed.text


def test_after_a_companion_ends_their_connection_they_can_be_invited_again(
    mock_client, connections_table
):
    companion = _as(CONNECTIONS_COMPANION, mock_client)
    row = connection_row(CONNECTIONS_MOTHER, CONNECTIONS_COMPANION, "companion")
    connections_table(connections=[row])

    ended = companion.delete(f"/connections/{row['id']}", headers=AUTH)
    assert ended.status_code == 204, ended.text

    mother = _as(CONNECTIONS_MOTHER, mock_client)
    issued = mother.post(
        "/connections/invite-codes", headers=AUTH, json={"target_role": "companion"}
    )
    assert issued.status_code == 201, issued.text

    companion = _as(CONNECTIONS_COMPANION, mock_client)
    redeemed = companion.post(
        "/connections", headers=AUTH, json={"code": issued.json()["code"]}
    )
    assert redeemed.status_code == 201, redeemed.text


def test_an_unauthenticated_request_is_rejected(mock_client, connections_table):
    import uuid

    import app.main as main
    from app.auth.router import verified_session

    client, _ = mock_client
    connections_table(
        connections=[connection_row(CONNECTIONS_MOTHER, CONNECTIONS_COMPANION, "companion")]
    )
    main.app.dependency_overrides.pop(verified_session, None)

    resp = client.delete(f"/connections/{uuid.uuid4()}", headers={})

    assert resp.status_code == 401, resp.text


def test_a_deleted_profile_cannot_end_a_connection(mock_client, connections_table):
    mother = _as(CONNECTIONS_MOTHER, mock_client)
    row = connection_row(CONNECTIONS_MOTHER, CONNECTIONS_COMPANION, "companion")
    profiles = connections_profiles()
    profiles[CONNECTIONS_MOTHER] = {
        **profiles[CONNECTIONS_MOTHER],
        "deleted_at": "2026-11-14T10:00:00+00:00",
    }
    connections_table(profiles=profiles, connections=[row])

    resp = mother.delete(f"/connections/{row['id']}", headers=AUTH)

    assert resp.status_code == 404, resp.text
