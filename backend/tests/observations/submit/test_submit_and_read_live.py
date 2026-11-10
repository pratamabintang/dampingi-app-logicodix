from datetime import datetime, timezone

import pytest

pytestmark = pytest.mark.live

TODAY = datetime.now(timezone.utc).date().isoformat()


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


def _create(client, companion_token: str, mother_id: str) -> dict:
    resp = client.post(
        "/observations",
        headers=_headers(companion_token),
        json={
            "mother_id": mother_id,
            "questions": [
                {
                    "prompt": "How did she sleep last night?",
                    "options": [{"label": "Well"}, {"label": "Poorly"}],
                },
                {
                    "prompt": "How was her mood?",
                    "options": [{"label": "Calm"}, {"label": "Anxious"}],
                },
            ],
        },
    )
    assert resp.status_code == 201, resp.text
    return resp.json()


def _answers(observation: dict) -> list[dict]:
    return [
        {
            "question_id": question["id"],
            "option_id": question["options"][0]["id"],
        }
        for question in observation["questions"]
    ]


def test_submit_completes_a_draft_once(client, register):
    _, mother, mother_token = register(role="mother")
    _, _, companion_token = register(role="companion")
    _connect(client, mother_token, companion_token)
    draft = _create(client, companion_token, mother["id"])

    submitted = client.patch(
        f"/observations/{draft['id']}",
        headers=_headers(companion_token),
        json={"answers": _answers(draft), "day": TODAY},
    )

    assert submitted.status_code == 200, submitted.text
    body = submitted.json()
    assert body["status"] == "completed"
    assert body["day"] == TODAY
    assert body["completed_at"]
    assert body["connection_id"] == draft["connection_id"]
    assert len(body["answers"]) == 2

    again = client.patch(
        f"/observations/{draft['id']}",
        headers=_headers(companion_token),
        json={"answers": _answers(draft), "day": TODAY},
    )
    assert again.status_code == 409, again.text

    second = _create(client, companion_token, mother["id"])
    duplicate_day = client.patch(
        f"/observations/{second['id']}",
        headers=_headers(companion_token),
        json={"answers": _answers(second), "day": TODAY},
    )
    assert duplicate_day.status_code == 409, duplicate_day.text

    read = client.get(
        f"/observations/{draft['id']}", headers=_headers(companion_token)
    )
    assert read.status_code == 200, read.text
    assert read.json()["status"] == "completed"


def test_list_and_filters_are_author_scoped(client, register):
    _, mother, mother_token = register(role="mother")
    _, _, companion_token = register(role="companion")
    _connect(client, mother_token, companion_token)
    completed = _create(client, companion_token, mother["id"])
    draft = _create(client, companion_token, mother["id"])

    submitted = client.patch(
        f"/observations/{completed['id']}",
        headers=_headers(companion_token),
        json={"answers": _answers(completed), "day": TODAY},
    )
    assert submitted.status_code == 200, submitted.text

    listed = client.get("/observations", headers=_headers(companion_token))
    assert listed.status_code == 200, listed.text
    body = listed.json()
    assert body["total"] == 2
    assert {item["id"] for item in body["observations"]} == {
        completed["id"],
        draft["id"],
    }

    drafts = client.get(
        "/observations",
        headers=_headers(companion_token),
        params={"status": "draft"},
    )
    assert drafts.status_code == 200, drafts.text
    assert [item["id"] for item in drafts.json()["observations"]] == [
        draft["id"]
    ]

    completed_only = client.get(
        "/observations",
        headers=_headers(companion_token),
        params={"status": "completed", "day": TODAY},
    )
    assert completed_only.status_code == 200, completed_only.text
    assert [item["id"] for item in completed_only.json()["observations"]] == [
        completed["id"]
    ]

    by_connection = client.get(
        "/observations",
        headers=_headers(companion_token),
        params={"connection_id": completed["connection_id"]},
    )
    assert by_connection.status_code == 200, by_connection.text
    assert by_connection.json()["total"] == 2
