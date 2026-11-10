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
def real_moods_gate(mock_client):
    import app.main as main
    from app.moods import router as moods_router

    saved = main.app.dependency_overrides.pop(moods_router.mother_only, None)
    yield
    if saved is not None:
        main.app.dependency_overrides[moods_router.mother_only] = saved


@pytest.fixture
def as_author():

    def _as(user_id: str, token: str = "offline-token") -> None:
        import app.main as main
        from app.auth import service
        from app.auth.router import verified_session

        main.app.dependency_overrides[verified_session] = lambda: service.Session(
            user_id=user_id, email="offline@gmail.com", token=token
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




def _with_generated_id(row: dict) -> dict:
    return {**row, "id": row.get("id") or str(uuid.uuid4())}


def _canned_table(
    upstream, *, table, profile, rows, row_for=None, max_rows=1000, fail_insert=None
):

    import json

    import httpx

    stored = [_with_generated_id(row) for row in rows]
    fill = row_for or (lambda body: body)

    def _match(request):
        wanted_user = request.url.params.get("user_id")
        id_filters = request.url.params.get_list("id")
        day_filters = request.url.params.get_list("created_at")
        return [
            row
            for row in stored
            if (
                wanted_user is None
                or row["user_id"] == wanted_user.removeprefix("eq.")
            )
            and all(_compare(row["id"], wanted) for wanted in id_filters)
            and all(
                _compare(row["created_at"], wanted) for wanted in day_filters
            )
        ]

    def _select(request, matched):
        asked = request.url.params.get("select")
        if asked is None:
            return list(matched)
        if asked == "count":
            return [{} for _ in matched]
        return [
            {k: row[k] for k in asked.split(",") if k in row}
            for row in matched
        ]

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
        if fail_insert is not None:
            return fail_insert()
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
        row = fill(_with_generated_id(body))
        stored.append(row)
        return supabase_json(201, _select(request, [row]))

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

    def _use(profile, journals=None, fail_insert=None):
        return _canned_table(
            upstream,
            table="journals",
            profile=profile,
            rows=journals or [],
            fail_insert=fail_insert,
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



CONNECTIONS_MOTHER = "00000000-0000-4000-8000-0000000000a1"
CONNECTIONS_COMPANION = "00000000-0000-4000-8000-0000000000a2"
CONNECTIONS_OTHER_COMPANION = "00000000-0000-4000-8000-0000000000a3"
CONNECTIONS_PROFESSIONAL = "00000000-0000-4000-8000-0000000000a4"
CONNECTIONS_OTHER_MOTHER = "00000000-0000-4000-8000-0000000000a5"


def _split_top_level(select: str) -> list:
    parts, depth, current = [], 0, ""
    for char in select:
        if char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
        if char == "," and depth == 0:
            parts.append(current)
            current = ""
        else:
            current += char
    if current:
        parts.append(current)
    return [p.strip() for p in parts if p.strip()]


def _compare(value, wanted: str) -> bool:
    op, _, operand = wanted.partition(".")
    if op == "not":
        return not _compare(value, operand)
    if op == "is":
        return (value is None) if operand == "null" else (value is not None)
    if value is None:
        return False
    if op == "eq":
        return str(value) == operand
    if op == "neq":
        return str(value) != operand
    if op in ("gt", "gte", "lt", "lte"):
        left, right = str(value), operand
        return {
            "gt": left > right,
            "gte": left >= right,
            "lt": left < right,
            "lte": left <= right,
        }[op]
    raise AssertionError(f"canned table does not model operator {op!r}")


def _canned_connections(upstream, *, profiles, connections=None, invite_codes=None,
                        observations=None, max_rows=1000, extra_routes=None):

    import json

    import httpx

    stored_connections = list(connections or [])
    stored_codes = list(invite_codes or [])
    stored_observations = list(observations or [])
    by_id = dict(profiles)

    def _match(rows, request, columns):
        matched = rows
        for column in columns:
            wanted = request.url.params.get_list(column)
            if wanted:
                matched = [
                    row for row in matched
                    if all(_compare(row.get(column), w) for w in wanted)
                ]
        or_param = request.url.params.get("or")
        if or_param:
            clauses = or_param.strip("()").split(",")
            matched = [
                row for row in matched
                if any(
                    _compare(
                        row.get(clause.split(".", 2)[0]),
                        ".".join(clause.split(".", 2)[1:]),
                    )
                    for clause in clauses
                )
            ]
        return list(matched)

    def _project(rows, request):
        asked = _split_top_level(request.url.params.get("select", "*"))
        if asked == ["*"]:
            return rows
        if asked == ["count"]:
            return [{} for _ in rows]
        out = []
        for row in rows:
            projected = {}
            for field in asked:
                if ":" in field:
                    alias, _, target = field.partition(":")
                    table, _, spec = target.partition("!")
                    fk, _, fields = spec.partition("(")
                    wanted = [f.strip() for f in fields.rstrip(")").split(",")]
                    if table == "connections":
                        connection_id = row.get("connection_id")
                        related = next(
                            (
                                connection
                                for connection in stored_connections
                                if connection["id"] == connection_id
                            ),
                            None,
                        )
                        if related is None:
                            raise AssertionError(
                                f"embed {alias} found no connection for "
                                f"connection_id={connection_id!r}; the "
                                "transport asked for a join the fake cannot satisfy"
                            )
                    else:
                        related = by_id.get(row.get(fk))
                        if related is None:
                            raise AssertionError(
                                f"embed {alias} found no profile for {fk}={row.get(fk)!r}; "
                                "the transport asked for a join the fake cannot satisfy"
                            )
                    projected[alias] = {k: related[k] for k in wanted if k in related}
                elif field in row:
                    projected[field] = row[field]
                else:
                    raise AssertionError(
                        f"select asked for column {field!r}, which this row does "
                        f"not have: {sorted(row)}"
                    )
            out.append(projected)
        return out

    def _paged(rows, request, order_column):
        order = request.url.params.get("order")
        if order == f"{order_column}.desc":
            rows = sorted(rows, key=lambda r: r.get(order_column) or "", reverse=True)
        elif order == f"{order_column}.asc":
            rows = sorted(rows, key=lambda r: r.get(order_column) or "")
        offset = int(request.url.params.get("offset", 0))
        limit = int(request.url.params.get("limit", len(rows) or 1))
        return rows[offset : offset + min(limit, max_rows)]

    def _conflict(detail):
        return httpx.Response(
            409,
            json={
                "code": "23505",
                "details": detail,
                "message": "duplicate key value violates unique constraint",
            },
        )

    def _active(role=None, mother_id=None, counterpart_id=None):
        return [
            row for row in stored_connections
            if row.get("ended_at") is None
            and (role is None or row["counterpart_role"] == role)
            and (mother_id is None or row["mother_id"] == mother_id)
            and (counterpart_id is None or row["counterpart_id"] == counterpart_id)
        ]

    def connections_get(request):
        hits = _match(
            stored_connections, request,
            ["mother_id", "counterpart_id", "counterpart_role", "ended_at"],
        )
        return supabase_json(
            200, _project(_paged(hits, request, "connected_at"), request)
        )

    def connections_post(request):
        body = json.loads(request.content)
        if body["mother_id"] == body["counterpart_id"]:
            return httpx.Response(
                400,
                json={"code": "23514", "message": "connections_distinct_ends"},
            )
        role = body["counterpart_role"]
        if role == "professional" and _active("professional", mother_id=body["mother_id"]):
            return _conflict(
                "Key (mother_id) already exists for an active professional."
            )
        if role == "companion" and _active("companion", counterpart_id=body["counterpart_id"]):
            return _conflict(
                "Key (counterpart_id) already exists for an active companion."
            )
        row = {
            "id": str(uuid.uuid4()),
            "ended_at": None,
            "ended_by": None,
            "connected_at": "2026-11-15T12:00:00+00:00",
            **body,
        }
        stored_connections.append(row)
        return supabase_json(201, _project([row], request))

    def connections_patch(request):
        hits = _match(
            stored_connections, request,
            ["id", "mother_id", "counterpart_id", "ended_at"],
        )
        body = json.loads(request.content)
        for row in hits:
            row.update(body)
        return supabase_json(200, _project(hits, request))

    def codes_get(request):
        hits = _match(
            stored_codes, request,
            ["issuer_id", "code", "target_role", "redeemed_at", "revoked_at",
             "expires_at"],
        )
        return supabase_json(200, _project(_paged(hits, request, "created_at"), request))

    def codes_post(request):
        body = json.loads(request.content)
        clash = [
            row for row in stored_codes
            if row["code"] == body["code"]
            and row.get("redeemed_at") is None
            and row.get("revoked_at") is None
        ]
        if clash:
            return _conflict("Key (code) already exists among unspent codes.")
        row = {
            "id": str(uuid.uuid4()),
            "created_at": "2026-11-15T12:00:00+00:00",
            "redeemed_at": None,
            "redeemed_by": None,
            "revoked_at": None,
            **body,
        }
        stored_codes.append(row)
        return supabase_json(201, _project([row], request))

    def codes_patch(request):
        hits = _match(
            stored_codes, request,
            ["id", "issuer_id", "code", "redeemed_at", "revoked_at", "expires_at"],
        )
        body = json.loads(request.content)
        for row in hits:
            row.update(body)
        return supabase_json(200, _project(hits, request))

    def profiles_get(request):
        wanted = request.url.params.get("user_id")
        rows = list(by_id.values())
        if wanted is not None:
            rows = [r for r in rows if r["user_id"] == wanted.removeprefix("eq.")]
        return supabase_json(200, _project(rows, request))

    def _authored_observations(rows, request):
        wanted = request.url.params.get("connection.counterpart_id")
        if not wanted:
            return rows
        user_id = wanted.removeprefix("eq.")
        by_connection = {c["id"]: c for c in stored_connections}
        return [
            row for row in rows
            if (by_connection.get(row["connection_id"]) or {}).get(
                "counterpart_id"
            ) == user_id
        ]

    def observations_get(request):
        hits = _match(
            stored_observations, request,
            ["id", "connection_id", "day", "completed_at"],
        )
        hits = _authored_observations(hits, request)
        if request.headers.get("prefer") == "count=exact":
            page = hits[0:0]
            return httpx.Response(
                200,
                json=_project(page, request),
                headers={"content-range": f"0-0/{len(hits)}"},
            )
        return supabase_json(
            200, _project(_paged(hits, request, "created_at"), request)
        )

    def observations_post(request):
        body = json.loads(request.content)
        row = {
            "id": str(uuid.uuid4()),
            "created_at": "2026-11-10T09:00:00+00:00",
            "connection_id": body["connection_id"],
            "questions": body["questions"],
            "answers": body.get("answers"),
            "day": body.get("day"),
            "completed_at": body.get("completed_at"),
        }
        if row["day"] is not None:
            clash = [
                existing for existing in stored_observations
                if existing["connection_id"] == row["connection_id"]
                and existing["day"] == row["day"]
            ]
            if clash:
                return _conflict(
                    "Key (connection_id, day) already exists."
                )
        stored_observations.append(row)
        return supabase_json(201, _project([row], request))

    def observations_patch(request):
        hits = _match(
            stored_observations, request,
            ["id", "connection_id", "day", "completed_at"],
        )
        hits = _authored_observations(hits, request)
        body = json.loads(request.content)

        patched_ids = {id(row) for row in hits}
        if body.get("day") is not None:
            for row in hits:
                clash = [
                    existing for existing in stored_observations
                    if id(existing) not in patched_ids
                    and existing["connection_id"] == row["connection_id"]
                    and existing["day"] == body["day"]
                ]
                if clash:
                    return _conflict(
                        "Key (connection_id, day) already exists."
                    )

        for row in hits:
            row.update(body)
        return supabase_json(200, _project(hits, request))

    recorded = upstream(
        {
            ("GET", "/rest/v1/profiles"): profiles_get,
            ("GET", "/rest/v1/connections"): connections_get,
            ("POST", "/rest/v1/connections"): connections_post,
            ("PATCH", "/rest/v1/connections"): connections_patch,
            ("GET", "/rest/v1/invite_codes"): codes_get,
            ("POST", "/rest/v1/invite_codes"): codes_post,
            ("PATCH", "/rest/v1/invite_codes"): codes_patch,
            ("GET", "/rest/v1/observations"): observations_get,
            ("POST", "/rest/v1/observations"): observations_post,
            ("PATCH", "/rest/v1/observations"): observations_patch,
            **(extra_routes or {}),
        }
    )
    recorded.observations = stored_observations
    return recorded


def connection_row(mother_id, counterpart_id, counterpart_role="companion",
                   ended_at=None, connected_at="2026-11-15T12:00:00+00:00"):
    return {
        "id": str(uuid.uuid4()),
        "mother_id": mother_id,
        "counterpart_id": counterpart_id,
        "counterpart_role": counterpart_role,
        "connected_at": connected_at,
        "ended_at": ended_at,
        "ended_by": None,
    }


def observation_row(
    connection_id,
    questions=None,
    answers=None,
    day=None,
    completed_at=None,
    created_at="2026-11-18T09:00:00+00:00",
):
    return {
        "id": str(uuid.uuid4()),
        "connection_id": connection_id,
        "questions": questions or observation_questions(),
        "answers": answers,
        "day": day,
        "completed_at": completed_at,
        "created_at": created_at,
    }


def observation_questions():
    return [
        {
            "id": "q1",
            "prompt": "How did she sleep?",
            "options": [
                {"id": "q1o1", "label": "Well"},
                {"id": "q1o2", "label": "Poorly"},
            ],
        },
        {
            "id": "q2",
            "prompt": "How was her mood?",
            "options": [
                {"id": "q2o1", "label": "Calm"},
                {"id": "q2o2", "label": "Anxious"},
            ],
        },
    ]


def invite_code_row(issuer_id, code, target_role="companion",
                    expires_at="2026-11-15T13:00:00+00:00",
                    created_at="2026-11-15T12:00:00+00:00",
                    redeemed_at=None, redeemed_by=None, revoked_at=None):
    return {
        "id": str(uuid.uuid4()),
        "issuer_id": issuer_id,
        "target_role": target_role,
        "code": code,
        "created_at": created_at,
        "expires_at": expires_at,
        "redeemed_at": redeemed_at,
        "redeemed_by": redeemed_by,
        "revoked_at": revoked_at,
    }


def connections_profiles():
    def _profile(user_id, name, role):
        return {
            "user_id": user_id, "name": name, "role": role,
            "deleted_at": None, "timezone": "UTC",
        }

    return {
        CONNECTIONS_MOTHER: _profile(CONNECTIONS_MOTHER, "Ani", "mother"),
        CONNECTIONS_OTHER_MOTHER: _profile(CONNECTIONS_OTHER_MOTHER, "Sari", "mother"),
        CONNECTIONS_COMPANION: _profile(CONNECTIONS_COMPANION, "Budi", "companion"),
        CONNECTIONS_OTHER_COMPANION: _profile(
            CONNECTIONS_OTHER_COMPANION, "Dewi", "companion"
        ),
        CONNECTIONS_PROFESSIONAL: _profile(
            CONNECTIONS_PROFESSIONAL, "Dr. Ratna", "professional"
        ),
    }


@pytest.fixture
def connections_table(upstream):

    def _use(connections=None, invite_codes=None, profiles=None, max_rows=1000,
             extra_routes=None):
        return _canned_connections(
            upstream,
            profiles=profiles or connections_profiles(),
            connections=connections or [],
            invite_codes=invite_codes or [],
            max_rows=max_rows,
            extra_routes=extra_routes,
        )

    return _use


@pytest.fixture
def observations_table(upstream):

    def _use(
        connections=None,
        invite_codes=None,
        profiles=None,
        observations=None,
        extra_routes=None,
    ):
        return _canned_connections(
            upstream,
            profiles=profiles or connections_profiles(),
            connections=connections or [],
            invite_codes=invite_codes or [],
            observations=observations or [],
            extra_routes=extra_routes,
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
