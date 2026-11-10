from typing import Optional

from app.auth import supabase as auth_supabase


def active_profile(user_id: str) -> Optional[dict]:
    profile = auth_supabase.fetch_profile(user_id)
    if not profile or profile.get("deleted_at"):
        return None
    return profile
