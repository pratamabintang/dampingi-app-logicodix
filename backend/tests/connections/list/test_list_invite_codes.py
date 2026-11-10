from conftest import (
    CONNECTIONS_COMPANION,
    CONNECTIONS_MOTHER,
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


def test_an_issuer_sees_their_live_codes(mock_client, connections_table):
    client = _as(CONNECTIONS_MOTHER, mock_client)
    codes = [
        invite_code_row(CONNECTIONS_MOTHER, "AAAA-BBBB", target_role="companion"),
        invite_code_row(CONNECTIONS_MOTHER, "CCCC-DDDD", target_role="professional"),
    ]
    connections_table(invite_codes=codes)

    resp = client.get("/connections/invite-codes", headers=AUTH)

    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["count"] == 2
    assert body["offset"] == 0
    assert body["limit"] == 100
    listed = {item["code"]: item for item in body["invite_codes"]}
    assert set(listed) == {"AAAA-BBBB", "CCCC-DDDD"}
    assert listed["AAAA-BBBB"]["target_role"] == "companion"
    assert listed["CCCC-DDDD"]["target_role"] == "professional"
    assert listed["AAAA-BBBB"]["id"]
    assert listed["AAAA-BBBB"]["expires_at"]


def test_a_redeemed_code_does_not_appear(mock_client, connections_table):
    client = _as(CONNECTIONS_MOTHER, mock_client)
    connections_table(
        invite_codes=[
            invite_code_row(CONNECTIONS_MOTHER, "AAAA-BBBB"),
            invite_code_row(
                CONNECTIONS_MOTHER,
                "CCCC-DDDD",
                redeemed_at="2026-11-15T12:30:00+00:00",
                redeemed_by=CONNECTIONS_MOTHER,
            ),
        ]
    )

    resp = client.get("/connections/invite-codes", headers=AUTH)

    assert resp.status_code == 200, resp.text
    listed = {item["code"] for item in resp.json()["invite_codes"]}
    assert listed == {"AAAA-BBBB"}


def test_another_profiles_codes_never_appear(mock_client, connections_table):
    client = _as(CONNECTIONS_MOTHER, mock_client)
    connections_table(
        invite_codes=[
            invite_code_row(CONNECTIONS_MOTHER, "AAAA-BBBB"),
            invite_code_row(CONNECTIONS_COMPANION, "MMMM-NNNN"),
        ]
    )

    resp = client.get("/connections/invite-codes", headers=AUTH)

    assert resp.status_code == 200, resp.text
    listed = {item["code"] for item in resp.json()["invite_codes"]}
    assert listed == {"AAAA-BBBB"}


def test_the_list_is_newest_first(mock_client, connections_table):
    client = _as(CONNECTIONS_MOTHER, mock_client)
    connections_table(
        invite_codes=[
            invite_code_row(
                CONNECTIONS_MOTHER, "AAAA-BBBB", created_at="2026-11-15T10:00:00+00:00"
            ),
            invite_code_row(
                CONNECTIONS_MOTHER, "CCCC-DDDD", created_at="2026-11-15T12:00:00+00:00"
            ),
        ]
    )

    resp = client.get("/connections/invite-codes", headers=AUTH)

    assert resp.status_code == 200, resp.text
    listed = [item["code"] for item in resp.json()["invite_codes"]]
    assert listed == ["CCCC-DDDD", "AAAA-BBBB"]


def test_offset_and_limit_page_the_list(mock_client, connections_table):
    client = _as(CONNECTIONS_MOTHER, mock_client)
    connections_table(
        invite_codes=[
            invite_code_row(
                CONNECTIONS_MOTHER, "AAAA-BBBB", created_at="2026-11-15T10:00:00+00:00"
            ),
            invite_code_row(
                CONNECTIONS_MOTHER, "CCCC-DDDD", created_at="2026-11-15T12:00:00+00:00"
            ),
        ]
    )

    resp = client.get(
        "/connections/invite-codes", headers=AUTH, params={"offset": 1, "limit": 1}
    )

    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert [item["code"] for item in body["invite_codes"]] == ["AAAA-BBBB"]
    assert body["count"] == 1
    assert body["offset"] == 1
    assert body["limit"] == 1


def test_an_unauthenticated_request_is_rejected(mock_client, connections_table):
    import app.main as main
    from app.auth.router import verified_session

    client, _ = mock_client
    connections_table(invite_codes=[invite_code_row(CONNECTIONS_MOTHER, "AAAA-BBBB")])
    main.app.dependency_overrides.pop(verified_session, None)

    resp = client.get("/connections/invite-codes", headers={})

    assert resp.status_code == 401, resp.text


def test_a_deleted_profile_cannot_list_codes(mock_client, connections_table):
    client = _as(CONNECTIONS_MOTHER, mock_client)
    profiles = connections_profiles()
    profiles[CONNECTIONS_MOTHER] = {
        **profiles[CONNECTIONS_MOTHER],
        "deleted_at": "2026-11-14T10:00:00+00:00",
    }
    connections_table(
        profiles=profiles,
        invite_codes=[invite_code_row(CONNECTIONS_MOTHER, "AAAA-BBBB")],
    )

    resp = client.get("/connections/invite-codes", headers=AUTH)

    assert resp.status_code == 404, resp.text


def test_a_revoked_code_does_not_appear(mock_client, connections_table):
    client = _as(CONNECTIONS_MOTHER, mock_client)
    connections_table(
        invite_codes=[
            invite_code_row(CONNECTIONS_MOTHER, "AAAA-BBBB"),
            invite_code_row(
                CONNECTIONS_MOTHER,
                "CCCC-DDDD",
                revoked_at="2026-11-15T12:30:00+00:00",
            ),
        ]
    )

    resp = client.get("/connections/invite-codes", headers=AUTH)

    assert resp.status_code == 200, resp.text
    listed = {item["code"] for item in resp.json()["invite_codes"]}
    assert listed == {"AAAA-BBBB"}


def test_an_expired_code_does_not_appear(mock_client, connections_table):
    client = _as(CONNECTIONS_MOTHER, mock_client)
    connections_table(
        invite_codes=[
            invite_code_row(CONNECTIONS_MOTHER, "AAAA-BBBB"),
            invite_code_row(
                CONNECTIONS_MOTHER,
                "CCCC-DDDD",
                expires_at="2026-11-01T12:30:00+00:00",
                created_at="2026-11-01T11:30:00+00:00",
            ),
        ]
    )

    resp = client.get("/connections/invite-codes", headers=AUTH)

    assert resp.status_code == 200, resp.text
    listed = {item["code"] for item in resp.json()["invite_codes"]}
    assert listed == {"AAAA-BBBB"}
