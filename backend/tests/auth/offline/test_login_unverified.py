"""Login before the address is confirmed.

GoTrue answers `400 email_not_confirmed`. The router must translate that to a
`403` that names the problem, instead of the `401` it uses for bad
credentials — otherwise a user who simply has not clicked yet keeps retrying
the password.
"""

import pytest

from conftest import supabase_error

pytestmark = pytest.mark.local

LOGIN = "/auth/login"

UNVERIFIED = supabase_error(
    400, "Email not confirmed", "email_not_confirmed"
)

BAD_CREDENTIALS = supabase_error(400, "Invalid login credentials", "invalid_credentials")


def _login(client, email="waiting@gmail.com"):
    return client.post(LOGIN, json={"email": email, "password": "Sup3rSecure!"})


def test_an_unconfirmed_address_is_403_with_its_own_message(mock_client, upstream):
    client, _ = mock_client
    upstream({("POST", "/auth/v1/token"): UNVERIFIED})

    resp = _login(client)

    assert resp.status_code == 403, resp.text
    assert resp.json()["detail"] == (
        "Email belum diverifikasi. Cek email untuk kode verifikasi."
    )


def test_it_is_not_confused_with_a_wrong_password(mock_client, upstream):
    client, _ = mock_client
    upstream({("POST", "/auth/v1/token"): BAD_CREDENTIALS})

    resp = _login(client)

    assert resp.status_code == 401, resp.text
    assert resp.json()["detail"] == "Invalid email or password"
