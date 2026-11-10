import uuid

import pytest

pytestmark = pytest.mark.live


def test_purge_deletes_leaked_test_users(client, supabase_env):
    from app import admin
    from app.auth import supabase

    email = f"pytest.swept{uuid.uuid4().hex[:12]}@gmail.com"
    body = supabase.signup(
        name="Sweep Me", email=email, password="Sup3rSecure!", role="mother"
    )
    user_id = body["user"]["id"]
    leaked_before = [u for u in admin.find_leaked_users() if u.get("id") == user_id]
    assert leaked_before, "freshly created test-pattern user not detected as leaked"

    deleted = admin.delete_users(leaked_before, log=lambda _msg: None)
    assert deleted == 1

    remaining = [u for u in admin.all_user_ids() if u.get("id") == user_id]
    assert not remaining, "test-pattern user survived the sweep"


def test_purge_deletes_soft_deleted_test_users(client, supabase_env):
    from app import admin
    from app.auth import supabase

    email = f"pytest.dead{uuid.uuid4().hex[:12]}@gmail.com"
    body = supabase.signup(
        name="Dead Walk", email=email, password="Sup3rSecure!", role="mother"
    )
    user_id = body["user"]["id"]
    supabase.ban_user(user_id)
    assert supabase.tombstone_profile(user_id)

    leaked = [u for u in admin.find_leaked_users() if u.get("id") == user_id]
    assert leaked, "soft-deleted test user not detected as leaked"
    assert admin.delete_users(leaked, log=lambda _msg: None) == 1
    assert not [u for u in admin.all_user_ids() if u.get("id") == user_id]


def test_purge_leaves_real_users_alone(client, supabase_env):
    from app import admin
    from app.admin import is_test_email

    users = admin.all_user_ids()
    non_test = [u for u in users if not is_test_email(u.get("email"))]
    for u in non_test:
        assert not admin.is_test_email(u.get("email"))


def test_status_runs_clean(client, supabase_env, capsys):
    from app import admin

    rc = admin.cmd_status(None)
    out = capsys.readouterr().out
    assert rc == 0
    assert "total users:" in out
    assert "test users:" in out
