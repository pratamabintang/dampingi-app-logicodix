import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]

SKIP_DIRS = {
    ".git",
    ".venv",
    "venv",
    "node_modules",
    ".pytest_cache",
    ".mypy_cache",
    "__pycache__",
    "htmlcov",
    ".scratch",
}

TEXT_SUFFIXES = {
    ".py",
    ".md",
    ".sql",
    ".http",
    ".json",
    ".txt",
    ".toml",
    ".ini",
    ".cfg",
    ".yaml",
    ".yml",
    ".example",
}

SECRET_PATTERNS = {
    "json-web-token": re.compile(
        r"eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}"
    ),
    "supabase-secret-key": re.compile(r"sb_secret_[A-Za-z0-9_-]{10,}"),
    "openai-key": re.compile(r"sk-[A-Za-z0-9]{20,}"),
    "anthropic-key": re.compile(r"sk-ant-[A-Za-z0-9_-]{10,}"),
}


def _scan_files():
    for path in ROOT.rglob("*"):
        if not path.is_file():
            continue
        if any(part in SKIP_DIRS for part in path.parts):
            continue
        name = path.name
        if name == ".env" or (name.startswith(".env.") and not name.endswith(".example")):
            continue  # git-ignored local credentials, never committed
        if path.suffix in TEXT_SUFFIXES or name == ".gitignore":
            yield path


def test_no_secret_shaped_string_in_the_source_tree():
    hits = []
    for path in _scan_files():
        text = path.read_text(encoding="utf-8", errors="ignore")
        for label, pattern in SECRET_PATTERNS.items():
            for match in pattern.finditer(text):
                shown = match.group(0)[:12]
                hits.append(f"{path.relative_to(ROOT)}: {label}: {shown}...")

    assert not hits, "secret-shaped strings found:\n" + "\n".join(hits)


def test_the_sample_request_access_token_is_a_placeholder():
    for path in sorted((ROOT / "http").glob("*.http")):
        for line in path.read_text(encoding="utf-8").splitlines():
            if line.strip().startswith("@access_token"):
                assert "eyJ" not in line, f"{path.name} carries a literal token"


def test_supabase_placeholders_in_env_examples_are_empty():
    for path in sorted(ROOT.rglob(".env.example")):
        for raw in path.read_text(encoding="utf-8").splitlines():
            line = raw.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, value = line.partition("=")
            if key.strip().startswith("SUPABASE"):
                assert value.strip() == "", (
                    f"{path.relative_to(ROOT)} sets {key.strip()}"
                )


def test_local_env_files_are_git_ignored():
    path = ROOT / ".gitignore"
    entries = {line.strip() for line in path.read_text(encoding="utf-8").splitlines()}
    assert ".env" in entries, f"{path} does not ignore .env"
