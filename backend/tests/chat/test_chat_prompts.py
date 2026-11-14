import hashlib

import pytest

from app.ai.config import AISettings
from app.ai.providers import GeminiProvider
from app.chat import prompts
from app.chat.prompts import PROMPTS, build_system_prompt

pytestmark = pytest.mark.local

# versi -> sidik jari isi prompt. Ubah prompt = naikkan versi + perbarui baris di sini.
FROZEN = {
    "chat-mother-v4": "4719e030dfcc",
    "chat-companion-v4": "53224af856a8",
    "chat-mother-mood-v4": "9958524cc190",
}


def fingerprint(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()[:12]


@pytest.mark.parametrize("role", ["mother", "companion"])
def test_role_prompts_are_frozen(role):
    version, text = PROMPTS[role]
    assert FROZEN.get(version) == fingerprint(text), (
        f"Isi prompt {role} berubah. Naikkan versinya, lalu perbarui FROZEN: "
        f'"{version}": "{fingerprint(text)}"'
    )


def test_mood_rules_are_frozen():
    version, _ = build_system_prompt("mother", [{"date": "2026-11-09", "mood": 2}])
    assert FROZEN.get(version) == fingerprint(prompts._MOOD_RULES), (
        f'Aturan mood berubah. Naikkan versinya, lalu perbarui FROZEN: "{version}": '
        f'"{fingerprint(prompts._MOOD_RULES)}"'
    )


def test_every_version_is_unique():
    versions = [v for v, _ in PROMPTS.values()] + [build_system_prompt("mother", [{"date": "d", "mood": 3}])[0]]
    assert len(versions) == len(set(versions))


def test_tone_is_consistent():
    assert "'Bunda'" in PROMPTS["mother"][1] and "'aku'" in PROMPTS["mother"][1]
    assert "'kamu'" in PROMPTS["companion"][1] and "'aku'" in PROMPTS["companion"][1]


def test_demo_config_defaults_are_locked():
    s = AISettings(_env_file=None)
    assert s.ai_provider == "fake"            # tanpa .env: tidak memakai kuota
    assert s.ai_timeout_seconds == 20.0
    assert GeminiProvider.__init__.__defaults__ == (0.4,)  # temperature