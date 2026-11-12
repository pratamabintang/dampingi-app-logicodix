from starlette.requests import Request

from app import errors, security, throttle
from conftest import supabase_error

LOGIN = "/auth/login"
REGISTER = "/auth/register"
REDEEM = "/connections"

BAD_CREDENTIALS = supabase_error(400, "Invalid login credentials", "invalid_credentials")
ALREADY_REGISTERED = supabase_error(
    422, "User already registered", "user_already_exists"
)


def _limits(monkeypatch, **overrides):
    for name, value in overrides.items():
        monkeypatch.setattr(throttle, name.upper(), value)
    throttle.set_limiter(throttle.InMemoryRateLimiter())


def _login(client, email="ada@gmail.com", password="WrongPass1!"):
    return client.post(LOGIN, json={"email": email, "password": password})


def _register(client, email="new@gmail.com"):
    return client.post(
        REGISTER,
        json={
            "name": "New",
            "email": email,
            "password": "Sup3rSecure!",
            "role": "mother",
        },
    )




def test_the_account_limit_refuses_the_nth_plus_one_login(
    mock_client, upstream, monkeypatch
):
    _limits(monkeypatch, login_per_account=2, login_per_address=100)
    client, _ = mock_client
    recorded = upstream({("POST", "/auth/v1/token"): BAD_CREDENTIALS})

    for _ in range(2):
        assert _login(client).status_code == 401
    assert len(recorded.requests) == 2

    refused = _login(client)

    assert refused.status_code == 401
    assert len(recorded.requests) == 2


def test_the_address_limit_refuses_across_different_accounts(
    mock_client, upstream, monkeypatch
):
    _limits(monkeypatch, login_per_account=100, login_per_address=2)
    client, _ = mock_client
    recorded = upstream({("POST", "/auth/v1/token"): BAD_CREDENTIALS})

    assert _login(client, email="a@gmail.com").status_code == 401
    assert _login(client, email="b@gmail.com").status_code == 401
    assert len(recorded.requests) == 2

    assert _login(client, email="c@gmail.com").status_code == 401
    assert len(recorded.requests) == 2


def test_a_different_caller_address_is_unaffected(mock_client, upstream, monkeypatch):
    _limits(monkeypatch, login_per_account=100, login_per_address=2)
    here = {"ip": "203.0.113.1"}
    monkeypatch.setattr(throttle, "caller_address", lambda _request: here["ip"])
    client, _ = mock_client
    recorded = upstream({("POST", "/auth/v1/token"): BAD_CREDENTIALS})

    assert _login(client, email="a@gmail.com").status_code == 401
    assert _login(client, email="b@gmail.com").status_code == 401

    here["ip"] = "198.51.100.7"
    assert _login(client, email="c@gmail.com").status_code == 401
    assert len(recorded.requests) == 3


def test_caller_address_is_the_client_uvicorn_resolved(offline_env):
    scope = {"type": "http", "client": ("203.0.113.9", 50000), "headers": []}
    assert throttle.caller_address(Request(scope)) == "203.0.113.9"

    no_client = {"type": "http", "client": None, "headers": []}
    assert throttle.caller_address(Request(no_client)) == "unknown"




def test_a_throttled_login_is_byte_identical_to_a_wrong_password(
    mock_client, upstream, monkeypatch
):
    _limits(monkeypatch, login_per_account=1, login_per_address=100)
    client, _ = mock_client
    upstream({("POST", "/auth/v1/token"): BAD_CREDENTIALS})

    assert _login(client, email="known@gmail.com").status_code == 401

    throttled = _login(client, email="known@gmail.com")
    wrong = _login(client, email="other@gmail.com")

    assert throttled.status_code == wrong.status_code == 401
    assert throttled.content == wrong.content
    assert throttled.headers.get("retry-after") == wrong.headers.get("retry-after")


def test_a_transport_failure_is_not_reported_as_a_throttle(
    mock_client, upstream, monkeypatch
):
    import httpx

    _limits(monkeypatch, login_per_account=100, login_per_address=100)
    client, _ = mock_client

    def unreachable(_request):
        raise httpx.ConnectError("connection refused")

    upstream({("POST", "/auth/v1/token"): unreachable})

    assert _login(client).status_code == 503




def test_the_nth_plus_one_registration_is_429_with_a_retry_hint(
    mock_client, upstream, monkeypatch
):
    _limits(monkeypatch, register_per_address=2, register_per_account=100)
    client, _ = mock_client
    recorded = upstream({("POST", "/auth/v1/signup"): ALREADY_REGISTERED})

    assert _register(client, "a@gmail.com").status_code == 409
    assert _register(client, "b@gmail.com").status_code == 409
    assert len(recorded.requests) == 2

    refused = _register(client, "c@gmail.com")

    assert refused.status_code == 429, refused.text
    assert refused.json()["detail"] == errors._THROTTLED
    assert refused.headers.get("Retry-After")
    for name, value in security.SECURITY_HEADERS.items():
        assert refused.headers.get(name) == value, f"missing {name} on the 429"
    assert len(recorded.requests) == 2


def test_the_register_account_limit_refuses_the_nth_plus_one(
    mock_client, upstream, monkeypatch
):
    _limits(monkeypatch, register_per_address=100, register_per_account=2)
    client, _ = mock_client
    recorded = upstream({("POST", "/auth/v1/signup"): ALREADY_REGISTERED})

    assert _register(client, "same@gmail.com").status_code == 409
    assert _register(client, "same@gmail.com").status_code == 409

    refused = _register(client, "Same@Gmail.com")

    assert refused.status_code == 429, refused.text
    assert len(recorded.requests) == 2


def test_the_nth_plus_one_redemption_is_429_with_a_retry_hint(
    mock_client, upstream, monkeypatch
):
    _limits(monkeypatch, redeem_per_user=1)
    client, _ = mock_client
    recorded = upstream({})

    first = client.post(
        REDEEM,
        headers={"Authorization": "Bearer offline-token"},
        json={"code": "ABCD-EFGH"},
    )
    assert first.status_code != 429
    after_first = len(recorded.requests)

    refused = client.post(
        REDEEM,
        headers={"Authorization": "Bearer offline-token"},
        json={"code": "ABCD-EFGH"},
    )

    assert refused.status_code == 429, refused.text
    assert refused.headers.get("Retry-After")
    assert len(recorded.requests) == after_first




def test_the_window_resets_after_its_interval(monkeypatch):
    now = {"t": 1_000.0}
    limiter = throttle.InMemoryRateLimiter(clock=lambda: now["t"])

    assert limiter.hit("k", 2, 900) is None
    assert limiter.hit("k", 2, 900) is None
    assert limiter.hit("k", 2, 900) == 900

    now["t"] += 900
    assert limiter.hit("k", 2, 900) is None


def test_redemption_buckets_are_per_user(monkeypatch):
    _limits(monkeypatch, redeem_per_user=1)

    throttle.record_redemption("user-1")
    try:
        throttle.record_redemption("user-1")
    except throttle.RateLimited:
        pass
    else:
        raise AssertionError("the second redemption for user-1 was not refused")

    throttle.record_redemption("user-2")


def test_a_disabled_limiter_never_refuses(mock_client, upstream, monkeypatch):
    monkeypatch.setattr(throttle, "LOGIN_PER_ACCOUNT", 1)
    monkeypatch.setattr(throttle, "LOGIN_PER_ADDRESS", 1)
    throttle.set_limiter(throttle.NullRateLimiter())
    client, _ = mock_client
    recorded = upstream({("POST", "/auth/v1/token"): BAD_CREDENTIALS})

    for _ in range(5):
        assert _login(client).status_code == 401
    assert len(recorded.requests) == 5


def test_attempts_under_the_real_limits_are_not_refused(
    mock_client, upstream, monkeypatch
):
    throttle.set_limiter(throttle.InMemoryRateLimiter())
    client, _ = mock_client
    recorded = upstream({("POST", "/auth/v1/token"): BAD_CREDENTIALS})

    for _ in range(3):
        assert _login(client).status_code == 401
    assert len(recorded.requests) == 3
