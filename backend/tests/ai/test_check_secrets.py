import base64
import importlib.util
import json
import subprocess
import zipfile
from pathlib import Path

import pytest

pytestmark = pytest.mark.local

ROOT = Path(__file__).resolve().parents[3]
_spec = importlib.util.spec_from_file_location("check_secrets", ROOT / "backend/scripts/check_secrets.py")
assert _spec and _spec.loader
cs = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(cs)

GEMINI = "AI" + "za" + "B" * 35
OPENAI = "s" + "k-proj-" + "a" * 30


def _jwt(payload: dict) -> str:
    def seg(obj):
        return base64.urlsafe_b64encode(json.dumps(obj).encode()).decode().rstrip("=")
    return f"{seg({'alg': 'HS256'})}.{seg(payload)}.{'s' * 20}"


def test_detects_keys_without_printing_them():
    found = cs.find_secrets(f"key={GEMINI}\nother={OPENAI}")
    assert {kind for kind, _ in found} == {"Google/Gemini API key", "OpenAI API key"}
    assert all(GEMINI not in val and OPENAI not in val for _, val in found)


def test_real_service_role_jwt_is_flagged_but_local_demo_is_not():
    real = _jwt({"role": "service_role", "iss": "supabase", "ref": "abcd"})
    demo = _jwt({"role": "service_role", "iss": "supabase-demo"})
    anon = _jwt({"role": "anon", "iss": "supabase"})
    assert [k for k, _ in cs.find_secrets(real)] == ["Supabase service_role JWT"]
    assert cs.find_secrets(demo) == [] and cs.find_secrets(anon) == []


def test_ordinary_text_is_not_flagged():
    assert cs.find_secrets("AI_PROVIDER=fake\nGEMINI_MODEL=gemini-3.1-flash-lite\nhubungi 119") == []


def test_env_example_must_not_contain_secret_values():
    bad = cs.env_example_problems("x/.env.example", f"GEMINI_API_KEY={GEMINI}\nGEMINI_MODEL=m")
    ok = cs.env_example_problems("x/.env.example", "GEMINI_API_KEY=\nGEMINI_MODEL=gemini-3.1-flash-lite")
    assert len(bad) == 1 and ok == []


def test_apk_scan_finds_key_and_direct_gemini_call(tmp_path):
    apk = tmp_path / "app.apk"
    with zipfile.ZipFile(apk, "w") as z:
        z.writestr("lib/libapp.so", f"https://generativelanguage.googleapis.com/ {GEMINI}".encode())
    kinds = {kind for _, kind, _ in cs.scan_apk(str(apk))}
    assert kinds == {"Google/Gemini API key", "aplikasi memanggil Gemini langsung"}


def test_repository_has_no_secrets(monkeypatch):
    """Penjaga regresi: kalau ada yang meng-commit kunci, tes ini gagal."""
    if subprocess.run(["git", "-C", str(ROOT), "rev-parse"], capture_output=True).returncode != 0:
        pytest.skip("bukan repository git")
    monkeypatch.chdir(ROOT)
    assert cs.scan_tracked() == []