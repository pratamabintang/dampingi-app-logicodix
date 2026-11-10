from datetime import datetime

import pytest

pytestmark = pytest.mark.live


def _headers(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def _issue(client, token: str, target_role: str):
    resp = client.post(
        "/connections/invite-codes",
        headers=_headers(token),
        json={"target_role": target_role},
    )
    assert resp.status_code == 201, resp.text
    return resp.json()


def test_an_issuer_sees_their_live_codes_with_a_total(client, register):
    _, _, token = register(role="mother")
    _issue(client, token, "companion")
    _issue(client, token, "professional")

    resp = client.get("/connections/invite-codes", headers=_headers(token))

    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body.keys() == {"invite_codes", "count", "offset", "limit", "total"}
    assert body["count"] == 2
    assert body["total"] == 2
    assert body["offset"] == 0
    for item in body["invite_codes"]:
        assert item["code"]
        assert item["target_role"] in ("companion", "professional")
        datetime.fromisoformat(item["expires_at"])


def test_a_redeemed_code_leaves_the_issuer_s_list(client, register):
    _, _, mother_token = register(role="mother")
    _, _, companion_token = register(role="companion")

    code = _issue(client, mother_token, "companion")["code"]
    redeem = client.post(
        "/connections", headers=_headers(companion_token), json={"code": code}
    )
    assert redeem.status_code == 201, redeem.text

    listed = client.get("/connections/invite-codes", headers=_headers(mother_token))

    assert listed.status_code == 200, listed.text
    assert listed.json()["count"] == 0


def test_an_unauthenticated_request_is_rejected(client):
    resp = client.get("/connections/invite-codes", headers={})

    assert resp.status_code == 401, resp.text
