from app.auth import supabase as sb
from app.auth import service

import pytest

pytestmark = pytest.mark.local


def test_throttled_verification_is_not_a_wrong_password(monkeypatch):
    from app.auth import supabase as sb
    from app.auth import service

    session = service.Session(user_id="u", email="a@gmail.com", token="t")
    monkeypatch.setattr(service, "active_profile", lambda _uid: {"role": "mother"})

    def boom(_email, _password):
        raise sb.SupabaseError(429, "Request rate limit reached")

    monkeypatch.setattr(sb, "login", boom)

    with pytest.raises(sb.SupabaseError) as caught:
        service.change_password(session, "current", "N3wSecure!pass")
    assert caught.value.status == 429

    def wrong(_email, _password):
        raise sb.SupabaseError(400, "Invalid login credentials", "invalid_credentials")

    monkeypatch.setattr(sb, "login", wrong)
    with pytest.raises(service.CurrentPasswordIncorrect):
        service.change_password(session, "current", "N3wSecure!pass")
