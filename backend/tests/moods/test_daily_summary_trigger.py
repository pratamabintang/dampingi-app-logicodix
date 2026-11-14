
import pytest
from unittest.mock import Mock

import app.moods.router as moods_router

from conftest import captured, mood_row


PROFILE = {
    **captured("profiles-select-2026-11-10"),
    "role": "mother",
}

MOOD_ID = "00000000-0000-4000-8000-0000000000b2"
MOOD_DATE = "2026-10-30"


def _mood(**overrides):
    return {
        **mood_row(PROFILE["user_id"], MOOD_DATE, mood=4),
        "id": MOOD_ID,
        **overrides,
    }


def test_create_mood_schedules_daily_summary_refresh(
    mock_client,
    moods_table,
    monkeypatch,
):
    client, session = mock_client
    moods_table(PROFILE)

    refresh = Mock()
    monkeypatch.setattr(
        moods_router,
        "_refresh_daily_summary_background",
        refresh,
    )

    response = client.post(
        "/moods",
        headers={"Authorization": f"Bearer {session.token}"},
        json={
            "created_at": MOOD_DATE,
            "mood": 4,
        },
    )

    assert response.status_code == 201, response.text
    refresh.assert_called_once_with(
        session.user_id,
        MOOD_DATE,
    )


def test_update_mood_schedules_daily_summary_refresh(
    mock_client,
    moods_table,
    monkeypatch,
):
    client, session = mock_client
    moods_table(PROFILE, moods=[_mood()])

    refresh = Mock()
    monkeypatch.setattr(
        moods_router,
        "_refresh_daily_summary_background",
        refresh,
    )

    response = client.patch(
        f"/moods/{MOOD_ID}",
        headers={"Authorization": f"Bearer {session.token}"},
        json={"mood": 5},
    )

    assert response.status_code == 200, response.text
    refresh.assert_called_once_with(
        session.user_id,
        MOOD_DATE,
    )


def test_delete_mood_schedules_daily_summary_refresh(
    mock_client,
    moods_table,
    monkeypatch,
):
    client, session = mock_client
    moods_table(PROFILE, moods=[_mood()])

    refresh = Mock()
    monkeypatch.setattr(
        moods_router,
        "_refresh_daily_summary_background",
        refresh,
    )

    response = client.delete(
        f"/moods/{MOOD_ID}",
        headers={"Authorization": f"Bearer {session.token}"},
    )

    assert response.status_code == 204, response.text
    refresh.assert_called_once_with(
        session.user_id,
        MOOD_DATE,
    )


def test_deleting_nonexistent_mood_does_not_schedule_refresh(
    mock_client,
    moods_table,
    monkeypatch,
):
    client, session = mock_client
    moods_table(PROFILE)

    refresh = Mock()
    monkeypatch.setattr(
        moods_router,
        "_refresh_daily_summary_background",
        refresh,
    )

    response = client.delete(
        "/moods/00000000-0000-4000-8000-00000000dead",
        headers={"Authorization": f"Bearer {session.token}"},
    )

    assert response.status_code == 204, response.text
    refresh.assert_not_called()
