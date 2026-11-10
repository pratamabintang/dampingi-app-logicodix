import os

import httpx
import pytest

pytestmark = pytest.mark.live


def _headers(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def _issue_and_redeem(client, issuer_token: str, target_role: str, redeemer_token: str) -> str:
    resp = client.post(
        "/connections/invite-codes",
        headers=_headers(issuer_token),
        json={"target_role": target_role},
    )
    assert resp.status_code == 201, resp.text
    redeem = client.post(
        "/connections", headers=_headers(redeemer_token), json={"code": resp.json()["code"]}
    )
    assert redeem.status_code == 201, redeem.text
    return redeem.json()["id"]


def _service_rows(user_id: str) -> list:
    base = os.environ["SUPABASE_URL"].rstrip("/")
    resp = httpx.get(
        f"{base}/rest/v1/connections",
        params={
            "or": f"(mother_id.eq.{user_id},counterpart_id.eq.{user_id})",
            "select": "id,ended_at,ended_by,mother_id,counterpart_id,counterpart_role",
        },
        headers={
            "apikey": os.environ["SUPABASE_SECRET_KEY"],
            "Authorization": f"Bearer {os.environ['SUPABASE_SECRET_KEY']}",
        },
        timeout=10,
    )
    assert resp.status_code == 200, resp.text
    return resp.json()


def test_soft_deleting_a_mother_stamps_and_survives(client, register):
    _, mother_user, mother_token = register(role="mother")
    _, _, companion_token = register(role="companion")
    _, _, professional_token = register(role="professional")

    _issue_and_redeem(client, mother_token, "companion", companion_token)
    _issue_and_redeem(client, mother_token, "professional", professional_token)

    deleted = client.delete("/me", headers=_headers(mother_token))
    assert deleted.status_code == 204, deleted.text

    rows = _service_rows(mother_user["id"])
    assert len(rows) == 2, rows
    for row in rows:
        assert row["ended_at"], row
        assert row["ended_by"] == mother_user["id"], row


def test_the_survivor_can_reconnect_after_a_soft_delete(client, register):
    _, mother_user, mother_token = register(role="mother")
    _, _, companion_token = register(role="companion")
    _issue_and_redeem(client, mother_token, "companion", companion_token)

    deleted = client.delete("/me", headers=_headers(mother_token))
    assert deleted.status_code == 204, deleted.text

    _, _, other_mother_token = register(role="mother")
    _issue_and_redeem(client, other_mother_token, "companion", companion_token)


def test_soft_deleting_a_professional_stamps_their_connection(client, register):
    _, _, mother_token = register(role="mother")
    _, professional_user, professional_token = register(role="professional")
    connection_id = _issue_and_redeem(
        client, mother_token, "professional", professional_token
    )

    deleted = client.delete("/me", headers=_headers(professional_token))
    assert deleted.status_code == 204, deleted.text

    base = os.environ["SUPABASE_URL"].rstrip("/")
    resp = httpx.get(
        f"{base}/rest/v1/connections",
        params={"id": f"eq.{connection_id}", "select": "id,ended_at,ended_by"},
        headers={
            "apikey": os.environ["SUPABASE_SECRET_KEY"],
            "Authorization": f"Bearer {os.environ['SUPABASE_SECRET_KEY']}",
        },
        timeout=10,
    )
    assert resp.status_code == 200, resp.text
    rows = resp.json()
    assert len(rows) == 1, rows
    assert rows[0]["ended_at"], rows
    assert rows[0]["ended_by"] == professional_user["id"], rows


def test_an_unauthenticated_request_is_rejected(client):
    resp = client.delete("/me", headers={})

    assert resp.status_code == 401, resp.text
