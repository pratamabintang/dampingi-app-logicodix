import pytest

from app import config, security


def _client(host: str):
    from fastapi.testclient import TestClient

    import app.main as main

    return TestClient(main.app, base_url=f"http://{host}")


def _as_hosts(monkeypatch, value: str):
    monkeypatch.setenv("TRUSTED_HOSTS", value)
    config.reset_settings()


def test_an_unlisted_host_is_refused(offline_env):
    resp = _client("evil.example.com").get("/health")

    assert resp.status_code == 400, resp.text
    assert "invalid host" in resp.json()["detail"].lower()


def test_a_listed_host_passes(offline_env):
    resp = _client("testserver").get("/health")

    assert resp.status_code == 200, resp.text


def test_the_default_allowlist_admits_the_platform_domain(offline_env):
    assert _client("dampingi.onrender.com").get("/health").status_code == 200
    assert _client("localhost").get("/health").status_code == 200
    assert _client("onrender.com.evil.example.com").get("/health").status_code == 400


def test_the_allowlist_comes_from_configuration(offline_env, monkeypatch):
    _as_hosts(monkeypatch, "dampingi.example.com, www.dampingi.example.com")

    assert _client("dampingi.example.com").get("/health").status_code == 200
    assert _client("www.dampingi.example.com").get("/health").status_code == 200
    assert _client("testserver").get("/health").status_code == 400


def test_the_host_check_tolerates_a_port(offline_env):
    resp = _client("localhost:8000").get("/health")

    assert resp.status_code == 200, resp.text


@pytest.mark.parametrize("path", ["/health", "/nope-not-a-route"])
def test_the_header_set_is_present_on_success_and_on_refusal(offline_env, path):
    resp = _client("testserver").get(path)

    assert resp.status_code in (200, 404)
    for name, value in security.SECURITY_HEADERS.items():
        assert resp.headers.get(name) == value, f"missing {name} on {path}"


def test_the_header_set_is_present_on_the_host_refusal(offline_env):
    resp = _client("evil.example.com").get("/health")

    assert resp.status_code == 400
    for name, value in security.SECURITY_HEADERS.items():
        assert resp.headers.get(name) == value, f"missing {name} on the refusal"


def test_an_upstream_failure_carries_the_header_set(offline_env, mock_client, upstream):
    import httpx

    from app import errors
    from conftest import journals_profile

    client, _ = mock_client

    def unreachable(_request):
        raise httpx.ConnectError("connection refused")

    upstream(
        {
            ("GET", "/rest/v1/profiles"): httpx.Response(
                200, json=[journals_profile()]
            ),
            ("GET", "/rest/v1/journals"): unreachable,
        }
    )

    resp = client.get("/journals", headers={"Authorization": "Bearer offline-token"})

    assert resp.status_code == 503, resp.text
    for name, value in security.SECURITY_HEADERS.items():
        assert resp.headers.get(name) == value, f"missing {name} on the 503"


def test_no_hsts_and_no_cors_are_added(offline_env):
    resp = _client("testserver").get("/health")

    assert "strict-transport-security" not in resp.headers
    assert "access-control-allow-origin" not in resp.headers
