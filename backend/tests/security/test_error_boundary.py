import logging
import uuid

import httpx

from app import errors
from conftest import journals_profile, supabase_json

AUTH = {"Authorization": "Bearer offline-token"}
PROFILE = journals_profile()

UNAVAILABLE = errors._UNAVAILABLE
UNREACHABLE = errors._UNREACHABLE

SENSITIVE = "we walked to the park and mother cried"
UPSTREAM_LEAK = (
    'insert or update on table "journals" violates foreign key constraint '
    '"journals_user_id_fkey": column "user_id" references "profiles"'
)


def test_an_upstream_failure_body_carries_no_upstream_text(
    mock_client, journals_table, caplog
):

    def leaky_upstream():
        return httpx.Response(
            500,
            json={"code": "XX000", "details": UPSTREAM_LEAK, "message": UPSTREAM_LEAK},
        )

    client, _ = mock_client
    journals_table(PROFILE, fail_insert=leaky_upstream)

    with caplog.at_level(logging.WARNING, logger="dampingi.upstream"):
        resp = client.post(
            "/journals",
            headers=AUTH,
            json={"title": "A day", "content": SENSITIVE},
        )

    assert resp.status_code == 503, resp.text
    assert resp.json()["detail"] == UNAVAILABLE
    assert "journals" not in resp.text
    assert "user_id" not in resp.text
    assert "constraint" not in resp.text
    assert SENSITIVE not in resp.text


def test_the_failure_is_logged_with_its_location_and_status(
    mock_client, journals_table, caplog
):

    def leaky_upstream():
        return httpx.Response(
            500, json={"code": "XX000", "message": UPSTREAM_LEAK}
        )

    client, _ = mock_client
    journals_table(PROFILE, fail_insert=leaky_upstream)

    with caplog.at_level(logging.WARNING, logger="dampingi.upstream"):
        client.post(
            "/journals",
            headers=AUTH,
            json={"title": "A day", "content": SENSITIVE},
        )

    records = [r for r in caplog.records if r.name == "dampingi.upstream"]
    assert records, "the upstream failure was not logged"
    message = records[-1].getMessage()
    assert "status=500" in message
    assert "path=/journals" in message
    assert "method=POST" in message
    assert SENSITIVE not in caplog.text
    assert UPSTREAM_LEAK not in caplog.text


def test_a_transport_failure_is_503_and_caller_safe(mock_client, journals_table):

    def unreachable():
        raise httpx.ConnectError("connection refused to internal host db:5432")

    client, _ = mock_client
    journals_table(PROFILE, fail_insert=unreachable)

    resp = client.post(
        "/journals", headers=AUTH, json={"title": "A day", "content": "Hello."}
    )

    assert resp.status_code == 503, resp.text
    assert resp.json()["detail"] == UNREACHABLE
    assert "db:5432" not in resp.text


def test_the_duplicate_day_conflict_keeps_its_message(mock_client, journals_table):
    client, _ = mock_client
    journals_table(PROFILE)

    first = client.post(
        "/journals", headers=AUTH, json={"title": "One", "content": "A."}
    )
    assert first.status_code == 201, first.text
    day = first.json()["created_at"]

    second = client.post(
        "/journals", headers=AUTH, json={"title": "Two", "content": "B."}
    )

    assert second.status_code == 409, second.text
    assert second.json()["detail"] == f"A journal already exists for {day}"


def test_a_missing_journal_is_still_a_404_with_its_message(mock_client, journals_table):
    client, _ = mock_client
    journals_table(PROFILE)

    resp = client.get(f"/journals/{uuid.uuid4()}", headers=AUTH)

    assert resp.status_code == 404, resp.text
    assert resp.json()["detail"] == "Journal not found"


def test_a_deleted_account_refusal_is_still_a_403(mock_client, upstream):
    client, _ = mock_client
    upstream(
        {
            ("GET", "/rest/v1/profiles"): supabase_json(
                200, [{**PROFILE, "deleted_at": "2026-11-12T00:00:00+00:00"}]
            )
        }
    )

    resp = client.get("/me", headers=AUTH)

    assert resp.status_code == 403, resp.text
    assert resp.json()["detail"] == "This account has been deleted"


def test_an_unexpected_failure_is_a_plain_500(mock_client, monkeypatch):
    from fastapi.testclient import TestClient

    import app.main as main

    client, _ = mock_client

    def boom(*_args, **_kwargs):
        raise RuntimeError("internal detail with secret-ish text")

    monkeypatch.setattr("app.journals.service.list_journals", boom)
    resp = TestClient(main.app, raise_server_exceptions=False).get(
        "/journals", headers=AUTH
    )

    assert resp.status_code == 500, resp.text
    assert resp.json()["detail"] == "Internal server error"
    assert "secret-ish" not in resp.text
