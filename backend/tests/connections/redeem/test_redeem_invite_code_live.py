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


def test_a_companion_redeems_a_mothers_code(client, register):
    _, _, mother_token = register(role="mother")
    _, _, companion_token = register(role="companion")

    code = _issue(client, mother_token, "companion")["code"]

    resp = client.post(
        "/connections", headers=_headers(companion_token), json={"code": code}
    )

    assert resp.status_code == 201, resp.text
    body = resp.json()
    assert body["id"]
    assert body["connected_at"]
    assert body["counterpart"]["role"] == "mother"
    assert body.keys() == {"id", "connected_at", "counterpart"}, body


def test_a_redeemed_code_is_one_404_on_the_second_attempt(client, register):
    _, _, mother_token = register(role="mother")
    _, _, first_token = register(role="companion")
    _, _, second_token = register(role="companion")

    code = _issue(client, mother_token, "companion")["code"]

    first = client.post(
        "/connections", headers=_headers(first_token), json={"code": code}
    )
    assert first.status_code == 201, first.text

    second = client.post(
        "/connections", headers=_headers(second_token), json={"code": code}
    )
    assert second.status_code == 404, second.text
    assert second.json() == {"detail": "Invite code is not valid"}


def test_a_malformed_code_is_a_400(client, register):
    _, _, token = register(role="mother")

    resp = client.post("/connections", headers=_headers(token), json={"code": "abc"})

    assert resp.status_code == 400, resp.text


def test_an_unauthenticated_request_is_rejected(client):
    resp = client.post("/connections", headers={}, json={"code": "AAAA-BBBB"})

    assert resp.status_code == 401, resp.text
