import asyncio
import json
from types import SimpleNamespace
from typing import Any, cast

import pytest
from pydantic import BaseModel, ConfigDict, Field

from app.ai import AIBadOutput, AIGateway, AIReply, AITimeout, Turn, json_schema_for
from app.ai.gateway import REPLY_JSON_SCHEMA
from app.ai.providers import FakeProvider, GeminiProvider

pytestmark = pytest.mark.local


class SummaryLike(BaseModel):
    """Meniru `SummaryOutput` milik D."""

    model_config = ConfigDict(extra="forbid")
    overview: str = Field(min_length=1)


TURNS = [Turn("user", '{"moods": [{"date": "2026-11-09", "mood": 2}]}')]


def run(coro):
    return asyncio.run(coro)


def test_generate_returns_typed_object():
    provider = FakeProvider(response={"overview": "Minggu ini mood cenderung rendah."})
    result = run(AIGateway(provider).generate("ringkas", TURNS, SummaryLike))
    assert isinstance(result, SummaryLike)
    assert result.overview == "Minggu ini mood cenderung rendah."


def test_schema_is_derived_from_the_model():
    provider = FakeProvider(response={"overview": "x"})
    run(AIGateway(provider).generate("ringkas", TURNS, SummaryLike))
    sent = provider.schemas[-1]
    assert sent["required"] == ["overview"]
    assert sent["additionalProperties"] is False   # extra="forbid" ikut terbawa
    assert "title" not in json.dumps(sent)          # title dibuang


def test_custom_schema_overrides_the_derived_one():
    provider = FakeProvider(response={"overview": "x"})
    custom = {"type": "object", "properties": {"overview": {"type": "string"}}, "required": ["overview"]}
    run(AIGateway(provider).generate("ringkas", TURNS, SummaryLike, schema=custom))
    assert provider.schemas[-1] is custom


@pytest.mark.parametrize("bad", [{"overview": ""}, {"summary": "x"}, {"overview": "x", "diagnosis": "y"}])
def test_output_not_matching_the_model_is_bad_output(bad):
    with pytest.raises(AIBadOutput):
        run(AIGateway(FakeProvider(response=bad)).generate("ringkas", TURNS, SummaryLike))


def test_timeout_and_errors_apply_to_generate_too():
    gateway = AIGateway(FakeProvider(response={"overview": "x"}, delay=1), timeout_s=0.05)
    with pytest.raises(AITimeout):
        run(gateway.generate("ringkas", TURNS, SummaryLike))


def test_reply_still_uses_the_chat_schema():
    provider = FakeProvider("halo")
    result = run(AIGateway(provider).reply("s", TURNS))
    assert isinstance(result, AIReply) and result.reply == "halo"
    assert provider.schemas[-1] is REPLY_JSON_SCHEMA


def test_gemini_receives_the_requested_schema():
    class Models:
        kwargs: dict[str, Any] = {}

        async def generate_content(self, **kwargs):
            Models.kwargs = kwargs
            return SimpleNamespace(text=json.dumps({"overview": "ok"}))

    client = cast(Any, SimpleNamespace(aio=SimpleNamespace(models=Models())))
    result = run(AIGateway(GeminiProvider(client, "m")).generate("ringkas", TURNS, SummaryLike))
    assert result.overview == "ok"
    assert Models.kwargs["config"].response_json_schema == json_schema_for(SummaryLike)
    assert Models.kwargs["config"].system_instruction == "ringkas"