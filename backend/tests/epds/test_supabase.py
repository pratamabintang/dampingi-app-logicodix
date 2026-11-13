
from types import SimpleNamespace

import pytest

from app.epds import supabase


MOTHER_ID = "11111111-1111-4111-8111-111111111111"
ASSESSMENT_ID = "22222222-2222-4222-8222-222222222222"
ALERT_ID = "33333333-3333-4333-8333-333333333333"


@pytest.fixture
def mock_http(monkeypatch):
    calls = []

    class FakeClient:
        def post(self, *args, **kwargs):
            pass

        def get(self, *args, **kwargs):
            pass

        def patch(self, *args, **kwargs):
            pass

    def fake_request(method, *args, **kwargs):
        calls.append((method.__name__, args, kwargs))
        return SimpleNamespace(
            status_code=200,
            headers={"content-range": "0-0/1"},
            json=lambda: [{"id": "test-id"}],
        )

    monkeypatch.setattr(supabase, "_client", lambda: FakeClient())
    monkeypatch.setattr(supabase, "_base_url", lambda: "https://test.supabase.co")
    monkeypatch.setattr(supabase, "_request", fake_request)
    monkeypatch.setattr(supabase, "supabase_service_http", lambda: {})

    return calls


def test_create_assessment(mock_http):
    result = supabase.create_assessment({"mother_id": MOTHER_ID})

    assert result["id"] == "test-id"
    assert mock_http[0][0] == "post"
    assert "epds_assessments" in mock_http[0][1][0]


def test_list_assessments(mock_http):
    items, total = supabase.list_assessments(MOTHER_ID)

    assert items == [{"id": "test-id"}]
    assert total == 1
    assert len(mock_http) == 2
    assert mock_http[0][0] == "get"
    assert mock_http[1][0] == "get"


def test_create_alert(mock_http):
    result = supabase.create_alert({"mother_id": MOTHER_ID})

    assert result["id"] == "test-id"
    assert mock_http[0][0] == "post"
    assert "alerts" in mock_http[0][1][0]


def test_list_alerts(mock_http):
    items, total = supabase.list_alerts(MOTHER_ID)

    assert items == [{"id": "test-id"}]
    assert total == 1
    assert len(mock_http) == 2


def test_mark_alert_read(mock_http):
    result = supabase.mark_alert_read(
        MOTHER_ID,
        ALERT_ID,
        "2026-11-14T00:00:00+00:00",
    )

    assert result["id"] == "test-id"
    assert mock_http[0][0] == "patch"

    params = mock_http[0][2]["params"]
    assert ("id", f"eq.{ALERT_ID}") in params
    assert ("mother_id", f"eq.{MOTHER_ID}") in params
