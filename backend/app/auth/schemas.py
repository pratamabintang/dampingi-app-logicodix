import string
from enum import Enum
from typing import Optional
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator

PASSWORD_RULE = (
    "Kata sandi minimal 8 karakter dan harus memuat huruf kecil, huruf besar, "
    "angka, dan simbol."
)

_PASSWORD_CLASSES = (
    frozenset(string.ascii_lowercase),
    frozenset(string.ascii_uppercase),
    frozenset(string.digits),
    frozenset("!@#$%^&*()_+-=[]{};'\\:\"|<>?,./`~"),
)


def enforce_password_policy(value: str) -> str:
    """Reject a password Supabase would reject, before it reaches Supabase.

    The project's `password_required_characters` requires one lowercase
    letter, one uppercase letter, one digit, and one symbol. A password that
    clears only the local length bound gets `422 weak_password` from
    Supabase, which the error boundary reports as an outage (`503`).
    Checking the classes here keeps the refusal a `422` the caller can act
    on instead of an outage they cannot.
    """
    if not all(any(char in allowed for char in value) for allowed in _PASSWORD_CLASSES):
        raise ValueError(PASSWORD_RULE)
    return value


class Role(str, Enum):

    mother = "mother"
    companion = "companion"
    professional = "professional"


class RegisterRequest(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    email: EmailStr
    password: str = Field(min_length=8, max_length=72)
    role: Role
    timezone: str = Field(default="Asia/Jakarta", min_length=1, max_length=64)

    @field_validator("email")
    @classmethod
    def must_be_gmail(cls, value: EmailStr) -> EmailStr:
        if not value.lower().endswith("@gmail.com"):
            raise ValueError("registration is restricted to Gmail addresses")
        return value

    @field_validator("timezone")
    @classmethod
    def must_be_an_iana_zone(cls, value: str) -> str:
        try:
            ZoneInfo(value)
        except (ZoneInfoNotFoundError, ValueError, TypeError) as exc:
            raise ValueError(
                f"unknown IANA timezone: {value!r}"
            ) from exc
        return value

    @field_validator("password")
    @classmethod
    def password_must_meet_the_policy(cls, value: str) -> str:
        return enforce_password_policy(value)


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1)


class VerifyEmailRequest(BaseModel):
    email: EmailStr
    token: str = Field(min_length=1, max_length=64)


class ResendConfirmationRequest(BaseModel):
    email: EmailStr


class ForgotPasswordRequest(BaseModel):
    email: EmailStr


class ResetPasswordRequest(BaseModel):
    email: EmailStr
    token: str = Field(min_length=1, max_length=64)
    new_password: str = Field(min_length=8, max_length=72)

    @field_validator("new_password")
    @classmethod
    def password_must_meet_the_policy(cls, value: str) -> str:
        return enforce_password_policy(value)


class UserOut(BaseModel):
    id: str
    email: str
    name: Optional[str] = None
    role: Optional[Role] = None


class RegisterResponse(BaseModel):
    user: UserOut
    access_token: Optional[str] = None


class LoginResponse(BaseModel):
    access_token: str
    refresh_token: Optional[str] = None
    expires_in: Optional[int] = None
    user: UserOut


class RefreshRequest(BaseModel):

    model_config = ConfigDict(extra="forbid")

    refresh_token: str = Field(min_length=1)


class RefreshResponse(BaseModel):
    access_token: str
    refresh_token: str
    expires_in: Optional[int] = None


class UpdateMeRequest(BaseModel):

    model_config = ConfigDict(extra="forbid")

    name: str = Field(min_length=1, max_length=100)


class ChangePasswordRequest(BaseModel):
    current_password: str = Field(min_length=1)
    new_password: str = Field(min_length=8, max_length=72)

    @field_validator("new_password")
    @classmethod
    def password_must_meet_the_policy(cls, value: str) -> str:
        return enforce_password_policy(value)
