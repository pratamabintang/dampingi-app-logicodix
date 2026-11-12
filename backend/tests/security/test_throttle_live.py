import pytest

from app import security, throttle

pytestmark = pytest.mark.live


def _payload(email: str) -> dict:
    return {
        "name": "Throttle Probe",
        "email": email,
        "password": "Sup3rSecure!",
        "role": "mother",
    }


def test_a_throttled_registration_is_429_with_a_retry_hint(
    client, supabase_env, tracked_users, unique_email, monkeypatch
):
    monkeypatch.setattr(throttle, "REGISTER_PER_ADDRESS", 1)
    throttle.set_limiter(throttle.InMemoryRateLimiter())

    first = client.post("/auth/register", json=_payload(unique_email()))
    assert first.status_code == 201, first.text
    tracked_users.append(first.json()["user"]["id"])

    second = client.post("/auth/register", json=_payload(unique_email()))

    assert second.status_code == 429, second.text
    assert second.json()["detail"] == "Too many requests. Please try again later."
    assert second.headers.get("Retry-After")
    for name, value in security.SECURITY_HEADERS.items():
        assert second.headers.get(name) == value, f"missing {name} on the 429"
