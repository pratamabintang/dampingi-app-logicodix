from conftest import (
    CONNECTIONS_COMPANION,
    CONNECTIONS_MOTHER,
    CONNECTIONS_OTHER_MOTHER,
    CONNECTIONS_PROFESSIONAL,
    captured,
    captured_empty,
    connection_row,
    connections_profiles,
    supabase_json,
)

AUTH = {"Authorization": "Bearer offline-token"}


def _auth_routes(user_id: str, profiles: dict) -> dict:
    def tombstone(request):
        profiles[user_id]["deleted_at"] = "2026-11-15T14:00:00+00:00"
        return captured_empty("profiles-patch-tombstone-2026-11-09")

    return {
        ("POST", "/auth/v1/logout"): captured_empty("auth-logout-2026-11-09"),
        ("PUT", f"/auth/v1/admin/users/{user_id}"): supabase_json(
            200, captured("admin-user-ban-2026-11-09")
        ),
        ("PATCH", "/rest/v1/profiles"): tombstone,
    }


def test_soft_deleting_a_mother_ends_their_connections(
    mock_client, connections_table, as_author
):
    client, _ = mock_client
    as_author(CONNECTIONS_MOTHER)
    profiles = connections_profiles()
    connections_table(
        profiles=profiles,
        connections=[
            connection_row(CONNECTIONS_MOTHER, CONNECTIONS_COMPANION, "companion"),
            connection_row(CONNECTIONS_MOTHER, CONNECTIONS_PROFESSIONAL, "professional"),
        ],
        extra_routes=_auth_routes(CONNECTIONS_MOTHER, profiles),
    )

    deleted = client.delete("/me", headers=AUTH)
    assert deleted.status_code == 204, deleted.text

    as_author(CONNECTIONS_COMPANION)
    listed = client.get("/connections", headers=AUTH)
    assert listed.status_code == 200, listed.text
    assert listed.json()["connections"] == []

    as_author(CONNECTIONS_OTHER_MOTHER)
    issued = client.post(
        "/connections/invite-codes", headers=AUTH, json={"target_role": "companion"}
    )
    assert issued.status_code == 201, issued.text

    as_author(CONNECTIONS_COMPANION)
    redeemed = client.post(
        "/connections", headers=AUTH, json={"code": issued.json()["code"]}
    )
    assert redeemed.status_code == 201, redeemed.text


def test_the_delete_survives_a_failed_stamp(
    mock_client, connections_table, as_author
):
    from conftest import supabase_error

    client, _ = mock_client
    as_author(CONNECTIONS_MOTHER)
    profiles = connections_profiles()
    connections_table(
        profiles=profiles,
        connections=[
            connection_row(CONNECTIONS_MOTHER, CONNECTIONS_COMPANION, "companion")
        ],
        extra_routes={
            **_auth_routes(CONNECTIONS_MOTHER, profiles),
            ("PATCH", "/rest/v1/connections"): supabase_error(
                500, "upstream exploded", "unexpected_failure"
            ),
        },
    )

    deleted = client.delete("/me", headers=AUTH)
    assert deleted.status_code == 204, deleted.text

    as_author(CONNECTIONS_COMPANION)
    listed = client.get("/connections", headers=AUTH)
    assert listed.status_code == 200, listed.text
    assert listed.json()["connections"] == []

    as_author(CONNECTIONS_OTHER_MOTHER)
    issued = client.post(
        "/connections/invite-codes", headers=AUTH, json={"target_role": "companion"}
    )
    assert issued.status_code == 201, issued.text

    as_author(CONNECTIONS_COMPANION)
    refused = client.post(
        "/connections", headers=AUTH, json={"code": issued.json()["code"]}
    )
    assert refused.status_code == 409, refused.text


def test_soft_deleting_a_professional_frees_the_mother_s_slot(
    mock_client, connections_table, as_author
):
    client, _ = mock_client
    profiles = connections_profiles()
    connections_table(
        profiles=profiles,
        connections=[
            connection_row(CONNECTIONS_MOTHER, CONNECTIONS_PROFESSIONAL, "professional")
        ],
        extra_routes=_auth_routes(CONNECTIONS_PROFESSIONAL, profiles),
    )

    as_author(CONNECTIONS_MOTHER)
    blocked = client.post(
        "/connections/invite-codes", headers=AUTH, json={"target_role": "professional"}
    )
    assert blocked.status_code == 409, blocked.text

    as_author(CONNECTIONS_PROFESSIONAL)
    deleted = client.delete("/me", headers=AUTH)
    assert deleted.status_code == 204, deleted.text

    as_author(CONNECTIONS_MOTHER)
    issued = client.post(
        "/connections/invite-codes", headers=AUTH, json={"target_role": "professional"}
    )
    assert issued.status_code == 201, issued.text
