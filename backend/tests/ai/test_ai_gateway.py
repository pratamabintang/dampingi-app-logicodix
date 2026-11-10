import asyncio
import json
from types import SimpleNamespace
from typing import Any, cast

import pytest

from app.ai import AIBadOutput, AIError, AIGateway, AITimeout, AIUnavailable, Turn
from app.ai.config import AISettings, build_gateway
from app.ai.providers import FakeProvider, OpenAIProvider

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


# ---------- OpenAIProvider (client dipalsukan, tidak ada request sungguhan) ----------

class FakeCompletions:
    def __init__(self, content):
        self.content = content
        self.kwargs: dict[str, Any] = {}

    async def create(self, **kwargs):
        self.kwargs = kwargs
        msg = SimpleNamespace(content=self.content)
        return SimpleNamespace(choices=[SimpleNamespace(message=msg)])


def fake_client(content):
    completions = FakeCompletions(content)
    client = SimpleNamespace(chat=SimpleNamespace(completions=completions))
    return cast(Any, client), completions


def test_openai_request_shape():
    client, completions = fake_client(json.dumps({"reply": "ok", "urgent": False}))
    result = run(AIGateway(OpenAIProvider(client, "model-x")).reply(SYSTEM, TURNS))
    assert result.reply == "ok"

    sent = completions.kwargs
    assert sent["model"] == "model-x"
    assert sent["messages"][0] == {"role": "system", "content": SYSTEM}
    assert [m["role"] for m in sent["messages"][1:]] == ["user", "assistant", "user"]
    assert sent["response_format"]["json_schema"]["strict"] is True


def test_openai_empty_content_is_bad_output():
    client, _ = fake_client(None)
    with pytest.raises(AIBadOutput):
        run(AIGateway(OpenAIProvider(client, "model-x")).reply(SYSTEM, TURNS))


# ---------- pengaturan ----------

def test_default_provider_is_fake(monkeypatch):
    monkeypatch.delenv("AI_PROVIDER", raising=False)
    gateway = build_gateway(AISettings(_env_file=None))
    assert isinstance(gateway.provider, FakeProvider)


def test_openai_without_key_fails_fast():
    with pytest.raises(RuntimeError):
        build_gateway(AISettings(_env_file=None, ai_provider="openai", openai_api_key=None, openai_model="m"))


def test_api_key_is_never_printed():
    s = AISettings(_env_file=None, ai_provider="openai", openai_api_key="sk-test-123", openai_model="m")
    assert "sk-test-123" not in repr(s) and "sk-test-123" not in str(s.model_dump())
    assert isinstance(build_gateway(s).provider, OpenAIProvider)