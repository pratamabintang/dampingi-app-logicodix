import importlib

import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import rsa
from fastapi import HTTPException
from fastapi.security import HTTPAuthorizationCredentials

from app.auth.router import verified_session

auth_router = importlib.import_module("app.auth.router")

ISSUER = "https://offline.supabase.test/auth/v1"
SUB = "00000000-0000-4000-8000-000000000001"
FAR_FUTURE = 4102444800  # 2100-01-01


class _SigningKey:
    def __init__(self, key):
        self.key = key


class _FakeJwk:

    def __init__(self, public_key):
        self._public_key = public_key

    def get_signing_key_from_jwt(self, _token):
        return _SigningKey(self._public_key)


@pytest.fixture
def signing(offline_env, monkeypatch):
    private = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    monkeypatch.setattr(auth_router, "_jwk", lambda: _FakeJwk(private.public_key()))
    return private


def _token(private, **claims):
    payload = {
        "sub": SUB,
        "aud": "authenticated",
        "iss": ISSUER,
        "exp": FAR_FUTURE,
        "email": "offline@gmail.com",
        **claims,
    }
    return jwt.encode(payload, private, algorithm="RS256")


def _verify(token):
    return verified_session(
        HTTPAuthorizationCredentials(scheme="Bearer", credentials=token)
    )


def _assert_401(call):
    with pytest.raises(HTTPException) as exc:
        call()
    assert exc.value.status_code == 401, exc.value


def test_a_valid_token_yields_its_session(signing):
    token = _token(signing)

    session = _verify(token)

    assert session.user_id == SUB
    assert session.email == "offline@gmail.com"
    assert session.token == token


def test_missing_credentials_are_refused(offline_env):
    _assert_401(lambda: verified_session(None))


def test_a_non_bearer_scheme_is_refused(signing):
    token = _token(signing)

    _assert_401(
        lambda: verified_session(
            HTTPAuthorizationCredentials(scheme="Basic", credentials=token)
        )
    )


@pytest.mark.parametrize(
    "overrides",
    [
        {"aud": "another-service"},
        {"iss": "https://someone-elses-project.supabase.co/auth/v1"},
        {"exp": 1},  # long expired
        {"sub": None},
        {"exp": None},
    ],
    ids=["wrong-audience", "wrong-issuer", "expired", "missing-sub", "missing-exp"],
)
def test_a_token_failing_a_claim_check_is_401(signing, overrides):
    token = _token(signing, **overrides)

    _assert_401(lambda: _verify(token))


def test_a_token_signed_by_another_key_is_401(signing):
    impostor = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    token = _token(impostor)  # signed by a key the fake JWKS does not hold

    _assert_401(lambda: _verify(token))


def test_an_hmac_token_is_refused_by_the_algorithm_allowlist(signing):
    token = jwt.encode(
        {"sub": SUB, "aud": "authenticated", "iss": ISSUER, "exp": FAR_FUTURE},
        key="attacker-controlled-secret-32-bytes-min",
        algorithm="HS256",
    )

    _assert_401(lambda: _verify(token))


def test_an_unknown_signing_key_surfaces_the_migration_hint(offline_env, monkeypatch):

    class _NoKey:
        def get_signing_key_from_jwt(self, _token):
            raise jwt.PyJWKClientError("no matching key")

    monkeypatch.setattr(auth_router, "_jwk", lambda: _NoKey())

    with pytest.raises(HTTPException) as exc:
        verified_session(
            HTTPAuthorizationCredentials(scheme="Bearer", credentials="not.a.jwt")
        )

    assert exc.value.status_code == 401
    assert "migrate to signing keys" in exc.value.detail
