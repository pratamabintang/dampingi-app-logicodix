from typing import Literal

from pydantic import BaseModel, Field


class InviteCodeCreate(BaseModel):

    model_config = {"extra": "forbid"}

    target_role: Literal["mother", "companion", "professional"] = Field(
        description=(
            "The Role the redeemer must hold. A Mother targets 'companion' or "
            "'professional'; a Companion or Professional targets 'mother'."
        ),
    )


class InviteCodeOut(BaseModel):

    id: str
    code: str
    target_role: str
    expires_at: str


class InviteCodeListOut(BaseModel):

    invite_codes: list[InviteCodeOut]
    count: int
    offset: int
    limit: int
    total: int


class ConnectionRedeem(BaseModel):

    model_config = {"extra": "forbid"}

    code: str = Field(
        description="An Invite code, case- and dash-insensitive.",
    )


class CounterpartOut(BaseModel):

    id: str = Field(
        description=(
            "The counterpart's user ID. A Companion needs the Mother's ID "
            "to create an Observation about her."
        )
    )
    name: str
    role: str


class ConnectionOut(BaseModel):

    id: str
    connected_at: str
    counterpart: CounterpartOut


class ConnectionListOut(BaseModel):

    connections: list[ConnectionOut]
    count: int
    offset: int
    limit: int
    total: int
