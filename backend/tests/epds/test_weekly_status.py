from datetime import date, datetime, timezone

import pytest

from app.epds import weekly
from app.epds import assessment_service
from app.supabase import SupabaseError
from .test_assessment_router import assessment_client

pytestmark = pytest.mark.local


@pytest.fixture
def mother(monkeypatch):
    profile = {"timezone": "Asia/Jakarta"}
    monkeypatch.setattr(weekly.auth_supabase, "fetch_profile", lambda _: profile)
    monkeypatch.setattr(weekly.supabase, "registration_time", lambda _: "2026-11-07T12:00:00Z")
    monkeypatch.setattr(weekly.supabase, "list_assessments", lambda *args, **kwargs: ([], 0))
    class FrozenDatetime(datetime):
        @classmethod
        def now(cls, tz=None):
            return datetime(2026, 11, 14, 12, tzinfo=timezone.utc)
    monkeypatch.setattr(weekly, "datetime", FrozenDatetime)
    return profile


def test_first_assessment_before_seven_days_is_closed(monkeypatch, mother):
    monkeypatch.setattr(weekly.supabase, "registration_time", lambda _: "2026-11-08T12:00:00Z")
    result = weekly.weekly_status("mother-A")
    assert result["can_submit"] is False
    assert result["filled"] is False
    assert result["next_available_date"] == "2026-11-15"


def test_first_assessment_at_seven_days_is_open_even_on_saturday(mother):
    assert weekly.weekly_status("mother-A")["can_submit"] is True


def test_repeat_is_closed_until_seven_days_after_last_submission(monkeypatch, mother):
    monkeypatch.setattr(weekly.supabase, "list_assessments", lambda *args, **kwargs: ([
        {"id": "saved", "created_at": "2026-11-10T12:00:00Z"}], 1))
    result = weekly.weekly_status("mother-A")
    assert result["can_submit"] is False
    assert result["filled"] is True
    assert result["next_available_date"] == "2026-11-17"


def test_repeat_at_exactly_seven_days_is_open(monkeypatch, mother):
    monkeypatch.setattr(weekly.supabase, "list_assessments", lambda *args, **kwargs: ([
        {"id": "saved", "created_at": "2026-11-07T12:00:00Z"}], 1))
    assert weekly.weekly_status("mother-A")["can_submit"] is True


def test_week_uses_mother_timezone_and_owner(monkeypatch, mother):
    calls = []
    monkeypatch.setattr(weekly.supabase, "latest_between", lambda *args: calls.append(args))
    weekly.assessment_for_week("mother-A", date(2026, 11, 9), mother)
    assert calls == [("mother-A", "2026-11-08T17:00:00+00:00", "2026-11-15T17:00:00+00:00")]


def test_week_over_year_boundary():
    assert weekly.week_start(date(2027, 1, 3)) == date(2026, 12, 28)


def test_submit_duplicate_is_409(assessment_client, monkeypatch):
    def conflict(*args):
        raise SupabaseError(409, "duplicate", "23505")
    monkeypatch.setattr(assessment_service, "submit_assessment", conflict)
    response = assessment_client.post("/v1/me/epds-assessments", json={
        "answers": [{"item_id": f"Q{i}", "option_index": 0} for i in range(1, 11)]
    })
    assert response.status_code == 409


def test_submit_before_first_eligibility_is_403(assessment_client, monkeypatch):
    def closed(*args):
        raise SupabaseError(400, "closed", "P0002")
    monkeypatch.setattr(assessment_service, "submit_assessment", closed)
    response = assessment_client.post("/v1/me/epds-assessments", json={
        "answers": [{"item_id": f"Q{i}", "option_index": 0} for i in range(1, 11)]
    })
    assert response.status_code == 403
