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


def test_the_issuer_revokes_a_live_code(client, register):
    _, _, token = register(role="mother")
    code = _issue(client, token, "companion")

    first = client.delete(
        f"/connections/invite-codes/{code['id']}", headers=_headers(token)
    )
    assert first.status_code == 204, first.text

    listed = client.get("/connections/invite-codes", headers=_headers(token))
    assert listed.status_code == 200, listed.text
    assert listed.json()["count"] == 0

    second = client.delete(
        f"/connections/invite-codes/{code['id']}", headers=_headers(token)
    )
    assert second.status_code == 404, second.text


def test_revoking_another_profiles_code_is_a_404(client, register):
    _, _, mother_token = register(role="mother")
    _, _, other_token = register(role="mother")
    code = _issue(client, mother_token, "companion")

    resp = client.delete(
        f"/connections/invite-codes/{code['id']}", headers=_headers(other_token)
    )
    assert resp.status_code == 404, resp.text

    listed = client.get("/connections/invite-codes", headers=_headers(mother_token))
    assert listed.json()["count"] == 1, listed.text


def test_an_unauthenticated_request_is_rejected(client):
    resp = client.delete(
        "/connections/invite-codes/00000000-0000-4000-8000-000000000000", headers={}
    )

    assert resp.status_code == 401, resp.text
