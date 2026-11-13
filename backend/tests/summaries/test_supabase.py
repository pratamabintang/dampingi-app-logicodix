import pytest

from app.summaries import supabase


class FakeResponse:
    status_code = 200
    headers = {"content-range": "0-0/1"}

    def __init__(self, rows):
        self._rows = rows

    def json(self):
        return self._rows


@pytest.fixture
def mock_http(monkeypatch):
    calls = []

    def fake_request(func, *args, **kwargs):
        calls.append((func.__name__, args, kwargs))
        return FakeResponse([{"id": "summary-1"}])

    class FakeClient:
        def post(self, *args, **kwargs):
            pass

        def get(self, *args, **kwargs):
            pass

    monkeypatch.setattr(supabase, "_request", fake_request)
    monkeypatch.setattr(
        supabase,
        "_base_url",
        lambda: "https://test.supabase.co",
    )
    monkeypatch.setattr(supabase, "_client", lambda: FakeClient())
    monkeypatch.setattr(
        supabase,
        "supabase_service_http",
        lambda: {
            "apikey": "test",
            "Authorization": "Bearer test",
        },
    )

    return calls


def test_save_summary(mock_http):
    payload = {
        "mother_id": "mother-1",
        "period_start": "2026-11-09",
        "period_end": "2026-11-15",
        "audience": "mother",
        "status": "completed",
        "overview": "Summary",
        "limitations": [],
        "source_refs": [],
        "prompt_version": "weekly-summary-v2",
    }

    result = supabase.save_summary(payload)

    assert result["id"] == "summary-1"
    assert len(mock_http) == 1

    method, args, kwargs = mock_http[0]
    assert method == "post"
    assert args[0] == (
        "https://test.supabase.co/rest/v1/weekly_summaries"
    )
    assert kwargs["params"]["on_conflict"] == (
        "mother_id,period_start,audience"
    )
    assert kwargs["json"] == payload


def test_get_summary(mock_http):
    result = supabase.get_summary(
        mother_id="mother-1",
        period_start="2026-11-09",
        audience="mother",
    )

    assert result["id"] == "summary-1"
    assert len(mock_http) == 1

    method, args, kwargs = mock_http[0]
    assert method == "get"
    assert args[0] == (
        "https://test.supabase.co/rest/v1/weekly_summaries"
    )
    assert ("mother_id", "eq.mother-1") in kwargs["params"]
    assert ("period_start", "eq.2026-11-09") in kwargs["params"]
    assert ("audience", "eq.mother") in kwargs["params"]


def test_save_summary_without_returned_row(mock_http, monkeypatch):
    monkeypatch.setattr(
        supabase,
        "_request",
        lambda *args, **kwargs: FakeResponse([]),
    )

    with pytest.raises(supabase.SupabaseError):
        supabase.save_summary({"mother_id": "mother-1"})


def test_get_summary_not_found(mock_http, monkeypatch):
    monkeypatch.setattr(
        supabase,
        "_request",
        lambda *args, **kwargs: FakeResponse([]),
    )

    result = supabase.get_summary(
        mother_id="mother-1",
        period_start="2026-11-09",
        audience="mother",
    )

    assert result is None