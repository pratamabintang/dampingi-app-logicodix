import os
import platform
import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BACKEND = ROOT / "backend"
REPORTS = ROOT / "docs" / "testing" / "reports"
sys.path.insert(0, str(BACKEND))


def run(cmd: list[str], cwd: Path = ROOT) -> tuple[int, str]:
    proc = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    return proc.returncode, (proc.stdout + proc.stderr).strip()


def last_line(output: str) -> str:
    lines = [l for l in output.splitlines() if l.strip()]
    return lines[-1].strip("= ") if lines else "(tanpa output)"


def env_value(name: str) -> str:
    """Baca nilai dari backend/.env tanpa mencetak isinya."""
    env = BACKEND / ".env"
    if not env.exists():
        return ""
    for line in env.read_text(encoding="utf-8").splitlines():
        key, sep, value = line.partition("=")
        if sep and key.strip() == name:
            return value.strip().strip("'\"")
    return ""


def main() -> int:
    from app.chat.prompts import PROMPTS, build_system_prompt

    py = sys.executable
    steps: list[tuple[str, str, str]] = []  # (langkah, status, ringkasan)
    details: list[tuple[str, str]] = []

    def record(name: str, code: int | None, output: str, summary: str | None = None):
        status = "tidak dijalankan" if code is None else ("lulus" if code == 0 else "**GAGAL**")
        steps.append((name, status, summary or last_line(output)))
        if code not in (None, 0):
            details.append((name, output[-3000:]))
        print(f"[{status}] {name}: {summary or last_line(output)}")

    code, out = run([py, "-m", "pytest", "backend/tests/chat", "backend/tests/ai", "-q", "-p", "no:cacheprovider"])
    record("Tes chat + AI (offline)", code, out)

    code, out = run([py, "-m", "pytest", "-q", "-m", "local", "-p", "no:cacheprovider"])
    record("Semua tes offline tim (`-m local`)", code, out)

    code, out = run([py, "backend/scripts/check_secrets.py", "--history"])
    record("Rahasia di repo + riwayat", code, out)

    if env_value("AI_PROVIDER") == "gemini":
        code, out = run([py, "scripts/ai_smoke.py"], cwd=BACKEND)
        ok = len(re.findall(r"^\[OK\]", out, re.M))
        total = len(re.findall(r"^\[(OK|CEK|GAGAL)\]", out, re.M))
        record("Smoke test Gemini (perilaku model)", code, out, f"{ok}/{total} OK")
    else:
        record("Smoke test Gemini (perilaku model)", None, "", "AI_PROVIDER di backend/.env bukan gemini")

    if os.getenv("CHAT_CHECK_URL"):
        code, out = run([py, "backend/scripts/chat_live_check.py"])
        record(f"Uji HTTP ke {os.environ['CHAT_CHECK_URL']}", code, out)
    else:
        record("Uji HTTP ke backend berjalan", None, "", "CHAT_CHECK_URL belum diisi")

    _, commit = run(["git", "rev-parse", "--short", "HEAD"])
    _, dirty = run(["git", "status", "--porcelain", "--untracked-files=no"])
    versions = [v for v, _ in PROMPTS.values()] + [build_system_prompt("mother", [{"date": "d", "mood": 3}])[0]]
    now = datetime.now().astimezone()

    lines = [
        f"# Laporan regresi chatbot — {now:%Y-%m-%d %H:%M %Z}",
        "",
        f"- Commit: `{commit}`" + (" (ada perubahan belum di-commit)" if dirty else ""),
        f"- Python: {platform.python_version()}",
        f"- Model: `{env_value('GEMINI_MODEL') or '(tidak diisi)'}`",
        f"- Versi prompt: {', '.join(f'`{v}`' for v in versions)}",
        "",
        "| Langkah | Status | Ringkasan |",
        "|---|---|---|",
        *[f"| {n} | {s} | {r.replace('|', '/')} |" for n, s, r in steps],
        "",
    ]
    for name, out in details:
        lines += [f"## Kegagalan: {name}", "", "```", out, "```", ""]

    REPORTS.mkdir(parents=True, exist_ok=True)
    report = REPORTS / f"chat-{now:%Y-%m-%d}.md"
    report.write_text("\n".join(lines), encoding="utf-8")
    print(f"\nLaporan: {report.relative_to(ROOT)}")
    return 1 if any(s == "**GAGAL**" for _, s, _ in steps) else 0


if __name__ == "__main__":
    sys.exit(main())