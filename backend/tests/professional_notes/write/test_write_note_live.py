import pytest

pytestmark = pytest.mark.live


def _headers(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def _issue(client, token: str, target_role: str) -> str:
    resp = client.post(
        "/connections/invite-codes",
        headers=_headers(token),
        json={"target_role": target_role},
    )
    assert resp.status_code == 201, resp.text
    return resp.json()["code"]


def _active_connection(client, professional_token: str, mother_token: str) -> str:
    code = _issue(client, professional_token, "mother")
    resp = client.post("/connections", headers=_headers(mother_token), json={"code": code})
    assert resp.status_code == 201, resp.text
    return resp.json()["id"]


def test_a_professional_writes_and_the_mother_reads_a_note(client, register):
    _, mother_user, mother_token = register(role="mother")
    _, professional_user, professional_token = register(role="professional")

    connection_id = _active_connection(client, professional_token, mother_token)

    wrote = client.post(
        "/professional-notes",
        headers=_headers(professional_token),
        json={"connection_id": connection_id, "content": "  Sleep is improving.  "},
    )

    assert wrote.status_code == 201, wrote.text
    note = wrote.json()
    assert note["connection_id"] == connection_id
    assert note["content"] == "Sleep is improving."
    assert note["professional_id"] == professional_user["id"]
    assert note["mother_id"] == mother_user["id"]

    read = client.get(
        f"/professional-notes/{note['id']}", headers=_headers(mother_token)
    )

    assert read.status_code == 200, read.text
    assert read.json()["content"] == "Sleep is improving."
