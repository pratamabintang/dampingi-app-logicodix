import os

import httpx
import pytest

pytestmark = pytest.mark.live


def _headers(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def _service_row(connection_id: str) -> list:
    base = os.environ["SUPABASE_URL"].rstrip("/")
    resp = httpx.get(
        f"{base}/rest/v1/connections",
        params={
            "id": f"eq.{connection_id}",
            "select": "id,ended_at,ended_by,mother_id,counterpart_id",
        },
        headers={
            "apikey": os.environ["SUPABASE_SECRET_KEY"],
            "Authorization": f"Bearer {os.environ['SUPABASE_SECRET_KEY']}",
        },
        timeout=10,
    )
    assert resp.status_code == 200, resp.text
    return resp.json()


def _connect(client, issuer_token: str, issuer_role: str, redeemer_token: str):
    resp = client.post(
        "/connections/invite-codes",
        headers=_headers(issuer_token),
        json={"target_role": "companion" if issuer_role == "mother" else "mother"},
    )
    assert resp.status_code == 201, resp.text
    redeem = client.post(
        "/connections", headers=_headers(redeemer_token), json={"code": resp.json()["code"]}
    )
    assert redeem.status_code == 201, redeem.text
    return redeem.json()["id"]


def _list(client, token: str):
    resp = client.get("/connections", headers=_headers(token))
    assert resp.status_code == 200, resp.text
    return resp.json()


def test_either_end_ends_and_both_lists_go_empty(client, register):
    _, _, mother_token = register(role="mother")
    _, _, companion_token = register(role="companion")
    connection_id = _connect(client, mother_token, "mother", companion_token)

    ended = client.delete(
        f"/connections/{connection_id}", headers=_headers(companion_token)
    )
    assert ended.status_code == 204, ended.text

    assert _list(client, mother_token)["connections"] == []
    assert _list(client, companion_token)["connections"] == []

    second = client.delete(
        f"/connections/{connection_id}", headers=_headers(companion_token)
    )
    assert second.status_code == 404, second.text
    assert second.json() == {"detail": "Connection not found"}


def test_a_third_party_cannot_end_a_connection(client, register):
    _, _, mother_token = register(role="mother")
    _, _, companion_token = register(role="companion")
    _, _, outsider_token = register(role="professional")
    connection_id = _connect(client, mother_token, "mother", companion_token)

    resp = client.delete(
        f"/connections/{connection_id}", headers=_headers(outsider_token)
    )

    assert resp.status_code == 404, resp.text
    assert _list(client, mother_token)["count"] == 1
    assert _list(client, companion_token)["count"] == 1


def test_an_unauthenticated_request_is_rejected(client):
    resp = client.delete(
        "/connections/00000000-0000-4000-8000-000000000000", headers={}
    )

    assert resp.status_code == 401, resp.text


def test_the_ended_row_survives_with_its_history(client, register):
    _, mother_user, mother_token = register(role="mother")
    _, companion_user, companion_token = register(role="companion")
    connection_id = _connect(client, mother_token, "mother", companion_token)

    ended = client.delete(
        f"/connections/{connection_id}", headers=_headers(companion_token)
    )
    assert ended.status_code == 204, ended.text

    rows = _service_row(connection_id)
    assert len(rows) == 1, rows
    row = rows[0]
    assert row["ended_at"], row
    assert row["ended_by"] == companion_user["id"], row
    assert row["mother_id"] == mother_user["id"], row


def test_an_ended_connection_spends_the_limit_again(client, register):
    _, _, mother_token = register(role="mother")
    _, _, professional_token = register(role="professional")
    _, _, replacement_token = register(role="professional")
    connection_id = _connect_professional(client, mother_token, professional_token)

    ended = client.delete(
        f"/connections/{connection_id}", headers=_headers(mother_token)
    )
    assert ended.status_code == 204, ended.text

    issued = client.post(
        "/connections/invite-codes",
        headers=_headers(mother_token),
        json={"target_role": "professional"},
    )
    assert issued.status_code == 201, issued.text

    redeemed = client.post(
        "/connections",
        headers=_headers(replacement_token),
        json={"code": issued.json()["code"]},
    )
    assert redeemed.status_code == 201, redeemed.text


def _connect_professional(client, mother_token: str, professional_token: str) -> str:
    resp = client.post(
        "/connections/invite-codes",
        headers=_headers(mother_token),
        json={"target_role": "professional"},
    )
    assert resp.status_code == 201, resp.text
    redeem = client.post(
        "/connections",
        headers=_headers(professional_token),
        json={"code": resp.json()["code"]},
    )
    assert redeem.status_code == 201, redeem.text
    return redeem.json()["id"]
