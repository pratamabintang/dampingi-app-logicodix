"""
    python backend/scripts/check_secrets.py              # file yang di-track git
    python backend/scripts/check_secrets.py --history    # + seluruh riwayat commit
    python backend/scripts/check_secrets.py --apk app-release.apk

Keluar dengan kode 1 kalau ada temuan. Nilai yang ditemukan TIDAK dicetak utuh.
"""
import argparse
import base64
import json
import re
import subprocess
import sys
import zipfile
from pathlib import Path

PATTERNS = {
    "Google/Gemini API key": re.compile(r"AIza[0-9A-Za-z_\-]{35}"),
    "OpenAI API key": re.compile(r"\bsk-(?:proj-)?[A-Za-z0-9_\-]{20,}"),
    "Supabase secret key": re.compile(r"\bsb_secret_[A-Za-z0-9_\-]{10,}"),
}
JWT = re.compile(r"eyJ[A-Za-z0-9_\-]{10,}\.(eyJ[A-Za-z0-9_\-]{10,})\.[A-Za-z0-9_\-]{10,}")
SECRET_ENV_NAMES = ("GEMINI_API_KEY", "OPENAI_API_KEY", "AI_API_KEY", "SUPABASE_SECRET_KEY", "SUPABASE_SERVICE_ROLE_KEY")


def _mask(value: str) -> str:
    return value[:6] + "…" + f"({len(value)} karakter)"


def _jwt_payload(segment: str) -> dict:
    try:
        padded = segment + "=" * (-len(segment) % 4)
        return json.loads(base64.urlsafe_b64decode(padded))
    except ValueError:  # termasuk json.JSONDecodeError dan base64 yang rusak
        return {}


def find_secrets(text: str) -> list[tuple[str, str]]:
    """Kembalikan [(jenis, nilai tersamar)]."""
    found = [(kind, _mask(m.group(0))) for kind, rx in PATTERNS.items() for m in rx.finditer(text)]
    for m in JWT.finditer(text):
        payload = _jwt_payload(m.group(1))
        # Kunci service_role Supabase SUNGGUHAN berbahaya; kunci demo lokal (iss=supabase-demo) tidak.
        if payload.get("role") == "service_role" and payload.get("iss") != "supabase-demo":
            found.append(("Supabase service_role JWT", _mask(m.group(0))))
    return found


def env_example_problems(path: str, text: str) -> list[tuple[str, str]]:
    """`.env.example` hanya boleh berisi nama variabel rahasia, tanpa nilai."""
    problems = []
    for line in text.splitlines():
        name, sep, value = line.partition("=")
        if sep and name.strip() in SECRET_ENV_NAMES and value.strip():
            problems.append((f"{path}: {name.strip()} berisi nilai", _mask(value.strip())))
    return problems


def _git(*args: str) -> str:
    return subprocess.run(["git", *args], capture_output=True, text=True, check=True).stdout


def scan_tracked() -> list[tuple[str, str, str]]:
    results = []
    for path in _git("ls-files").splitlines():
        name = Path(path).name
        if re.fullmatch(r"\.env(\..+)?", name) and not name.endswith(".example"):
            results.append((path, ".env ikut di-commit", "-"))
            continue
        try:
            text = Path(path).read_text(encoding="utf-8")
        except (UnicodeDecodeError, FileNotFoundError, IsADirectoryError):
            continue
        results += [(path, kind, val) for kind, val in find_secrets(text)]
        if name.endswith(".env.example"):
            results += [(path, kind, val) for kind, val in env_example_problems(path, text)]
    return results


def scan_history() -> list[tuple[str, str, str]]:
    # Hanya baris yang DITAMBAHKAN di setiap commit (diawali "+").
    added = "\n".join(l[1:] for l in _git("log", "-p", "--all", "--no-color").splitlines()
                      if l.startswith("+") and not l.startswith("+++"))
    return [("riwayat git", kind, val) for kind, val in find_secrets(added)]


def scan_apk(apk: str) -> list[tuple[str, str, str]]:
    results = []
    with zipfile.ZipFile(apk) as z:
        for info in z.infolist():
            text = z.read(info).decode("latin-1")  # biner pun bisa dicari polanya
            results += [(f"{apk}:{info.filename}", kind, val) for kind, val in find_secrets(text)]
            if "generativelanguage.googleapis.com" in text:
                results.append((f"{apk}:{info.filename}", "aplikasi memanggil Gemini langsung", "-"))
    return results


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--history", action="store_true", help="periksa juga seluruh riwayat commit")
    parser.add_argument("--apk", help="periksa juga isi file APK")
    args = parser.parse_args()

    findings = scan_tracked()
    if args.history:
        findings += scan_history()
    if args.apk:
        findings += scan_apk(args.apk)

    if not findings:
        checked = ["file yang di-track"] + (["riwayat git"] if args.history else []) + ([args.apk] if args.apk else [])
        print("Aman: tidak ada kunci rahasia di " + ", ".join(checked) + ".")
        return 0
    print("DITEMUKAN kemungkinan rahasia:")
    for where, kind, val in findings:
        print(f"  - {where}: {kind} {val}")
    print("\nSegera cabut (revoke) kunci itu di dashboard penyedianya, lalu hapus dari kode.")
    return 1


if __name__ == "__main__":
    sys.exit(main())