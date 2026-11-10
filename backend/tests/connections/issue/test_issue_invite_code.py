from conftest import (
    CONNECTIONS_COMPANION,
    CONNECTIONS_MOTHER,
    CONNECTIONS_PROFESSIONAL,
    connection_row,
    connections_profiles,
    invite_code_row,
)

from app.connections import service as service_module

AUTH = {"Authorization": "Bearer offline-token"}

PROFILES = connections_profiles()


def _as(user_id, mock_client):
    import app.main as main
    from app.auth import service
    from app.auth.router import verified_session

    client, _ = mock_client
    main.app.dependency_overrides[verified_session] = lambda: service.Session(
        user_id=user_id, email="offline@gmail.com", token="offline-token"
    )
    return client


def test_a_mother_issues_a_companion_code(mock_client, connections_table):
    client = _as(CONNECTIONS_MOTHER, mock_client)
    connections_table(profiles=PROFILES)

    resp = client.post(
        "/connections/invite-codes", headers=AUTH, json={"target_role": "companion"}
    )

    assert resp.status_code == 201, resp.text
    body = resp.json()
    assert body["id"]
    assert body["target_role"] == "companion"
    assert body["expires_at"]
    assert body["code"]


def test_the_code_is_eight_unambiguous_characters(mock_client, connections_table):
    import re

    client = _as(CONNECTIONS_MOTHER, mock_client)
    connections_table(profiles=PROFILES)

    for _ in range(40):
        resp = client.post(
            "/connections/invite-codes", headers=AUTH, json={"target_role": "companion"}
        )
        assert resp.status_code == 201, resp.text
        code = resp.json()["code"]
        assert re.fullmatch(r"[A-HJKMNP-Z2-9]{4}-[A-HJKMNP-Z2-9]{4}", code), code
        assert not set(code) & {"I", "L", "O", "0", "1"}, code


def test_the_alphabet_equals_the_column_check():
    import pathlib
    import re

    migration = (
        pathlib.Path(__file__).resolve().parents[4]
        / "supabase"
        / "migrations"
        / "20261110120002_connections.sql"
    )
    sql = migration.read_text(encoding="utf-8")

    match = re.search(r"code ~ '\^\[([^\]]+)\]\{4\}-\[([^\]]+)\]\{4\}\$'", sql)
    assert match, "could not find the code CHECK in the migration"

    check_alphabet = _expand_char_class(match.group(1))
    assert match.group(1) == match.group(2), "the two halves of the CHECK differ"
    assert check_alphabet == set(service_module.ALPHABET), (
        f"CHECK allows {''.join(sorted(check_alphabet))} but the generator "
        f"uses {''.join(sorted(service_module.ALPHABET))}"
    )


def _expand_char_class(char_class: str) -> set:
    members = set()
    i = 0
    while i < len(char_class):
        if i + 2 < len(char_class) and char_class[i + 1] == "-":
            low, high = char_class[i], char_class[i + 2]
            members.update(chr(c) for c in range(ord(low), ord(high) + 1))
            i += 3
        else:
            members.add(char_class[i])
            i += 1
    return members


def test_the_code_lives_exactly_one_hour(mock_client, connections_table):
    from datetime import datetime, timedelta

    client = _as(CONNECTIONS_MOTHER, mock_client)
    connections_table(profiles=PROFILES)

    before = datetime.now().astimezone()
    resp = client.post(
        "/connections/invite-codes", headers=AUTH, json={"target_role": "companion"}
    )
    after = datetime.now().astimezone()

    assert resp.status_code == 201, resp.text
    expires = datetime.fromisoformat(resp.json()["expires_at"])

    assert before + timedelta(hours=1) <= expires <= after + timedelta(hours=1)


def test_a_mother_issues_a_professional_code(mock_client, connections_table):
    client = _as(CONNECTIONS_MOTHER, mock_client)
    connections_table(profiles=PROFILES)

    resp = client.post(
        "/connections/invite-codes", headers=AUTH, json={"target_role": "professional"}
    )

    assert resp.status_code == 201, resp.text
    assert resp.json()["target_role"] == "professional"


def test_a_companion_issues_a_mother_code(mock_client, connections_table):
    client = _as(CONNECTIONS_COMPANION, mock_client)
    connections_table(profiles=PROFILES)

    resp = client.post(
        "/connections/invite-codes", headers=AUTH, json={"target_role": "mother"}
    )

    assert resp.status_code == 201, resp.text
    assert resp.json()["target_role"] == "mother"


def test_a_professional_issues_a_mother_code(mock_client, connections_table):
    client = _as(CONNECTIONS_PROFESSIONAL, mock_client)
    connections_table(profiles=PROFILES)

    resp = client.post(
        "/connections/invite-codes", headers=AUTH, json={"target_role": "mother"}
    )

    assert resp.status_code == 201, resp.text
    assert resp.json()["target_role"] == "mother"


def test_a_mother_cannot_invite_another_mother(mock_client, connections_table):
    client = _as(CONNECTIONS_MOTHER, mock_client)
    connections_table(profiles=PROFILES)

    resp = client.post(
        "/connections/invite-codes", headers=AUTH, json={"target_role": "mother"}
    )

    assert resp.status_code == 400, resp.text


def test_a_companion_cannot_invite_another_companion(mock_client, connections_table):
    client = _as(CONNECTIONS_COMPANION, mock_client)
    connections_table(profiles=PROFILES)

    resp = client.post(
        "/connections/invite-codes", headers=AUTH, json={"target_role": "companion"}
    )

    assert resp.status_code == 400, resp.text


def test_a_refused_limit_creates_no_code(mock_client, connections_table):
    client = _as(CONNECTIONS_MOTHER, mock_client)
    rec = connections_table(
        profiles=PROFILES,
        connections=[
            connection_row(
                CONNECTIONS_MOTHER, CONNECTIONS_PROFESSIONAL, "professional"
            )
        ],
    )

    refused = client.post(
        "/connections/invite-codes", headers=AUTH, json={"target_role": "professional"}
    )
    assert refused.status_code == 409, refused.text

    allowed = client.post(
        "/connections/invite-codes", headers=AUTH, json={"target_role": "companion"}
    )
    assert allowed.status_code == 201, allowed.text


def test_a_refused_target_creates_no_code(mock_client, connections_table):
    client = _as(CONNECTIONS_MOTHER, mock_client)
    connections_table(profiles=PROFILES)

    refused = client.post(
        "/connections/invite-codes", headers=AUTH, json={"target_role": "mother"}
    )
    assert refused.status_code == 400, refused.text

    allowed = client.post(
        "/connections/invite-codes", headers=AUTH, json={"target_role": "companion"}
    )
    assert allowed.status_code == 201, allowed.text


def test_a_mother_with_a_professional_cannot_invite_one(
    mock_client, connections_table
):
    client = _as(CONNECTIONS_MOTHER, mock_client)
    connections_table(
        profiles=PROFILES,
        connections=[
            connection_row(
                CONNECTIONS_MOTHER, CONNECTIONS_PROFESSIONAL, "professional"
            )
        ],
    )

    resp = client.post(
        "/connections/invite-codes", headers=AUTH, json={"target_role": "professional"}
    )

    assert resp.status_code == 409, resp.text
    assert "professional" in resp.json()["detail"]


def test_a_mother_with_a_professional_may_still_invite_companions(
    mock_client, connections_table
):
    client = _as(CONNECTIONS_MOTHER, mock_client)
    connections_table(
        profiles=PROFILES,
        connections=[
            connection_row(
                CONNECTIONS_MOTHER, CONNECTIONS_PROFESSIONAL, "professional"
            )
        ],
    )

    resp = client.post(
        "/connections/invite-codes", headers=AUTH, json={"target_role": "companion"}
    )

    assert resp.status_code == 201, resp.text


def test_a_companion_already_connected_cannot_invite_a_mother(
    mock_client, connections_table
):
    client = _as(CONNECTIONS_COMPANION, mock_client)
    connections_table(
        profiles=PROFILES,
        connections=[
            connection_row(CONNECTIONS_MOTHER, CONNECTIONS_COMPANION, "companion")
        ],
    )

    resp = client.post(
        "/connections/invite-codes", headers=AUTH, json={"target_role": "mother"}
    )

    assert resp.status_code == 409, resp.text
    assert "mother" in resp.json()["detail"]


def test_a_professional_already_connected_may_invite_another_mother(
    mock_client, connections_table
):
    client = _as(CONNECTIONS_PROFESSIONAL, mock_client)
    connections_table(
        profiles=PROFILES,
        connections=[
            connection_row(
                CONNECTIONS_MOTHER, CONNECTIONS_PROFESSIONAL, "professional"
            )
        ],
    )

    resp = client.post(
        "/connections/invite-codes", headers=AUTH, json={"target_role": "mother"}
    )

    assert resp.status_code == 201, resp.text


def test_an_ended_connection_frees_the_professional_slot(
    mock_client, connections_table
):
    client = _as(CONNECTIONS_MOTHER, mock_client)
    connections_table(
        profiles=PROFILES,
        connections=[
            connection_row(
                CONNECTIONS_MOTHER,
                CONNECTIONS_PROFESSIONAL,
                "professional",
                ended_at="2026-11-14T10:00:00+00:00",
            )
        ],
    )

    resp = client.post(
        "/connections/invite-codes", headers=AUTH, json={"target_role": "professional"}
    )

    assert resp.status_code == 201, resp.text


def test_a_colliding_code_is_retried_not_surfaced(
    mock_client, connections_table, monkeypatch
):
    client = _as(CONNECTIONS_MOTHER, mock_client)

    taken = "AAAA-BBBB"
    fresh = "CCCC-DDDD"
    issued = iter([taken, fresh])

    monkeypatch.setattr(
        service_module, "generate_code", lambda: next(issued, "ZZZZ-ZZZZ")
    )

    connections_table(
        profiles=PROFILES,
        invite_codes=[invite_code_row(CONNECTIONS_MOTHER, taken)],
    )

    resp = client.post(
        "/connections/invite-codes", headers=AUTH, json={"target_role": "companion"}
    )

    assert resp.status_code == 201, resp.text
    assert resp.json()["code"] == fresh


def test_an_unauthenticated_request_is_rejected(mock_client, connections_table):
    import app.main as main
    from app.auth.router import verified_session

    client, _ = mock_client
    connections_table(profiles=PROFILES)
    main.app.dependency_overrides.pop(verified_session, None)

    resp = client.post(
        "/connections/invite-codes", headers={}, json={"target_role": "companion"}
    )

    assert resp.status_code == 401, resp.text


def test_an_unknown_target_role_is_rejected(mock_client, connections_table):
    client = _as(CONNECTIONS_MOTHER, mock_client)
    connections_table(profiles=PROFILES)

    resp = client.post(
        "/connections/invite-codes", headers=AUTH, json={"target_role": "doctor"}
    )

    assert resp.status_code == 422, resp.text


def test_an_extra_field_is_rejected(mock_client, connections_table):
    client = _as(CONNECTIONS_MOTHER, mock_client)
    connections_table(profiles=PROFILES)

    resp = client.post(
        "/connections/invite-codes",
        headers=AUTH,
        json={"target_role": "companion", "expires_in": 999},
    )

    assert resp.status_code == 422, resp.text


def test_a_deleted_profile_cannot_issue_a_code(mock_client, connections_table):
    client = _as(CONNECTIONS_MOTHER, mock_client)
    profiles = connections_profiles()
    profiles[CONNECTIONS_MOTHER] = {
        **profiles[CONNECTIONS_MOTHER],
        "deleted_at": "2026-11-14T10:00:00+00:00",
    }
    connections_table(profiles=profiles)

    resp = client.post(
        "/connections/invite-codes", headers=AUTH, json={"target_role": "companion"}
    )

    assert resp.status_code == 404, resp.text


def test_all_three_roles_may_issue(mock_client, connections_table):
    for user_id, target in (
        (CONNECTIONS_MOTHER, "companion"),
        (CONNECTIONS_COMPANION, "mother"),
        (CONNECTIONS_PROFESSIONAL, "mother"),
    ):
        client = _as(user_id, mock_client)
        connections_table(profiles=PROFILES)

        resp = client.post(
            "/connections/invite-codes", headers=AUTH, json={"target_role": target}
        )

        assert resp.status_code == 201, (user_id, resp.text)
