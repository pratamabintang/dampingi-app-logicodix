
import app.journals.router as journals_router

from conftest import journals_profile


AUTH = {"Authorization": "Bearer offline-token"}
PROFILE = journals_profile()


def test_mothers_journal_schedules_daily_summary_refresh(
    mock_client,
    journals_table,
    monkeypatch,
):
    client, session = mock_client
    journals_table({**PROFILE, "role": "mother"})

    refresh = []
    monkeypatch.setattr(
        journals_router,
        "_refresh_daily_summary_background",
        lambda user_id, summary_date: refresh.append(
            (user_id, summary_date)
        ),
    )

    response = client.post(
        "/journals",
        headers=AUTH,
        json={
            "title": "A good day",
            "content": "We walked to the park.",
        },
    )

    assert response.status_code == 201, response.text
    assert refresh == [
        (session.user_id, response.json()["created_at"])
    ]


def test_companion_journal_does_not_refresh_mothers_summary(
    mock_client,
    journals_table,
    real_gate,
    monkeypatch,
):
    client, session = mock_client
    journals_table({**PROFILE, "role": "companion"})

    refresh = []
    monkeypatch.setattr(
        journals_router,
        "_refresh_daily_summary_background",
        lambda user_id, summary_date: refresh.append(
            (user_id, summary_date)
        ),
    )

    response = client.post(
        "/journals",
        headers=AUTH,
        json={
            "title": "Supporting her",
            "content": "A quiet day.",
        },
    )

    assert response.status_code == 201, response.text
    assert refresh == []
