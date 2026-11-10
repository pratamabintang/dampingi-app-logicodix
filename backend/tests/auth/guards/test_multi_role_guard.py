import httpx
from fastapi import Depends, FastAPI
from fastapi.testclient import TestClient

from app.auth import guards, service
from app.auth.router import verified_session
from conftest import captured, supabase_json

PROFILE = captured("profiles-select-2026-11-10")

AUTH = {"Authorization": "Bearer offline-token"}


def _client_gated_by(gate, session):
    app = FastAPI()

    @app.get("/gated")
    def gated(caller: service.Session = Depends(gate)):
        return {"user_id": caller.user_id}

    app.dependency_overrides[verified_session] = lambda: session
    return TestClient(app)


def _profile_route(profile):
    return ("GET", "/rest/v1/profiles"), supabase_json(200, [profile])


def test_mother_passes_a_mother_or_companion_gate(mock_client, upstream):
    _, session = mock_client
    (method, suffix), response = _profile_route({**PROFILE, "role": "mother"})
    upstream({(method, suffix): response})

    client = _client_gated_by(
        guards.require_any_role("mother", "companion"), session
    )

    resp = client.get("/gated", headers=AUTH)

    assert resp.status_code == 200, resp.text
    assert resp.json()["user_id"] == session.user_id


def test_companion_passes_a_mother_or_companion_gate(mock_client, upstream):
    _, session = mock_client
    (method, suffix), response = _profile_route({**PROFILE, "role": "companion"})
    upstream({(method, suffix): response})

    client = _client_gated_by(
        guards.require_any_role("mother", "companion"), session
    )

    resp = client.get("/gated", headers=AUTH)

    assert resp.status_code == 200, resp.text


def test_professional_is_refused_and_the_message_names_the_roles(
    mock_client, upstream
):
    _, session = mock_client
    (method, suffix), response = _profile_route(
        {**PROFILE, "role": "professional"}
    )
    upstream({(method, suffix): response})

    client = _client_gated_by(
        guards.require_any_role("mother", "companion"), session
    )

    resp = client.get("/gated", headers=AUTH)

    assert resp.status_code == 403, resp.text
    detail = resp.json()["detail"]
    assert "mother" in detail and "companion" in detail


def test_a_missing_profile_is_refused(mock_client, upstream):
    _, session = mock_client
    upstream({("GET", "/rest/v1/profiles"): supabase_json(200, [])})

    client = _client_gated_by(
        guards.require_any_role("mother", "companion"), session
    )

    resp = client.get("/gated", headers=AUTH)

    assert resp.status_code == 403, resp.text


def test_the_single_role_gate_is_unchanged(mock_client, upstream):
    _, session = mock_client
    (method, suffix), response = _profile_route({**PROFILE, "role": "companion"})
    upstream({(method, suffix): response})

    client = _client_gated_by(guards.require_role("mother"), session)

    resp = client.get("/gated", headers=AUTH)

    assert resp.status_code == 403, resp.text


def test_the_timezone_reaches_the_caller(mock_client, upstream):
    _, session = mock_client

    def postgrest(request):
        asked = request.url.params["select"].split(",")
        return supabase_json(
            200, [{key: PROFILE[key] for key in asked if key in PROFILE}]
        )

    upstream({("GET", "/rest/v1/profiles"): postgrest})

    from app.auth import supabase as auth_supabase

    profile = auth_supabase.fetch_profile(session.user_id)

    assert profile["timezone"] == PROFILE["timezone"]


def test_a_profile_that_predates_the_timezone_column_still_works(
    mock_client, upstream
):
    _, session = mock_client
    old_shape = captured("profiles-select-2026-11-09")

    def postgrest(request):
        asked = request.url.params["select"].split(",")
        return supabase_json(
            200, [{key: old_shape[key] for key in asked if key in old_shape}]
        )

    upstream({("GET", "/rest/v1/profiles"): postgrest})

    client = _client_gated_by(
        guards.require_any_role("mother", "companion"), session
    )

    resp = client.get("/gated", headers=AUTH)

    assert resp.status_code == 200, resp.text
