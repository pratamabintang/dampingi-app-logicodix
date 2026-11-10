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


def test_both_ends_see_each_other_after_a_redeem(client, register):
    _, _, mother_token = register(role="mother")
    _, _, companion_token = register(role="companion")

    code = _issue(client, mother_token, "companion")["code"]
    redeem = client.post(
        "/connections", headers=_headers(companion_token), json={"code": code}
    )
    assert redeem.status_code == 201, redeem.text

    mother_list = client.get("/connections", headers=_headers(mother_token))
    assert mother_list.status_code == 200, mother_list.text
    mother_body = mother_list.json()
    assert mother_body["count"] == 1
    assert mother_body["connections"][0]["counterpart"]["role"] == "companion"
    assert mother_body["connections"][0].keys() == {
        "id",
        "connected_at",
        "counterpart",
    }
    assert mother_body["connections"][0]["counterpart"].keys() == {"name", "role"}

    companion_list = client.get("/connections", headers=_headers(companion_token))
    assert companion_list.status_code == 200, companion_list.text
    companion_body = companion_list.json()
    assert companion_body["count"] == 1
    assert companion_body["connections"][0]["counterpart"]["role"] == "mother"


def test_a_profile_with_no_connections_gets_an_empty_list(client, register):
    _, _, token = register(role="professional")

    resp = client.get("/connections", headers=_headers(token))

    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["connections"] == []
    assert body["count"] == 0
    assert body["total"] == 0


def test_an_unauthenticated_request_is_rejected(client):
    resp = client.get("/connections", headers={})

    assert resp.status_code == 401, resp.text
