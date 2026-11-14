import pytest


@pytest.fixture(autouse=True)
def no_epds_unless_supplied(monkeypatch):
    # Existing summary fixtures predate EPDS as an additional data source.
    from app.summaries import service
    monkeypatch.setattr(service, "assessment_for_week", lambda *args: None)
