from conftest import (
    CONNECTIONS_COMPANION,
    CONNECTIONS_MOTHER,
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


def test_the_issuer_revokes_a_live_code(mock_client, connections_table):
    client = _as(CONNECTIONS_MOTHER, mock_client)
    code = invite_code_row(CONNECTIONS_MOTHER, "AAAA-BBBB")
    connections_table(invite_codes=[code])

    resp = client.delete(
        f"/connections/invite-codes/{code['id']}", headers=AUTH
    )

    assert resp.status_code == 204, resp.text

    after = client.get("/connections/invite-codes", headers=AUTH)
    assert after.status_code == 200, after.text
    assert after.json()["invite_codes"] == []


def test_revoking_another_profiles_code_returns_404_and_survives(
    mock_client, connections_table
):
    client = _as(CONNECTIONS_COMPANION, mock_client)
    code = invite_code_row(CONNECTIONS_MOTHER, "AAAA-BBBB")
    connections_table(invite_codes=[code])

    resp = client.delete(
        f"/connections/invite-codes/{code['id']}", headers=AUTH
    )

    assert resp.status_code == 404, resp.text

    owner_client = _as(CONNECTIONS_MOTHER, mock_client)
    owner = owner_client.get("/connections/invite-codes", headers=AUTH)
    assert owner.status_code == 200, owner.text
    listed = {item["code"] for item in owner.json()["invite_codes"]}
    assert listed == {"AAAA-BBBB"}


def test_revoking_an_unknown_code_returns_404(mock_client, connections_table):
    import uuid

    client = _as(CONNECTIONS_MOTHER, mock_client)
    connections_table(invite_codes=[invite_code_row(CONNECTIONS_MOTHER, "AAAA-BBBB")])

    resp = client.delete(
        f"/connections/invite-codes/{uuid.uuid4()}", headers=AUTH
    )

    assert resp.status_code == 404, resp.text


def test_revoking_an_already_redeemed_code_returns_404(
    mock_client, connections_table
):
    client = _as(CONNECTIONS_MOTHER, mock_client)
    code = invite_code_row(
        CONNECTIONS_MOTHER,
        "AAAA-BBBB",
        redeemed_at="2026-11-15T12:30:00+00:00",
        redeemed_by=CONNECTIONS_MOTHER,
    )
    connections_table(invite_codes=[code])

    resp = client.delete(
        f"/connections/invite-codes/{code['id']}", headers=AUTH
    )

    assert resp.status_code == 404, resp.text


def test_revoking_an_already_expired_code_returns_404(
    mock_client, connections_table
):
    client = _as(CONNECTIONS_MOTHER, mock_client)
    code = invite_code_row(
        CONNECTIONS_MOTHER,
        "AAAA-BBBB",
        expires_at="2026-11-01T13:00:00+00:00",
        created_at="2026-11-01T12:00:00+00:00",
    )
    connections_table(invite_codes=[code])

    resp = client.delete(
        f"/connections/invite-codes/{code['id']}", headers=AUTH
    )

    assert resp.status_code == 404, resp.text


def test_revoking_twice_returns_404_on_the_second_attempt(
    mock_client, connections_table
):
    client = _as(CONNECTIONS_MOTHER, mock_client)
    code = invite_code_row(CONNECTIONS_MOTHER, "AAAA-BBBB")
    connections_table(invite_codes=[code])

    first = client.delete(f"/connections/invite-codes/{code['id']}", headers=AUTH)
    assert first.status_code == 204, first.text

    second = client.delete(f"/connections/invite-codes/{code['id']}", headers=AUTH)
    assert second.status_code == 404, second.text


def test_a_revoked_codes_string_may_be_reissued(
    mock_client, connections_table, monkeypatch
):
    import app.main as main
    from app.auth import service
    from app.auth.router import verified_session
    from app.connections import service as service_module

    client = _as(CONNECTIONS_MOTHER, mock_client)
    code = invite_code_row(CONNECTIONS_MOTHER, "AAAA-BBBB")
    connections_table(invite_codes=[code])

    revoked = client.delete(f"/connections/invite-codes/{code['id']}", headers=AUTH)
    assert revoked.status_code == 204, revoked.text

    monkeypatch.setattr(service_module, "generate_code", lambda: "AAAA-BBBB")
    reissued = client.post(
        "/connections/invite-codes", headers=AUTH, json={"target_role": "companion"}
    )

    assert reissued.status_code == 201, reissued.text
    assert reissued.json()["code"] == "AAAA-BBBB"

    main.app.dependency_overrides.pop(verified_session, None)


def test_an_unauthenticated_request_is_rejected(mock_client, connections_table):
    import uuid

    import app.main as main
    from app.auth.router import verified_session

    client, _ = mock_client
    connections_table(invite_codes=[invite_code_row(CONNECTIONS_MOTHER, "AAAA-BBBB")])
    main.app.dependency_overrides.pop(verified_session, None)

    resp = client.delete(f"/connections/invite-codes/{uuid.uuid4()}", headers={})

    assert resp.status_code == 401, resp.text


def test_a_deleted_profile_cannot_revoke_codes(mock_client, connections_table):
    from conftest import connections_profiles

    client = _as(CONNECTIONS_MOTHER, mock_client)
    code = invite_code_row(CONNECTIONS_MOTHER, "AAAA-BBBB")
    profiles = connections_profiles()
    profiles[CONNECTIONS_MOTHER] = {
        **profiles[CONNECTIONS_MOTHER],
        "deleted_at": "2026-11-14T10:00:00+00:00",
    }
    connections_table(profiles=profiles, invite_codes=[code])

    resp = client.delete(f"/connections/invite-codes/{code['id']}", headers=AUTH)

    assert resp.status_code == 404, resp.text
