import uuid

import pytest

pytestmark = pytest.mark.live


def _headers(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def _connect(client, mother_token: str, companion_token: str) -> None:
    issued = client.post(
        "/connections/invite-codes",
        headers=_headers(mother_token),
        json={"target_role": "companion"},
    )
    assert issued.status_code == 201, issued.text
    redeemed = client.post(
        "/connections",
        headers=_headers(companion_token),
        json={"code": issued.json()["code"]},
    )
    assert redeemed.status_code == 201, redeemed.text


def test_a_connected_companion_creates_an_observation(client, register):
    _, mother, mother_token = register(role="mother")
    _, _, companion_token = register(role="companion")
    _connect(client, mother_token, companion_token)

    resp = client.post(
        "/observations",
        headers=_headers(companion_token),
        json={
            "mother_id": mother["id"],
            "questions": [
                {
                    "prompt": "How did she sleep last night?",
                    "options": [{"label": "Well"}, {"label": "Poorly"}],
                }
            ],
        },
    )

    assert resp.status_code == 201, resp.text
    body = resp.json()
    assert uuid.UUID(body["id"])
    assert uuid.UUID(body["connection_id"])
    assert body["mother_id"] == mother["id"]
    assert body["answers"] is None
    assert body["day"] is None
    assert body["completed_at"] is None
    assert body["created_at"]
    assert body["questions"] == [
        {
            "id": "q1",
            "prompt": "How did she sleep last night?",
            "options": [
                {"id": "q1o1", "label": "Well"},
                {"id": "q1o2", "label": "Poorly"},
            ],
        }
    ]
