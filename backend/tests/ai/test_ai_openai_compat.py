"""Tes provider pihak ketiga (protokol OpenAI). Tanpa jaringan: httpx dipalsukan."""

import asyncio
import json
from typing import Any, cast

import httpx
import pytest
from pydantic import ValidationError

from app.ai import AIBadOutput, AIBusy, AIGateway, AITimeout, AIUnavailable, Turn
from app.ai.config import AISettings, build_gateway
from app.ai.gateway import REPLY_JSON_SCHEMA
from app.ai.providers import OpenAICompatProvider

pytestmark = pytest.mark.local

SYSTEM = "Kamu pendamping ibu pascamelahirkan."
TURNS = [Turn("user", "Aku capek"), Turn("assistant", "Ceritakan ya")]
MODEL = "deepseek-v4.1-flash"
OK_PAYLOAD = {"choices": [{"message": {"role": "assistant", "content": json.dumps({"reply": "ok", "urgent": False})}}]}


def run(coro):
    return asyncio.run(coro)


class FakeClient:
    """Meniru httpx.AsyncClient: mencatat request, membalas sesuai yang diminta tes."""

    def __init__(self, status: int = 200, payload: dict | None = None, error: Exception | None = None, raw: bytes | None = None):
        self.status = status
        self.payload = OK_PAYLOAD if payload is None else payload
        self.error = error
        self.raw = raw
        self.url: str | None = None
        self.body: dict[str, Any] = {}

    async def post(self, url, json=None):  # noqa: A002 - nama argumen mengikuti httpx
        self.url = url
        self.body = json or {}
        if self.error:
            raise self.error
        request = httpx.Request("POST", f"https://gateway.test/v1/{url}")
        if self.raw is not None:
            return httpx.Response(self.status, content=self.raw, request=request)
        return httpx.Response(self.status, json=self.payload, request=request)


def provider(client: FakeClient) -> OpenAICompatProvider:
    return OpenAICompatProvider(cast(Any, client), MODEL)


# ---------- bentuk request ----------

def test_request_shape_follows_the_openai_protocol():
    client = FakeClient()
    result = run(AIGateway(provider(client)).reply(SYSTEM, TURNS))

    assert result.reply == "ok"
    assert client.url == "chat/completions"
    assert client.body["model"] == MODEL
    assert client.body["response_format"] == {"type": "json_object"}  # tanpa ini jawaban berpagar ```json
    assert [m["role"] for m in client.body["messages"]] == ["system", "user", "assistant"]
    assert client.body["messages"][1]["content"] == "Aku capek"


def test_schema_is_carried_in_the_system_message_only():
    client = FakeClient()
    run(AIGateway(provider(client)).reply(SYSTEM, TURNS))

    system_message = client.body["messages"][0]["content"]
    assert SYSTEM in system_message
    assert json.dumps(REPLY_JSON_SCHEMA, separators=(",", ":")) in system_message
    assert all("required" not in str(m["content"]) for m in client.body["messages"][1:])


def test_requested_schema_is_what_the_caller_asked_for():
    from pydantic import BaseModel, ConfigDict

    class SummaryLike(BaseModel):
        model_config = ConfigDict(extra="forbid")
        overview: str

    client = FakeClient(payload={"choices": [{"message": {"content": json.dumps({"overview": "ringkas"})}}]})
    result = run(AIGateway(provider(client)).generate("ringkas", TURNS, SummaryLike))
    assert result.overview == "ringkas"
    assert '"required":["overview"]' in client.body["messages"][0]["content"]


# ---------- jawaban rusak ----------

@pytest.mark.parametrize("payload", [
    {"choices": [{"message": {"content": ""}}]},
    {"choices": [{"message": {"content": None}}]},
    {"choices": [{"message": {"content": "   "}}]},
    {"choices": []},
    {"error": {"message": "gagal"}},
    {},
])
def test_unusable_body_is_bad_output(payload):
    with pytest.raises(AIBadOutput):
        run(AIGateway(provider(FakeClient(payload=payload))).reply(SYSTEM, TURNS))


def test_non_json_body_is_bad_output():
    with pytest.raises(AIBadOutput):
        run(AIGateway(provider(FakeClient(raw=b"<html>502 bad gateway</html>"))).reply(SYSTEM, TURNS))


def test_content_sent_as_parts_is_joined():
    payload = {"choices": [{"message": {"content": [{"type": "text", "text": '{"reply": "ha'}, {"type": "text", "text": 'i", "urgent": false}'}]}}]}
    result = run(AIGateway(provider(FakeClient(payload=payload))).reply(SYSTEM, TURNS))
    assert result.reply == "hai"


def test_gateway_still_rejects_json_that_misses_the_schema():
    payload = {"choices": [{"message": {"content": json.dumps({"reply": "hai", "diagnosis": "x"})}}]}
    with pytest.raises(AIBadOutput):
        run(AIGateway(provider(FakeClient(payload=payload))).reply(SYSTEM, TURNS))


# ---------- gangguan layanan ----------

@pytest.mark.parametrize("status,expected", [
    (429, AIBusy),
    (504, AITimeout),
    (500, AIUnavailable),
    (404, AIUnavailable),
    (401, AIUnavailable),
])
def test_http_status_is_translated(status, expected):
    with pytest.raises(expected):
        run(AIGateway(provider(FakeClient(status=status))).reply(SYSTEM, TURNS))


def test_unreachable_gateway_is_unavailable():
    with pytest.raises(AIUnavailable):
        run(AIGateway(provider(FakeClient(error=httpx.ConnectError("dns mati")))).reply(SYSTEM, TURNS))


def test_slow_gateway_is_a_timeout():
    with pytest.raises(AITimeout):
        run(AIGateway(provider(FakeClient(error=httpx.ReadTimeout("lambat")))).reply(SYSTEM, TURNS))


def test_error_message_never_leaks_the_request():
    error = httpx.ConnectError("gagal ke https://gateway.test/v1?key=sk-rahasia")
    with pytest.raises(AIUnavailable) as exc:
        run(AIGateway(provider(FakeClient(error=error))).reply(SYSTEM, TURNS))
    assert "sk-rahasia" not in exc.value.user_message


# ---------- pengaturan ----------

BASE = "https://gateway.test/v1"


def settings(**overrides):
    base = {"ai_provider": "openai_compatible", "ai_api_key": "sk-gw-test", "ai_base_url": BASE, "ai_model": MODEL}
    return AISettings(_env_file=None, **{**base, **overrides})


def test_configured_provider_is_built():
    gateway = build_gateway(settings())
    assert isinstance(gateway.provider, OpenAICompatProvider)


def test_client_points_at_the_gateway_and_sends_the_bearer_token():
    client = build_gateway(settings()).provider.client
    assert str(client.base_url) == BASE + "/"  # "chat/completions" menempel di ujung ini
    assert client.headers["Authorization"] == "Bearer sk-gw-test"


def test_trailing_slash_in_the_base_url_is_not_doubled():
    client = build_gateway(settings(ai_base_url=BASE + "/")).provider.client
    assert str(client.base_url) == BASE + "/"


@pytest.mark.parametrize("missing", [
    {"ai_api_key": None},
    {"ai_base_url": None},
    {"ai_base_url": ""},
    {"ai_model": None},
    {"ai_model": ""},
])
def test_incomplete_settings_fail_fast(missing):
    with pytest.raises(RuntimeError):
        build_gateway(settings(**missing))


def test_unknown_provider_name_is_rejected():
    with pytest.raises(ValidationError):
        AISettings(_env_file=None, ai_provider="openai")


def test_third_party_key_is_never_printed():
    s = settings()
    assert "sk-gw-test" not in repr(s) and "sk-gw-test" not in str(s.model_dump())


def test_gemini_and_fake_still_work():
    from app.ai.providers import FakeProvider, GeminiProvider

    assert isinstance(build_gateway(AISettings(_env_file=None)).provider, FakeProvider)
    gemini = build_gateway(AISettings(_env_file=None, ai_provider="gemini", gemini_api_key="k", gemini_model="m"))
    assert isinstance(gemini.provider, GeminiProvider)
