"""Tes AI gateway (C02, provider Gemini sejak C06). Tanpa jaringan dan tanpa biaya: provider dipalsukan."""
import asyncio
import json
from types import SimpleNamespace
from typing import Any, cast

import pytest

from app.ai import AIBadOutput, AIError, AIGateway, AITimeout, AIUnavailable, Turn
from app.ai.config import AISettings, build_gateway
from app.ai.providers import FakeProvider, GeminiProvider

pytestmark = pytest.mark.local

SYSTEM = "Kamu pendamping ibu pascamelahirkan."
TURNS = [Turn("user", "Aku capek"), Turn("assistant", "Ceritakan ya"), Turn("user", "Bayiku rewel")]


def run(coro):
    return asyncio.run(coro)


# ---------- jalur normal ----------

def test_valid_reply_is_returned_and_trimmed():
    provider = FakeProvider("  Kamu hebat sudah bertahan.  ")
    result = run(AIGateway(provider).reply(SYSTEM, TURNS))
    assert result.reply == "Kamu hebat sudah bertahan."
    assert result.urgent is False
    assert provider.calls == [(SYSTEM, TURNS)]


def test_urgent_flag_is_passed_through():
    result = run(AIGateway(FakeProvider("Segera hubungi 119", urgent=True)).reply(SYSTEM, TURNS))
    assert result.urgent is True


# ---------- jawaban AI yang rusak ----------

@pytest.mark.parametrize("raw", [
    "bukan json",
    json.dumps({"reply": "   ", "urgent": False}),
    json.dumps({"reply": "hai"}),
    json.dumps({"reply": "hai", "urgent": False, "diagnosis": "x"}),
])
def test_bad_output_is_rejected(raw):
    with pytest.raises(AIBadOutput):
        run(AIGateway(FakeProvider(raw=raw)).reply(SYSTEM, TURNS))


# ---------- gangguan layanan ----------

def test_slow_provider_times_out():
    with pytest.raises(AITimeout):
        run(AIGateway(FakeProvider(delay=1), timeout_s=0.05).reply(SYSTEM, TURNS))


def test_provider_crash_becomes_unavailable_without_leaking_details():
    secret = RuntimeError("401 invalid key sk-rahasia")
    with pytest.raises(AIUnavailable) as exc:
        run(AIGateway(FakeProvider(error=secret)).reply(SYSTEM, TURNS))
    assert "sk-rahasia" not in exc.value.user_message


@pytest.mark.parametrize("err", [AIError, AITimeout, AIUnavailable, AIBadOutput])
def test_every_error_has_user_message(err):
    assert err().user_message.strip()


# ---------- GeminiProvider (client dipalsukan, tidak ada request sungguhan) ----------

class FakeModels:
    def __init__(self, text):
        self.text = text
        self.kwargs: dict[str, Any] = {}

    async def generate_content(self, **kwargs):
        self.kwargs = kwargs
        return SimpleNamespace(text=self.text)


def fake_client(text):
    models = FakeModels(text)
    client = SimpleNamespace(aio=SimpleNamespace(models=models))
    return cast(Any, client), models


def test_gemini_request_shape():
    client, models = fake_client(json.dumps({"reply": "ok", "urgent": False}))
    result = run(AIGateway(GeminiProvider(client, "model-x")).reply(SYSTEM, TURNS))
    assert result.reply == "ok"

    sent = models.kwargs
    assert sent["model"] == "model-x"
    # instruksi sistem terpisah, TIDAK masuk riwayat
    assert sent["config"].system_instruction == SYSTEM
    assert [c.role for c in sent["contents"]] == ["user", "model", "user"]
    assert sent["contents"][-1].parts[0].text == "Bayiku rewel"
    # jawaban dipaksa JSON sesuai skema
    assert sent["config"].response_mime_type == "application/json"
    assert sent["config"].response_json_schema["required"] == ["reply", "urgent"]


def test_gemini_empty_text_is_bad_output():
    client, _ = fake_client(None)
    with pytest.raises(AIBadOutput):
        run(AIGateway(GeminiProvider(client, "model-x")).reply(SYSTEM, TURNS))


# ---------- pengaturan ----------

def test_default_provider_is_fake(monkeypatch):
    monkeypatch.delenv("AI_PROVIDER", raising=False)
    gateway = build_gateway(AISettings(_env_file=None))
    assert isinstance(gateway.provider, FakeProvider)


def test_gemini_without_key_fails_fast():
    with pytest.raises(RuntimeError):
        build_gateway(AISettings(_env_file=None, ai_provider="gemini", gemini_api_key=None, gemini_model="m"))


def test_gemini_without_model_fails_fast():
    with pytest.raises(RuntimeError):
        build_gateway(AISettings(_env_file=None, ai_provider="gemini", gemini_api_key="k", gemini_model=None))


def test_api_key_is_never_printed():
    s = AISettings(_env_file=None, ai_provider="gemini", gemini_api_key="AIza-test-123", gemini_model="m")
    assert "AIza-test-123" not in repr(s) and "AIza-test-123" not in str(s.model_dump())
    assert isinstance(build_gateway(s).provider, GeminiProvider)