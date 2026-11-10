from typing import Optional

from pydantic import AliasChoices, Field, ValidationError
from pydantic_settings import BaseSettings, SettingsConfigDict, SettingsError


class Settings(BaseSettings):

    app_env: str = "development"
    port: int = 8000
    gemini_api_key: Optional[str] = None
    gemini_model: str = "gemini-3.1-flash-lite"

    supabase_url: str
    supabase_publishable_key: str = Field(
        validation_alias=AliasChoices(
            "SUPABASE_PUBLISHABLE_KEY", "SUPABASE_ANON_KEY"
        )
    )
    supabase_secret_key: str = Field(
        validation_alias=AliasChoices(
            "SUPABASE_SECRET_KEY", "SUPABASE_SERVICE_ROLE_KEY"
        )
    )

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")


_settings: Optional[Settings] = None


def get_settings() -> Settings:
    global _settings
    if _settings is None:
        try:
            _settings = Settings()
        except (ValidationError, SettingsError) as exc:
            raise SystemExit(f"Invalid configuration: {exc}") from exc
    return _settings


def reset_settings() -> None:
    global _settings
    _settings = None


def supabase_auth_http() -> dict:
    settings = get_settings()
    return {
        "apikey": settings.supabase_publishable_key,
        "Authorization": f"Bearer {settings.supabase_publishable_key}",
        "Content-Type": "application/json",
    }


def supabase_service_http() -> dict:
    settings = get_settings()
    return {
        "apikey": settings.supabase_secret_key,
        "Authorization": f"Bearer {settings.supabase_secret_key}",
        "Content-Type": "application/json",
    }
