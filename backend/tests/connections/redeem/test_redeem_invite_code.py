import datetime

import app.main as main
from app.auth import service as auth_service
from app.auth.router import verified_session
from conftest import (
    CONNECTIONS_COMPANION,
    CONNECTIONS_MOTHER,
    CONNECTIONS_OTHER_COMPANION,
    CONNECTIONS_OTHER_MOTHER,
    CONNECTIONS_PROFESSIONAL,
    connection_row,
    connections_profiles,
    invite_code_row,
)

AUTH = {"Authorization": "Bearer offline-token"}


def _as(user_id, mock_client):
    client, _ = mock_client
    main.app.dependency_overrides[verified_session] = lambda: auth_service.Session(
        user_id=user_id, email="offline@gmail.com", token="offline-token"
    )
    return client


def PROFILES():
    return connections_profiles()


def test_a_companion_redeems_a_mother_code(mock_client, connections_table):
    client = _as(CONNECTIONS_COMPANION, mock_client)
    connections_table(
        profiles=PROFILES(),
        invite_codes=[invite_code_row(CONNECTIONS_MOTHER, "AAAA-BBBB", "companion")],
    )

    resp = client.post(
        "/connections", headers=AUTH, json={"code": "AAAA-BBBB"}
    )
    assert resp.status_code == 201, resp.text
    body = resp.json()
    assert body["id"]
    assert body["connected_at"]
    assert body["counterpart"] == {"id": CONNECTIONS_MOTHER, "name": "Ani", "role": "mother"}
    assert body.keys() == {"id", "connected_at", "counterpart"}, body


def test_a_mother_redeems_a_companion_code(mock_client, connections_table):
    client = _as(CONNECTIONS_MOTHER, mock_client)
    connections_table(
        profiles=PROFILES(),
        invite_codes=[invite_code_row(CONNECTIONS_COMPANION, "CCCC-DDDD", "mother")],
    )

    resp = client.post(
        "/connections", headers=AUTH, json={"code": "CCCC-DDDD"}
    )
    assert resp.status_code == 201, resp.text
    body = resp.json()
    assert body["counterpart"] == {"id": CONNECTIONS_COMPANION, "name": "Budi", "role": "companion"}


def test_a_professional_redeems_a_mother_code(mock_client, connections_table):
    client = _as(CONNECTIONS_PROFESSIONAL, mock_client)
    connections_table(
        profiles=PROFILES(),
        invite_codes=[invite_code_row(CONNECTIONS_MOTHER, "EEEE-FFFF", "professional")],
    )

    resp = client.post(
        "/connections", headers=AUTH, json={"code": "EEEE-FFFF"}
    )
    assert resp.status_code == 201, resp.text
    assert resp.json()["counterpart"] == {"id": CONNECTIONS_MOTHER, "name": "Ani", "role": "mother"}


def test_a_code_is_normalised_when_redeemed(mock_client, connections_table):
    client = _as(CONNECTIONS_COMPANION, mock_client)
    connections_table(
        profiles=PROFILES(),
        invite_codes=[invite_code_row(CONNECTIONS_MOTHER, "AAAA-BBBB", "companion")],
    )

    resp = client.post(
        "/connections", headers=AUTH, json={"code": "aaaabbbb"}
    )
    assert resp.status_code == 201, resp.text


def test_redeeming_the_same_code_twice_is_an_indistinguishable_404(
    mock_client, connections_table
):
    client = _as(CONNECTIONS_COMPANION, mock_client)
    connections_table(
        profiles=PROFILES(),
        invite_codes=[invite_code_row(CONNECTIONS_MOTHER, "AAAA-BBBB", "companion")],
    )

    first = client.post("/connections", headers=AUTH, json={"code": "AAAA-BBBB"})
    assert first.status_code == 201, first.text

    second = client.post("/connections", headers=AUTH, json={"code": "AAAA-BBBB"})
    assert second.status_code == 404, second.text
    assert second.json() == {"detail": "Invite code is not valid"}


def test_expired_revoked_and_unknown_codes_share_one_answer(
    mock_client, connections_table
):
    client = _as(CONNECTIONS_COMPANION, mock_client)
    past = (datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=1)).isoformat()
    connections_table(
        profiles=PROFILES(),
        invite_codes=[
            invite_code_row(
                CONNECTIONS_MOTHER, "AAAA-BBBB", "companion", expires_at=past
            ),
            invite_code_row(
                CONNECTIONS_MOTHER, "CCCC-DDDD", "companion", revoked_at="2026-11-15T11:00:00+00:00"
            ),
        ],
    )

    for code in ("AAAA-BBBB", "CCCC-DDDD", "ZZZZ-9999"):
        resp = client.post("/connections", headers=AUTH, json={"code": code})
        assert resp.status_code == 404, (code, resp.text)
        assert resp.json() == {"detail": "Invite code is not valid"}, (code, resp.text)


def test_a_malformed_code_is_a_400_distinguishable_from_a_404(mock_client, connections_table):
    client = _as(CONNECTIONS_COMPANION, mock_client)
    connections_table(profiles=PROFILES())

    resp = client.post("/connections", headers=AUTH, json={"code": "abc"})
    assert resp.status_code == 400, resp.text
    assert resp.json() != {"detail": "Invite code is not valid"}, resp.text

    long = "A" * 200
    resp = client.post("/connections", headers=AUTH, json={"code": long})
    assert resp.status_code == 400, resp.text
    assert resp.json() != {"detail": "Invite code is not valid"}, resp.text


def test_a_code_targeting_another_role_is_a_403_naming_the_role(
    mock_client, connections_table
):
    client = _as(CONNECTIONS_COMPANION, mock_client)
    connections_table(
        profiles=PROFILES(),
        invite_codes=[invite_code_row(CONNECTIONS_MOTHER, "AAAA-BBBB", "professional")],
    )

    resp = client.post("/connections", headers=AUTH, json={"code": "AAAA-BBBB"})
    assert resp.status_code == 403, resp.text
    assert "professional" in resp.json()["detail"].lower()


def test_a_failed_redemption_leaves_the_code_live(mock_client, connections_table):
    client = _as(CONNECTIONS_COMPANION, mock_client)
    connections_table(
        profiles=PROFILES(),
        connections=[
            connection_row(CONNECTIONS_OTHER_MOTHER, CONNECTIONS_COMPANION, "companion")
        ],
        invite_codes=[invite_code_row(CONNECTIONS_MOTHER, "AAAA-BBBB", "companion")],
    )

    refused = client.post(
        "/connections", headers=AUTH, json={"code": "AAAA-BBBB"}
    )
    assert refused.status_code == 409, refused.text
    assert refused.json()["detail"] == "You are already connected to a mother"

    still_refused = client.post(
        "/connections", headers=AUTH, json={"code": "AAAA-BBBB"}
    )
    assert still_refused.status_code == 409, still_refused.text

    other_client = _as(CONNECTIONS_OTHER_COMPANION, mock_client)
    allowed = other_client.post(
        "/connections", headers=AUTH, json={"code": "AAAA-BBBB"}
    )
    assert allowed.status_code == 201, allowed.text


def test_a_mother_already_holding_a_professional_is_a_409_and_not_burned(
    mock_client, connections_table
):
    client = _as(CONNECTIONS_PROFESSIONAL, mock_client)
    connections_table(
        profiles=PROFILES(),
        connections=[
            connection_row(
                CONNECTIONS_MOTHER, CONNECTIONS_PROFESSIONAL, "professional"
            )
        ],
        invite_codes=[invite_code_row(CONNECTIONS_MOTHER, "AAAA-BBBB", "professional")],
    )

    refused = client.post(
        "/connections", headers=AUTH, json={"code": "AAAA-BBBB"}
    )
    assert refused.status_code == 409, refused.text
    assert refused.json()["detail"] == "This mother already has a professional"

    still_refused = client.post(
        "/connections", headers=AUTH, json={"code": "AAAA-BBBB"}
    )
    assert still_refused.status_code == 409, still_refused.text


def test_a_mother_may_redeem_several_companion_codes(mock_client, connections_table):
    client = _as(CONNECTIONS_MOTHER, mock_client)
    connections_table(
        profiles=PROFILES(),
        invite_codes=[
            invite_code_row(CONNECTIONS_COMPANION, "AAAA-BBBB", "mother"),
            invite_code_row(CONNECTIONS_OTHER_COMPANION, "CCCC-DDDD", "mother"),
        ],
    )

    first = client.post("/connections", headers=AUTH, json={"code": "AAAA-BBBB"})
    assert first.status_code == 201, first.text

    second = client.post("/connections", headers=AUTH, json={"code": "CCCC-DDDD"})
    assert second.status_code == 201, second.text


def test_a_professional_redeems_after_the_first_connection_ended(
    mock_client, connections_table
):
    client = _as(CONNECTIONS_PROFESSIONAL, mock_client)
    connections_table(
        profiles=PROFILES(),
        connections=[
            connection_row(
                CONNECTIONS_MOTHER,
                CONNECTIONS_PROFESSIONAL,
                "professional",
                ended_at="2026-11-14T10:00:00+00:00",
            )
        ],
        invite_codes=[invite_code_row(CONNECTIONS_MOTHER, "AAAA-BBBB", "professional")],
    )

    resp = client.post("/connections", headers=AUTH, json={"code": "AAAA-BBBB"})
    assert resp.status_code == 201, resp.text


def test_a_mother_redeeming_a_second_professional_code_is_a_409(
    mock_client, connections_table
):
    client = _as(CONNECTIONS_MOTHER, mock_client)
    connections_table(
        profiles=PROFILES(),
        connections=[
            connection_row(
                CONNECTIONS_MOTHER, CONNECTIONS_PROFESSIONAL, "professional"
            )
        ],
        invite_codes=[
            invite_code_row(CONNECTIONS_PROFESSIONAL, "AAAA-BBBB", "mother")
        ],
    )

    refused = client.post("/connections", headers=AUTH, json={"code": "AAAA-BBBB"})
    assert refused.status_code == 409, refused.text
    assert refused.json()["detail"] == "This mother already has a professional"

    still_refused = client.post(
        "/connections", headers=AUTH, json={"code": "AAAA-BBBB"}
    )
    assert still_refused.status_code == 409, still_refused.text


def test_a_mother_redeems_a_professional_code_after_the_first_ended(
    mock_client, connections_table
):
    client = _as(CONNECTIONS_MOTHER, mock_client)
    connections_table(
        profiles=PROFILES(),
        connections=[
            connection_row(
                CONNECTIONS_MOTHER,
                CONNECTIONS_PROFESSIONAL,
                "professional",
                ended_at="2026-11-14T10:00:00+00:00",
            )
        ],
        invite_codes=[
            invite_code_row(CONNECTIONS_PROFESSIONAL, "AAAA-BBBB", "mother")
        ],
    )

    resp = client.post("/connections", headers=AUTH, json={"code": "AAAA-BBBB"})
    assert resp.status_code == 201, resp.text
    assert resp.json()["counterpart"] == {"id": CONNECTIONS_PROFESSIONAL, "name": "Dr. Ratna", "role": "professional"}


def test_a_deleted_redeemer_cannot_redeem(mock_client, connections_table):
    client = _as(CONNECTIONS_COMPANION, mock_client)
    profiles = connections_profiles()
    profiles[CONNECTIONS_COMPANION] = {
        **profiles[CONNECTIONS_COMPANION],
        "deleted_at": "2026-11-14T10:00:00+00:00",
    }
    connections_table(
        profiles=profiles,
        invite_codes=[invite_code_row(CONNECTIONS_MOTHER, "AAAA-BBBB", "companion")],
    )

    resp = client.post("/connections", headers=AUTH, json={"code": "AAAA-BBBB"})
    assert resp.status_code == 404, resp.text


def test_a_code_from_a_since_deleted_issuer_is_not_valid(mock_client, connections_table):
    client = _as(CONNECTIONS_COMPANION, mock_client)
    profiles = connections_profiles()
    profiles[CONNECTIONS_MOTHER] = {
        **profiles[CONNECTIONS_MOTHER],
        "deleted_at": "2026-11-14T10:00:00+00:00",
    }
    connections_table(
        profiles=profiles,
        invite_codes=[invite_code_row(CONNECTIONS_MOTHER, "AAAA-BBBB", "companion")],
    )

    resp = client.post("/connections", headers=AUTH, json={"code": "AAAA-BBBB"})
    assert resp.status_code == 404, resp.text
    assert resp.json() == {"detail": "Invite code is not valid"}


def test_an_extra_field_is_rejected(mock_client, connections_table):
    client = _as(CONNECTIONS_COMPANION, mock_client)
    connections_table(
        profiles=PROFILES(),
        invite_codes=[invite_code_row(CONNECTIONS_MOTHER, "AAAA-BBBB", "companion")],
    )

    resp = client.post(
        "/connections", headers=AUTH, json={"code": "AAAA-BBBB", "extra": "nope"}
    )
    assert resp.status_code == 422, resp.text


def test_an_unauthenticated_request_is_rejected(mock_client, connections_table):
    client, _ = mock_client
    connections_table(
        profiles=PROFILES(),
        invite_codes=[invite_code_row(CONNECTIONS_MOTHER, "AAAA-BBBB", "companion")],
    )
    main.app.dependency_overrides.pop(verified_session, None)

    resp = client.post(
        "/connections", headers={}, json={"code": "AAAA-BBBB"}
    )
    assert resp.status_code == 401, resp.text
