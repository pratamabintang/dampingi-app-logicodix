import pytest

from app import config

DOC_PATHS = ("/docs", "/redoc", "/openapi.json")


def _client():
    from fastapi.testclient import TestClient

    import app.main as main

    return TestClient(main.app)


def _running_as(monkeypatch, app_env: str):
    monkeypatch.setenv("APP_ENV", app_env)
    config.reset_settings()


@pytest.mark.parametrize("path", DOC_PATHS)
def test_docs_are_absent_outside_development(offline_env, monkeypatch, path):
    _running_as(monkeypatch, "production")

    resp = _client().get(path)

    assert resp.status_code == 404, resp.text


@pytest.mark.parametrize("path", DOC_PATHS)
def test_docs_are_present_in_development(offline_env, monkeypatch, path):
    _running_as(monkeypatch, "development")

    resp = _client().get(path)

    assert resp.status_code == 200, resp.text


def test_health_does_not_advertise_the_environment(offline_env, monkeypatch):
    _running_as(monkeypatch, "production")

    body = _client().get("/health").json()

    assert body["status"] == "healthy"
    assert "env" not in body


def test_the_gate_follows_the_single_environment_setting(offline_env, monkeypatch):
    _running_as(monkeypatch, "production")
    assert config.get_settings().is_development is False
    assert _client().get("/docs").status_code == 404

    _running_as(monkeypatch, "development")
    assert config.get_settings().is_development is True
    assert _client().get("/docs").status_code == 200
