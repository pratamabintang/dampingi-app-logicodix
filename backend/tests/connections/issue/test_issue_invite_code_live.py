import re
from datetime import datetime, timedelta

import pytest

pytestmark = pytest.mark.live

PATTERN = re.compile(r"^[A-HJKMNP-Z2-9]{4}-[A-HJKMNP-Z2-9]{4}$")


def _headers(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def test_a_mother_issues_a_companion_code(client, register):
    _, _, token = register(role="mother")

    resp = client.post(
        "/connections/invite-codes",
        headers=_headers(token),
        json={"target_role": "companion"},
    )

    assert resp.status_code == 201, resp.text
    body = resp.json()
    assert PATTERN.fullmatch(body["code"]), body["code"]
    assert body["target_role"] == "companion"
    assert body["id"]


def test_the_expiry_is_one_hour_and_parseable(client, register):
    _, _, token = register(role="mother")

    before = datetime.now().astimezone()
    resp = client.post(
        "/connections/invite-codes",
        headers=_headers(token),
        json={"target_role": "companion"},
    )
    after = datetime.now().astimezone()

    assert resp.status_code == 201, resp.text
    expires = datetime.fromisoformat(resp.json()["expires_at"])

    assert before + timedelta(hours=1) <= expires <= after + timedelta(hours=1)


def test_a_companion_issues_a_mother_code(client, register):
    _, _, token = register(role="companion")

    resp = client.post(
        "/connections/invite-codes",
        headers=_headers(token),
        json={"target_role": "mother"},
    )

    assert resp.status_code == 201, resp.text
    assert resp.json()["target_role"] == "mother"


def test_a_professional_issues_a_mother_code(client, register):
    _, _, token = register(role="professional")

    resp = client.post(
        "/connections/invite-codes",
        headers=_headers(token),
        json={"target_role": "mother"},
    )

    assert resp.status_code == 201, resp.text


def test_a_mother_cannot_invite_a_mother(client, register):
    _, _, token = register(role="mother")

    resp = client.post(
        "/connections/invite-codes",
        headers=_headers(token),
        json={"target_role": "mother"},
    )

    assert resp.status_code == 400, resp.text


def test_codes_are_not_shared_between_issuers(client, register):
    _, _, first = register(role="mother")
    _, _, second = register(role="mother")

    one = client.post(
        "/connections/invite-codes",
        headers=_headers(first),
        json={"target_role": "companion"},
    )
    two = client.post(
        "/connections/invite-codes",
        headers=_headers(second),
        json={"target_role": "companion"},
    )

    assert one.status_code == 201, one.text
    assert two.status_code == 201, two.text
    assert one.json()["code"] != two.json()["code"]


def test_an_unauthenticated_request_is_rejected(client):
    resp = client.post(
        "/connections/invite-codes", headers={}, json={"target_role": "companion"}
    )

    assert resp.status_code == 401, resp.text
