"""The password policy the API enforces locally, and the upstream echo of it.

Supabase refuses a password missing a required character class with
`422 weak_password`. Before the schema checked the same rule, that upstream
`422` reached the error boundary and was answered as a `503` outage — telling
the caller to retry a request that could never succeed. The schema now refuses
it first (`422`), and each password route still translates the upstream echo.
"""

import pytest
from pydantic import ValidationError

from app.auth.schemas import (
    PASSWORD_RULE,
    ChangePasswordRequest,
    RegisterRequest,
    ResetPasswordRequest,
)
from conftest import captured, supabase_error, supabase_json

pytestmark = pytest.mark.local

PROFILE = captured("profiles-select-2026-11-09")

AUTH = {"Authorization": "Bearer offline-token"}

TOKEN = ("POST", "/auth/v1/token")
UPDATE_USER = ("PUT", "/auth/v1/user")
LOGOUT = ("POST", "/auth/v1/logout")
SIGNUP = ("POST", "/auth/v1/signup")

STRONG = "Sup3rSecure!"

WEAK_FROM_UPSTREAM = supabase_error(
    422,
    "Password should contain at least one character of each: "
    "abcdefghijklmnopqrstuvwxyz, ABCDEFGHIJKLMNOPQRSTUVWXYZ, 0123456789.",
    "weak_password",
)


@pytest.mark.parametrize(
    "weak",
    [
        "alllowercase1!",  # no uppercase letter
        "ALLUPPERCASE1!",  # no lowercase letter
        "NoDigitsThere!",  # no digit
        "NoSymbolsHere123",  # no symbol
    ],
)
def test_a_missing_character_class_is_refused_before_any_call(weak):
    with pytest.raises(ValidationError) as caught:
        RegisterRequest(
            name="Bunda", email="bunda@gmail.com", password=weak, role="mother"
        )
    assert PASSWORD_RULE in str(caught.value)


def test_every_password_field_shares_the_policy():
    with pytest.raises(ValidationError):
        ResetPasswordRequest(
            email="bunda@gmail.com", token="12345678", new_password="nodigitshere!"
        )
    with pytest.raises(ValidationError):
        ChangePasswordRequest(
            current_password="whatever", new_password="NoSymbolsHere123"
        )


def test_a_strong_password_passes_the_policy():
    request = RegisterRequest(
        name="Bunda", email="bunda@gmail.com", password=STRONG, role="mother"
    )
    assert request.password == STRONG


def test_changing_a_password_to_a_weak_one_is_422_not_503(mock_client, upstream):
    client, _ = mock_client
    upstream(
        {
            ("GET", "/rest/v1/profiles"): supabase_json(200, [PROFILE]),
            TOKEN: supabase_json(
                200,
                {
                    "access_token": "THROWAWAY",
                    "refresh_token": "THROWAWAY-REFRESH",
                    "user": {"id": PROFILE["user_id"], "email": "offline@gmail.com"},
                },
            ),
            LOGOUT: supabase_json(200, {}),
            UPDATE_USER: WEAK_FROM_UPSTREAM,
        }
    )

    resp = client.post(
        "/auth/password",
        headers=AUTH,
        json={"current_password": "Sup3rSecure!", "new_password": "N3wSecure!pass"},
    )

    assert resp.status_code == 422, resp.text
    assert resp.status_code != 503
    assert resp.json()["detail"] == PASSWORD_RULE


def test_registering_with_a_weak_password_is_422_not_503(mock_client, upstream):
    """The local policy usually catches this first; the echo is the backstop."""

    client, _ = mock_client
    recorded = upstream({SIGNUP: WEAK_FROM_UPSTREAM})

    resp = client.post(
        "/auth/register",
        json={
            "name": "Bunda",
            "email": "bunda@gmail.com",
            "password": STRONG,
            "role": "mother",
        },
    )

    assert resp.status_code == 422, resp.text
    assert resp.status_code != 503
    assert resp.json()["detail"] == PASSWORD_RULE
    assert [r.url.path for r in recorded.requests] == ["/auth/v1/signup"]
