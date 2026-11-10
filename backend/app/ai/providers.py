import asyncio
import json

from openai import AsyncOpenAI
from openai.types.chat import (
    ChatCompletionAssistantMessageParam,
    ChatCompletionMessageParam,
    ChatCompletionSystemMessageParam,
    ChatCompletionUserMessageParam,
)
from openai.types.shared_params import ResponseFormatJSONSchema

from .errors import AIBadOutput
from .gateway import REPLY_JSON_SCHEMA, Turn


class FakeProvider:
    """Mengembalikan jawaban yang sudah ditentukan. `calls` mencatat apa yang dikirim."""

    def __init__(
        self,
        reply: str = "Terima kasih sudah bercerita. Aku di sini untuk menemanimu.",
        *,
        urgent: bool = False,
        raw: str | None = None,
        error: Exception | None = None,
        delay: float = 0.0,
    ):
        self.reply = reply
        self.urgent = urgent
        self.raw = raw
        self.error = error
        self.delay = delay
        self.calls: list[tuple[str, list[Turn]]] = []

    async def complete(self, system: str, turns: list[Turn]) -> str:
        self.calls.append((system, list(turns)))
        if self.delay:
            await asyncio.sleep(self.delay)
        if self.error:
            raise self.error
        if self.raw is not None:
            return self.raw
        return json.dumps({"reply": self.reply, "urgent": self.urgent})


def _to_message(turn: Turn) -> ChatCompletionMessageParam:
    if turn.role == "assistant":
        return ChatCompletionAssistantMessageParam(role="assistant", content=turn.content)
    return ChatCompletionUserMessageParam(role="user", content=turn.content)


class OpenAIProvider:
    def __init__(self, client: AsyncOpenAI, model: str):
        self.client = client
        self.model = model

    async def complete(self, system: str, turns: list[Turn]) -> str:
        messages: list[ChatCompletionMessageParam] = [
            ChatCompletionSystemMessageParam(role="system", content=system)
        ]
        messages += [_to_message(t) for t in turns]

        response_format = ResponseFormatJSONSchema(
            type="json_schema",
            json_schema={"name": "chat_reply", "strict": True, "schema": REPLY_JSON_SCHEMA},
        )
        resp = await self.client.chat.completions.create(
            model=self.model, messages=messages, response_format=response_format
        )
        content = resp.choices[0].message.content
        if not content:  # misalnya model menolak menjawab (refusal)
            raise AIBadOutput()
        return content
