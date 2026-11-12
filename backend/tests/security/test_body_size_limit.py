from app import security


def _client(host: str = "testserver"):
    from fastapi.testclient import TestClient

    import app.main as main

    return TestClient(main.app, base_url=f"http://{host}")


def test_an_oversized_declared_body_is_refused(offline_env, monkeypatch):
    monkeypatch.setattr(security, "MAX_BODY_BYTES", 16)

    resp = _client().post("/auth/login", json={"email": "a" * 200})

    assert resp.status_code == 413, resp.text
    assert resp.json()["detail"] == "Request body too large"


def test_the_refusal_happens_before_routing(offline_env, monkeypatch):
    monkeypatch.setattr(security, "MAX_BODY_BYTES", 16)

    resp = _client().post("/no-such-route", json={"x": "y" * 200})

    assert resp.status_code == 413, resp.text


def test_the_refusal_carries_the_security_headers(offline_env, monkeypatch):
    monkeypatch.setattr(security, "MAX_BODY_BYTES", 16)

    resp = _client().post("/auth/login", json={"email": "a" * 200})

    assert resp.status_code == 413
    for name, value in security.SECURITY_HEADERS.items():
        assert resp.headers.get(name) == value, f"missing {name} on the 413"


def test_a_legitimate_body_is_not_refused(offline_env, mock_client, journals_table):
    from conftest import journals_profile

    client, _ = mock_client
    journals_table(journals_profile())

    resp = client.post(
        "/journals",
        headers={"Authorization": "Bearer offline-token"},
        json={"title": "A day", "content": "x" * 10_000},
    )

    assert resp.status_code == 201, resp.text


def test_the_cap_is_larger_than_the_largest_legitimate_field():
    from app.journals.schemas import CONTENT_MAX
    from app.observations.schemas import OPTION_LABEL_MAX, OPTION_MAX, PROMPT_MAX, QUESTION_MAX

    assert security.MAX_BODY_BYTES > CONTENT_MAX
    worst_case = QUESTION_MAX * (PROMPT_MAX + OPTION_MAX * OPTION_LABEL_MAX) * 6
    assert security.MAX_BODY_BYTES > worst_case
