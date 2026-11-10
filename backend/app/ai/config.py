from typing import Literal

from google import genai
from google.genai import types
from pydantic import SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict

from .gateway import AIGateway
from .providers import FakeProvider, GeminiProvider


class AISettings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    ai_provider: Literal["fake", "gemini"] = "fake"
    # Nama variabel sama dengan yang dipakai fitur ringkasan mingguan (D): satu kunci untuk tim.
    gemini_api_key: SecretStr | None = None  # SecretStr: tidak tercetak di log/print
    gemini_model: str | None = None
    ai_timeout_seconds: float = 20.0


def build_gateway(settings: AISettings | None = None) -> AIGateway:
    s = settings or AISettings()
    if s.ai_provider == "gemini":
        if s.gemini_api_key is None or not s.gemini_model:
            raise RuntimeError("AI_PROVIDER=gemini butuh GEMINI_API_KEY dan GEMINI_MODEL di .env")
        client = genai.Client(
            api_key=s.gemini_api_key.get_secret_value(),
            http_options=types.HttpOptions(
                timeout=int(s.ai_timeout_seconds * 1000),           # milidetik
                retry_options=types.HttpRetryOptions(attempts=1),  # gagal cepat; pengguna bisa kirim ulang
            ),
        )
        return AIGateway(GeminiProvider(client, s.gemini_model), s.ai_timeout_seconds)
    return AIGateway(FakeProvider(), s.ai_timeout_seconds)