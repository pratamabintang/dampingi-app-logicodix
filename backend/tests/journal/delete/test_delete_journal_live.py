import pytest

pytestmark = pytest.mark.live


def _headers(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def _write(client, token, **overrides):
    payload = {
        "title": "To be deleted",
        "content": "Not for long.",
        "created_at": "2026-10-20",
        **overrides,
    }
    resp = client.post("/journals", headers=_headers(token), json=payload)
    assert resp.status_code == 201, resp.text
    return resp.json()


def test_deleting_an_Journal_removes_it(client, register):
    _, _, token = register(role="mother")
    written = _write(client, token)

    deleted = client.delete(f"/journals/{written['id']}", headers=_headers(token))

    assert deleted.status_code == 204, deleted.text
    assert (
        client.get(f"/journals/{written['id']}", headers=_headers(token)).status_code
        == 404
    )


def test_the_deleted_Journal_leaves_the_list(client, register):
    _, _, token = register(role="mother")
    _write(client, token, created_at="2026-10-20", title="Deleted")
    _write(client, token, created_at="2026-10-19", title="Kept")

    listed = client.get("/journals", headers=_headers(token))
    assert listed.status_code == 200, listed.text
    deleted = next(
        j for j in listed.json()["journals"] if j["title"] == "Deleted"
    )
    client.delete(f"/journals/{deleted['id']}", headers=_headers(token))

    after = client.get("/journals", headers=_headers(token))
    assert after.status_code == 200, after.text
    body = after.json()
    assert body["count"] == 1
    assert [j["title"] for j in body["journals"]] == ["Kept"]


def test_deleting_an_unknown_id_is_not_found(client, register):
    _, _, token = register(role="mother")

    resp = client.delete(
        "/journals/00000000-0000-4000-8000-00000000dead",
        headers=_headers(token),
    )

    assert resp.status_code == 404, resp.text


def test_another_authors_journal_may_not_be_deleted(client, register):
    _, _, alice = register(role="mother")
    _, _, bob = register(role="companion")
    written = _write(client, alice)

    resp = client.delete(f"/journals/{written['id']}", headers=_headers(bob))

    assert resp.status_code == 404, resp.text
    assert resp.status_code != 403

    read = client.get(f"/journals/{written['id']}", headers=_headers(alice))
    assert read.status_code == 200, read.text
    assert read.json()["title"] == written["title"]


def test_a_malformed_id_is_refused(client, register):
    _, _, token = register(role="mother")

    resp = client.delete("/journals/not-a-uuid", headers=_headers(token))

    assert resp.status_code == 422, resp.text


def test_a_professional_may_not_delete(client, register):
    _, _, token = register(role="professional")

    resp = client.delete(
        "/journals/00000000-0000-4000-8000-0000000000aa",
        headers=_headers(token),
    )

    assert resp.status_code == 403, resp.text


def test_deleting_with_no_auth_is_refused(client):
    resp = client.delete("/journals/00000000-0000-4000-8000-0000000000aa")

    assert resp.status_code == 401
