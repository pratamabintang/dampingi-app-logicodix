from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query

from app.auth import service as auth_service
from app.auth.router import verified_session
from app import throttle
from app.connections import service
from app.connections.schemas import (
    ConnectionListOut,
    ConnectionOut,
    ConnectionRedeem,
    InviteCodeCreate,
    InviteCodeListOut,
    InviteCodeOut,
)

router = APIRouter(tags=["connections"])



def _handle_connection_errors(func, *args):
    try:
        return func(*args)
    except service.ConnectionProfileNotFound:
        raise HTTPException(
            status_code=404,
            detail="User profile not found or has been deleted",
        )
    except service.InviteCodeInvalidTarget as exc:
        raise HTTPException(
            status_code=400,
            detail=(
                f"A {exc.issuer_role} cannot invite a {exc.target_role}"
            ),
        )
    except (service.ConnectionLimitReached, service.InviteCodeLimitReached) as exc:
        if exc.target_role == "professional":
            detail = "This mother already has a professional"
        else:
            detail = "You are already connected to a mother"
        raise HTTPException(status_code=409, detail=detail)
    except service.InviteCodeNotIssued:
        raise HTTPException(
            status_code=503,
            detail="Could not allocate an invite code; please try again",
        )
    except service.InviteCodeNotFound:
        raise HTTPException(
            status_code=404, detail="Invite code is not valid"
        )
    except service.ConnectionNotFound:
        raise HTTPException(status_code=404, detail="Connection not found")
    except service.InviteCodeMalformed as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    except service.InviteCodeRoleMismatch as exc:
        raise HTTPException(
            status_code=403,
            detail=f"This invite code is for a {exc.target_role}",
        )


@router.post(
    "/connections/invite-codes",
    status_code=201,
    response_model=InviteCodeOut,
    summary="Issue an Invite code",
    description=(
        "Mint a single-use code that will later authorise one Connection. "
        "The code names the Role its redeemer must hold: a Mother may invite a "
        "Companion or a Professional, while a Companion or Professional may "
        "only invite a Mother. It lives exactly one hour. A Mother who already "
        "has a Professional cannot issue a professional-target code, and a "
        "Companion or Professional already connected to a Mother cannot issue a "
        "mother-target code."
    ),
)
def issue_invite_code(
    payload: InviteCodeCreate,
    session: auth_service.Session = Depends(verified_session),
) -> InviteCodeOut:
    return _handle_connection_errors(
        service.issue_invite_code,
        session.user_id,
        payload.target_role,
    )


@router.get(
    "/connections/invite-codes",
    response_model=InviteCodeListOut,
    summary="List my live Invite codes",
    description=(
        "The caller's codes that are not yet spent: unredeemed, unrevoked, "
        "and unexpired, newest first. Closing the sheet before sending a code "
        "is not a disaster — the code is still here. A redeemed, revoked, or "
        "expired code never appears. offset and limit enable pagination "
        "(limit capped at 100)."
    ),
)
def list_invite_codes(
    offset: int = Query(0, ge=0, description="Number of results to skip"),
    limit: int = Query(
        100, ge=1, le=100, description="Number of results to return (max 100)"
    ),
    session: auth_service.Session = Depends(verified_session),
) -> InviteCodeListOut:
    return _handle_connection_errors(
        service.list_invite_codes, session.user_id, offset, limit
    )


@router.delete(
    "/connections/invite-codes/{id}",
    status_code=204,
    summary="Revoke an Invite code",
    description=(
        "Stamp the code `revoked` so it can no longer be redeemed. The row is "
        "never deleted. Revoking a code that is not the caller's, or that is "
        "no longer live (redeemed, expired, or already revoked), reports 404 "
        "— the same 404 for every such case, so the endpoint cannot probe "
        "which codes exist. DELETE is the verb, but nothing is deleted: this "
        "is the ending that is never a delete, for a code."
    ),
)
def revoke_invite_code(
    id: UUID,
    session: auth_service.Session = Depends(verified_session),
) -> None:
    return _handle_connection_errors(
        service.revoke_invite_code, session.user_id, str(id)
    )


@router.delete(
    "/connections/{id}",
    status_code=204,
    summary="End a Connection",
    description=(
        "Either end withdraws, without the other's permission. `ended_at` is "
        "stamped and `ended_by` records who did it; the row survives, so "
        "\"who had access to this Mother's data, and when\" stays answerable. "
        "Ending is not idempotent: a Connection that is not the caller's, "
        "already ended, or unknown is one identical 404. DELETE is the verb, "
        "but nothing is deleted."
    ),
)
def end_connection(
    id: UUID,
    session: auth_service.Session = Depends(verified_session),
) -> None:
    return _handle_connection_errors(
        service.end_connection, session.user_id, str(id)
    )


@router.get(
    "/connections",
    response_model=ConnectionListOut,
    summary="List my active Connections",
    description=(
        "Who is connected to the caller right now. The list is symmetric in "
        "shape but not in content: every item carries the counterpart's name "
        "and role, so a Mother sees her Companions and her one Professional, "
        "while a Companion or Professional sees Mothers. Active Connections "
        "only — an ended one disappears from both ends' lists, and a "
        "Connection whose other end is a soft-deleted Profile is filtered "
        "even if the delete path's stamping did not run. offset and limit "
        "enable pagination (limit capped at 100)."
    ),
)
def list_connections(
    offset: int = Query(0, ge=0, description="Number of results to skip"),
    limit: int = Query(
        100, ge=1, le=100, description="Number of results to return (max 100)"
    ),
    session: auth_service.Session = Depends(verified_session),
) -> ConnectionListOut:
    return _handle_connection_errors(
        service.list_connections, session.user_id, offset, limit
    )


@router.post(
    "/connections",
    status_code=201,
    response_model=ConnectionOut,
    summary="Redeem an Invite code",
    description=(
        "Present a code to create the Connection it authorises. The redeemer "
        "must hold the Role the code names; otherwise 403. The code names its "
        "target Role, so both Connection limits are checkable at redemption: "
        "409 'This mother already has a professional' or "
        "409 'You are already connected to a mother'. Every code-side failure "
        "(unknown, expired, revoked, spent, issued by a since-deleted Profile) "
        "is one identical 404 'Invite code is not valid'; a malformed code is "
        "400 so a typo is distinguishable from a valid-but-invalid code."
    ),
)
def redeem_invite_code(
    payload: ConnectionRedeem,
    session: auth_service.Session = Depends(verified_session),
) -> ConnectionOut:
    throttle.record_redemption(session.user_id)
    return _handle_connection_errors(
        service.redeem_invite_code, session.user_id, payload.code
    )
