from conftest import supabase_error

REGISTER = "/auth/register"
LOGIN = "/auth/login"

ALREADY_REGISTERED = supabase_error(
    422, "User already registered", "user_already_exists"
)

BAD_CREDENTIALS = supabase_error(400, "Invalid login credentials", "invalid_credentials")


def test_registering_an_existing_address_is_refused_with_the_conflict_status(
    mock_client, upstream
):
    client, _ = mock_client
    upstream({("POST", "/auth/v1/signup"): ALREADY_REGISTERED})

    resp = client.post(
        REGISTER,
        json={
            "name": "Returning",
            "email": "returning@gmail.com",
            "password": "Sup3rSecure!",
            "role": "mother",
        },
    )

    assert resp.status_code == 409, resp.text
    assert "already registered" in resp.json()["detail"].lower()


def test_login_does_not_distinguish_unknown_address_from_wrong_password(
    mock_client, upstream
):
    client, _ = mock_client
    upstream({("POST", "/auth/v1/token"): BAD_CREDENTIALS})

    unknown = client.post(
        LOGIN, json={"email": "nobody@gmail.com", "password": "Sup3rSecure!"}
    )
    wrong = client.post(
        LOGIN, json={"email": "someone@gmail.com", "password": "WrongPass123!"}
    )

    assert unknown.status_code == 401, unknown.text
    assert wrong.status_code == 401, wrong.text
    assert unknown.json() == wrong.json()


def test_the_two_halves_are_deliberately_different(mock_client, upstream):
    client, _ = mock_client
    upstream(
        {
            ("POST", "/auth/v1/signup"): ALREADY_REGISTERED,
            ("POST", "/auth/v1/token"): BAD_CREDENTIALS,
        }
    )

    register = client.post(
        REGISTER,
        json={
            "name": "Returning",
            "email": "returning@gmail.com",
            "password": "Sup3rSecure!",
            "role": "mother",
        },
    )
    login = client.post(
        LOGIN, json={"email": "nobody@gmail.com", "password": "Sup3rSecure!"}
    )

    assert register.status_code == 409
    assert login.status_code == 401
    assert register.status_code != login.status_code
