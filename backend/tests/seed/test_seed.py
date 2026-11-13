import json
import uuid

import httpx

from app import seed

CHILD_TABLES = (
    "connections",
    "invite_codes",
    "moods",
    "journals",
    "observations",
    "professional_notes",
)


def _signup_id(email: str) -> str:
    return str(uuid.uuid5(uuid.NAMESPACE_DNS, email))


def _json(request) -> dict:
    return json.loads(request.content)


def _routes(existing_users=None):

    def signup(request):
        body = _json(request)
        return httpx.Response(200, json={"user": {"id": _signup_id(body["email"])}})

    routes = {
        ("GET", "/auth/v1/admin/users"): httpx.Response(
            200, json={"users": existing_users or [], "next_page": None}
        ),
        ("POST", "/auth/v1/signup"): signup,
        ("PUT", ""): httpx.Response(200, json={}),
        ("PATCH", "/rest/v1/profiles"): httpx.Response(204),
    }
    for table in CHILD_TABLES:
        routes[("POST", f"/rest/v1/{table}")] = httpx.Response(201, json=[])

    routes[("DELETE", "/rest/v1/moods")] = httpx.Response(204)
    routes[("DELETE", "/rest/v1/journals")] = httpx.Response(204)
    routes[("DELETE", "/rest/v1/observations")] = httpx.Response(204)
    return routes


def _posts(recorded, table):
    return [
        request
        for request in recorded.requests
        if request.method == "POST" and request.url.path.endswith(f"/rest/v1/{table}")
    ]


def test_seed_creates_profiles_through_signup_and_upserts_every_table(
    offline_env, upstream, capsys
):
    recorded = upstream(_routes())

    exit_code = seed.main()

    assert exit_code == 0
    out = capsys.readouterr().out
    assert "Created 6 new profile(s)." in out

    signups = [
        request
        for request in recorded.requests
        if request.url.path.endswith("/auth/v1/signup")
    ]
    assert len(signups) == 6
    assert {_json(request)["email"] for request in signups} == {
        profile["email"] for profile in seed.SEED_PROFILES
    }

    assert _posts(recorded, "profiles") == []

    for table in CHILD_TABLES:
        posts = _posts(recorded, table)
        assert len(posts) == 1, f"{table} not upserted exactly once"
        request = posts[0]
        assert request.url.params["on_conflict"] == "id"
        assert "merge-duplicates" in request.headers["prefer"]
        assert _json(request), f"{table} posted no rows"


def test_seed_resolves_profile_placeholders_and_keeps_foreign_key_order(
    offline_env, upstream
):
    recorded = upstream(_routes())

    seed.main()

    mother_id = _signup_id("seed.mother@gmail.com")
    companion_id = _signup_id("seed.companion@gmail.com")

    connections = _json(_posts(recorded, "connections")[0])
    by_id = {row["id"]: row for row in connections}
    active = by_id[seed.seed_id("connection.mother1.companion1")]
    assert active["mother_id"] == mother_id
    assert active["counterpart_id"] == companion_id

    known_ids = {profile["email"] for profile in seed.SEED_PROFILES}
    for row in connections:
        assert row["mother_id"] not in known_ids
        assert row["counterpart_id"] not in known_ids

    codes = _json(_posts(recorded, "invite_codes")[0])
    assert {row["code"] for row in codes} == {
        "SEED-CMPN",
        "SEED-PRFN",
        "SEED-MTHR",
        "SEED-EXPD",
        "SEED-RVKD",
        "SEED-RDMD",
    }
    assert all(row["issuer_id"] == mother_id for row in codes)

    order = [
        request.url.path.rsplit("/", 1)[-1]
        for request in recorded.requests
        if request.method == "POST" and "/rest/v1/" in request.url.path
    ]
    assert order.index("connections") < order.index("observations")
    assert order.index("connections") < order.index("professional_notes")


def test_seed_is_idempotent_when_profiles_already_exist(offline_env, upstream, capsys):
    existing = [
        {"id": _signup_id(profile["email"]), "email": profile["email"]}
        for profile in seed.SEED_PROFILES
    ]
    recorded = upstream(_routes(existing_users=existing))

    exit_code = seed.main()

    assert exit_code == 0
    assert "Created 0 new profile(s)." in capsys.readouterr().out
    assert not [
        request
        for request in recorded.requests
        if request.url.path.endswith("/auth/v1/signup")
    ]
    for table in CHILD_TABLES:
        assert _posts(recorded, table), f"{table} skipped on re-run"


def test_seed_ids_are_deterministic_across_calls():
    assert seed.seed_id("connection.mother1.companion1") == seed.seed_id(
        "connection.mother1.companion1"
    )
    assert seed.seed_id("a") != seed.seed_id("b")
