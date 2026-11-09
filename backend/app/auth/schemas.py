from enum import Enum
from typing import Optional

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator


class Role(str, Enum):

    mother = "mother"
    companion = "companion"
    professional = "professional"


class RegisterRequest(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    email: EmailStr
    password: str = Field(min_length=8, max_length=72)
    role: Role

    @field_validator("email")
    @classmethod
    def must_be_gmail(cls, value: EmailStr) -> EmailStr:
        if not value.lower().endswith("@gmail.com"):
            raise ValueError("registration is restricted to Gmail addresses")
        return value


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1)


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
    user: UserOut


class UpdateMeRequest(BaseModel):

    model_config = ConfigDict(extra="forbid")

    name: str = Field(min_length=1, max_length=100)


class ChangePasswordRequest(BaseModel):
    current_password: str = Field(min_length=1)
    new_password: str = Field(min_length=8, max_length=72)
