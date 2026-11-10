from fastapi import Depends, HTTPException

from app.auth import supabase as auth_supabase, service as auth_service
from app.auth.router import verified_session


def require_role(role: str):
    
    def _check_role(
        session: auth_service.Session = Depends(verified_session),
    ) -> auth_service.Session:
        profile = auth_supabase.fetch_profile(session.user_id)
        if not profile or profile.get("role") != role:
            raise HTTPException(
                status_code=403,
                detail=f"Access denied: {role} role required",
            )
        return session
    
    return _check_role
