from typing import Literal

from openai import AsyncOpenAI
from pydantic import SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict

from .gateway import AIGateway
from .providers import FakeProvider, OpenAIProvider


class AISettings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    ai_provider: Literal["fake", "openai"] = "fake"
    openai_api_key: SecretStr | None = None  # SecretStr: tidak tercetak di log/print
    openai_model: str | None = None
    ai_timeout_seconds: float = 20.0


def build_gateway(settings: AISettings | None = None) -> AIGateway:
    s = settings or AISettings()
    if s.ai_provider == "openai":
        if s.openai_api_key is None or not s.openai_model:
            raise RuntimeError("AI_PROVIDER=openai butuh OPENAI_API_KEY dan OPENAI_MODEL di .env")
        client = AsyncOpenAI(
            api_key=s.openai_api_key.get_secret_value(),
            timeout=s.ai_timeout_seconds,
            max_retries=0,  # gagal cepat; pengguna bisa kirim ulang
        )
        return AIGateway(OpenAIProvider(client, s.openai_model), s.ai_timeout_seconds)
    return AIGateway(FakeProvider(), s.ai_timeout_seconds)