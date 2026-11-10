import pytest
from pydantic import ValidationError

from app.chat.schemas import MAX_MESSAGE_CHARS, ChatMessageOut, ChatRequest, ChatResponse

pytestmark = pytest.mark.local

SESSION_ID = "6f1c2a52-0d3e-4c1b-9a7e-2b9f4f0c1a11"

EXAMPLE_RESPONSE = {
    "session_id": SESSION_ID,
    "user_message": {
        "id": "0b6c7d2e-1111-4a2b-8c3d-000000000001",
        "role": "user",
        "content": "Aku capek banget hari ini",
        "created_at": "2026-11-10T13:00:00Z",
    },
    "reply": {
        "id": "0b6c7d2e-1111-4a2b-8c3d-000000000002",
        "role": "assistant",
        "content": "Wajar sekali merasa capek di masa ini...",
        "created_at": "2026-11-10T13:00:02Z",
    },
    "urgent": False,
    "context_used": ["mood_7d"],
}


def test_message_is_trimmed():
    req = ChatRequest.model_validate({"message": "  halo  "})
    assert req.message == "halo"
    assert req.session_id is None


@pytest.mark.parametrize("message", ["", "   ", "\n\t"])
def test_blank_message_is_rejected(message):
    with pytest.raises(ValidationError):
        ChatRequest.model_validate({"message": message})


def test_message_length_limit():
    ChatRequest.model_validate({"message": "a" * MAX_MESSAGE_CHARS})
    with pytest.raises(ValidationError):
        ChatRequest.model_validate({"message": "a" * (MAX_MESSAGE_CHARS + 1)})


def test_client_cannot_send_extra_fields():
    # mencegah aplikasi "menyamar" jadi jawaban AI atau mengirim role sendiri
    with pytest.raises(ValidationError):
        ChatRequest.model_validate({"message": "halo", "role": "assistant"})


def test_session_id_must_be_uuid():
    assert str(ChatRequest.model_validate({"message": "hi", "session_id": SESSION_ID}).session_id) == SESSION_ID
    with pytest.raises(ValidationError):
        ChatRequest.model_validate({"message": "hi", "session_id": "123"})


def test_documented_example_response_is_valid():
    res = ChatResponse.model_validate(EXAMPLE_RESPONSE)
    assert res.reply.role == "assistant"


def test_unknown_message_role_is_rejected():
    bad = dict(EXAMPLE_RESPONSE["reply"], role="system")
    with pytest.raises(ValidationError):
        ChatMessageOut.model_validate(bad)