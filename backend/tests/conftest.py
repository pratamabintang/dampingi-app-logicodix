import importlib
import os
import sys
import uuid
from pathlib import Path
from typing import Iterator

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

TESTS_DIR = Path(__file__).resolve().parent
TEST_ENV_FILE = TESTS_DIR / ".env"

REQUIRED_ENV = ("SUPABASE_URL", "SUPABASE_PUBLISHABLE_KEY", "SUPABASE_SECRET_KEY")
SKIP_REASON = (
    f"live Supabase credentials not configured: create {TESTS_DIR / '.env'} "
    f"from {TESTS_DIR / '.env.example'} (see docs/supabase-setup.md); "
    "missing keys are auto-detected and the whole module skips"
)


def _load_env_file(path: Path) -> dict:
    values = {}
    if not path.exists():
        return values
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        values[key.strip()] = value.strip().strip("'\"")
    return values


def _missing_keys() -> list:
    values = {}
    for key, value in _load_env_file(TEST_ENV_FILE).items():
        if value:
            values[key] = value
    for key, value in values.items():
        os.environ[key] = value
    return [key for key in REQUIRED_ENV if not os.environ.get(key)]


_dummy_client: object = None

_live_ran = False


@pytest.fixture(scope="session")
def client(supabase_env):
    global _dummy_client, _live_ran
    from fastapi.testclient import TestClient

    main = importlib.import_module("app.main")
    _dummy_client = TestClient(main.app)
    _live_ran = True
    return _dummy_client


@pytest.fixture(scope="session")
def supabase_env():
    missing = _missing_keys()
    if missing:
        pytest.skip(f"{SKIP_REASON} [{', '.join(missing)}]")
    base_url = os.environ["SUPABASE_URL"].rstrip("/")
    import httpx

    resp = httpx.get(f"{base_url}/auth/v1/.well-known/jwks.json", timeout=10)
    if resp.status_code >= 400:
        pytest.skip(f"JWKS discovery endpoint not reachable: {resp.status_code}")
    return base_url


@pytest.fixture
def unique_email():
    def _generate():
        return f"pytest.{uuid.uuid4().hex[:12]}@gmail.com"

    yield _generate


@pytest.fixture
def tracked_users() -> Iterator[list]:
    ids: list = []
    yield ids
    from app.auth import supabase

    for user_id in ids:
        supabase.delete_user(user_id)


def pytest_sessionfinish(session, exitstatus):
    if not _live_ran:
        return
    missing = _missing_keys()
    if missing:
        return
    try:
        from app import admin
        from app.auth import supabase
    except Exception:
        return
    try:
        leaked = admin.find_leaked_users()
        if leaked:
            admin.delete_users(leaked, log=lambda _msg: None)
    except supabase.SupabaseError:
        pass


@pytest.fixture
def register(client, unique_email, tracked_users):

    def _register(
        name: str = "Test User",
        password: str = "Sup3rSecure!",
        role: str = "mother",
    ):
        email = unique_email()
        resp = client.post(
            "/auth/register",
            json={"name": name, "email": email, "password": password, "role": role},
        )
        if resp.status_code == 400 and "rate limit" in resp.text.lower():
            pytest.fail(
                "Supabase rate limit hit (per-IP Auth throttle). The suite "
                "makes ~110 auth calls per run, so back-to-back runs trip it. "
                "Wait ~5 minutes and rerun (see docs/supabase-setup.md, "
                "Troubleshooting)."
            )
        assert resp.status_code == 201, resp.text
        body = resp.json()
        tracked_users.append(body["user"]["id"])
        return email, body["user"], body["access_token"]

    return _register




def supabase_error(status: int, message: str, error_code: str):
    import httpx

    return httpx.Response(
        status, json={"code": status, "error_code": error_code, "msg": message}
    )


def supabase_json(status: int, body):
    import httpx

    return httpx.Response(status, json=body)


FIXTURES_DIR = TESTS_DIR / "fixtures"


def captured(name: str):
    import json

    path = FIXTURES_DIR / f"{name}.json"
    if not path.exists():
        raise FileNotFoundError(
            f"no captured fixture {path.name}; see tests/fixtures/README.md"
        )
    return json.loads(path.read_text(encoding="utf-8"))["payload"]


def captured_empty(name: str):
    import httpx

    payload = captured(name)
    return httpx.Response(payload["status"], content=b"")


class _Recorded:

    def __init__(self, routes: dict):
        self.routes = routes
        self.requests: list = []

    def __call__(self, request):
        import httpx

        self.requests.append(request)
        for (method, suffix), handler in self.routes.items():
            if request.method == method and request.url.path.endswith(suffix):
                return handler(request) if callable(handler) else handler
        return httpx.Response(
            599,
            json={
                "msg": f"no canned response for {request.method} {request.url.path}",
                "error_code": "unrouted_in_test",
            },
        )


@pytest.fixture
def upstream():
    import httpx

    from app import supabase

    created = []

    def _use(routes: dict) -> _Recorded:
        recorded = _Recorded(routes)
        client = httpx.Client(transport=httpx.MockTransport(recorded))
        created.append(client)
        supabase.use_client(client)
        return recorded

    yield _use

    supabase.use_client(None)
    for client in created:
        client.close()


@pytest.fixture
def offline_env(monkeypatch):
    from app import config

    monkeypatch.setenv("SUPABASE_URL", "https://offline.supabase.test")
    monkeypatch.setenv("SUPABASE_PUBLISHABLE_KEY", "offline-publishable")
    monkeypatch.setenv("SUPABASE_SECRET_KEY", "offline-secret")
    config.reset_settings()
    yield
    config.reset_settings()


@pytest.fixture
def real_gate(mock_client):
    import app.main as main
    from app.journals import router as journals_router

    saved = main.app.dependency_overrides.pop(journals_router.mother_or_companion, None)
    yield
    if saved is not None:
        main.app.dependency_overrides[journals_router.mother_or_companion] = saved


@pytest.fixture
def as_author():
    def _as(user_id: str) -> None:
        import app.main as main
        from app.auth import service
        from app.auth.router import verified_session

        main.app.dependency_overrides[verified_session] = lambda: service.Session(
            user_id=user_id, email="offline@gmail.com", token="offline-token"
        )

    return _as

def journals_profile(**overrides):
    return {**captured("profiles-select-2026-11-10"), "role": "mother", **overrides}


OTHER_AUTHOR = "00000000-0000-4000-8000-0000000000f1"


def journal_row(user_id, day, title="A day", content="As written."):
    return {
        **captured("journals-select-2026-11-10")[0],
        "user_id": user_id,
        "created_at": day,
        "title": title,
        "content": content,
    }


def _canned_table(upstream, *, table, profile, rows, row_for=None, max_rows=1000):
    import json

    import httpx

    stored = list(rows)
    fill = row_for or (lambda body: body)

    def _day_matches(row, wanted: str) -> bool:
        if wanted.startswith("gte."):
            return row["created_at"] >= wanted.removeprefix("gte.")
        if wanted.startswith("lte."):
            return row["created_at"] <= wanted.removeprefix("lte.")
        return row["created_at"] == wanted.removeprefix("eq.")

    def _match(request):
        wanted_user = request.url.params.get("user_id")
        wanted_days = request.url.params.get_list("created_at")
        return [
            row
            for row in stored
            if (
                wanted_user is None
                or row["user_id"] == wanted_user.removeprefix("eq.")
            )
            and all(_day_matches(row, wanted) for wanted in wanted_days)
        ]

    def _select(request, matched):
        asked = request.url.params["select"].split(",")
        return [{k: row[k] for k in asked if k in row} for row in matched]

    def profile_get(request):
        asked = request.url.params["select"].split(",")
        return supabase_json(200, [{k: profile[k] for k in asked if k in profile}])

    def table_get(request):
        hits = _match(request)
        order = request.url.params.get("order")
        if order == "created_at.desc":
            hits = sorted(hits, key=lambda r: r["created_at"], reverse=True)
        elif order == "created_at.asc":
            hits = sorted(hits, key=lambda r: r["created_at"])
        offset = int(request.url.params.get("offset", 0))
        limit = int(request.url.params.get("limit", len(hits) or 1))
        return supabase_json(
            200, _select(request, hits[offset : offset + min(limit, max_rows)])
        )

    def table_post(request):
        body = json.loads(request.content)
        clash = [
            row
            for row in stored
            if row["user_id"] == body["user_id"]
            and row["created_at"] == body["created_at"]
        ]
        if clash:
            return httpx.Response(
                409,
                json={
                    "code": "23505",
                    "details": "Key (user_id, created_at) already exists.",
                    "message": "duplicate key value violates unique constraint",
                },
            )
        row = fill(body)
        stored.append(row)
        return supabase_json(201, [row])

    def table_patch(request):
        hits = _match(request)
        body = json.loads(request.content)
        for row in hits:
            row.update(body)
        return supabase_json(200, _select(request, hits))

    def table_delete(request):
        hits = _match(request)
        for row in hits:
            stored.remove(row)
        if "return=representation" in (request.headers.get("prefer") or ""):
            return supabase_json(200, _select(request, hits))
        return httpx.Response(204, content=b"")

    return upstream(
        {
            ("GET", "/rest/v1/profiles"): profile_get,
            ("GET", f"/rest/v1/{table}"): table_get,
            ("POST", f"/rest/v1/{table}"): table_post,
            ("PATCH", f"/rest/v1/{table}"): table_patch,
            ("DELETE", f"/rest/v1/{table}"): table_delete,
        }
    )


@pytest.fixture
def journals_table(upstream):
    def _use(profile, journals=None):
        return _canned_table(
            upstream, table="journals", profile=profile, rows=journals or []
        )

    return _use

def mood_row(user_id, day, mood=3, description=None):
    return {
        "user_id": user_id,
        "created_at": day,
        "mood": mood,
        "description": description,
    }


@pytest.fixture
def moods_table(upstream):
    def _use(profile, moods=None, max_rows=1000):
        return _canned_table(
            upstream,
            table="moods",
            profile=profile,
            rows=moods or [],
            max_rows=max_rows,
            row_for=lambda body: {
                **mood_row(body["user_id"], body["created_at"]),
                **body,
            },
        )

    return _use


@pytest.fixture
def mock_client(offline_env):
    from fastapi.testclient import TestClient

    import app.main as main
    from app.auth import service
    from app.auth.router import verified_session
    from app.journals import router as journals_router
    from app.moods import router as moods_router

    session = service.Session(
        user_id="00000000-0000-4000-8000-000000000001",
        email="offline@gmail.com",
        token="offline-token",
    )
    main.app.dependency_overrides[verified_session] = lambda: session
    main.app.dependency_overrides[moods_router.mother_only] = lambda: session
    main.app.dependency_overrides[journals_router.mother_or_companion] = (
        lambda: session
    )
    yield TestClient(main.app), session
    main.app.dependency_overrides.clear()
