"""Uji chatbot ujung ke ujung lewat HTTP ke backend yang SEDANG BERJALAN (lokal atau ter-host).

Memakai Supabase dan Gemini sungguhan (3 pesan = 3 jatah kuota). Pesan fiktif saja.

    CHAT_CHECK_URL=https://<backend>.onrender.com \\
    DEMO_MOTHER_EMAIL=... DEMO_MOTHER_PASSWORD=... \\
    DEMO_COMPANION_EMAIL=... DEMO_COMPANION_PASSWORD=... \\
    python backend/scripts/chat_live_check.py

Tambahkan `--register` untuk membuat akun demo kalau belum ada (Supabase LOKAL saja).
"""
import argparse
import os
import sys
import time

import httpx

LEAKS = ("AIza", "Traceback", "sb_secret_", "service_role")
results: list[tuple[bool, str]] = []


def check(ok: bool, title: str, detail: str = "") -> bool:
    results.append((ok, title))
    print(f"[{'OK' if ok else 'GAGAL'}] {title}" + (f"\n      {detail}" if detail else ""))
    return ok


def no_leak(resp: httpx.Response) -> bool:
    return not any(s in resp.text for s in LEAKS)


def login(client: httpx.Client, who: str, role: str, register: bool) -> str | None:
    email, password = os.getenv(f"DEMO_{who}_EMAIL"), os.getenv(f"DEMO_{who}_PASSWORD")
    if not email or not password:
        print(f"[LEWAT] login {who.lower()}: DEMO_{who}_EMAIL / DEMO_{who}_PASSWORD belum diisi")
        return None
    r = client.post("/auth/login", json={"email": email, "password": password})
    if r.status_code != 200 and register:
        client.post("/auth/register", json={"name": f"Demo {who.title()}", "email": email,
                                            "password": password, "role": role})
        r = client.post("/auth/login", json={"email": email, "password": password})
    check(r.status_code == 200, f"login {who.lower()}", "" if r.status_code == 200 else f"{r.status_code} {r.text[:200]}")
    return r.json()["access_token"] if r.status_code == 200 else None


def run(client: httpx.Client, register: bool = False) -> int:
    r = client.get("/health")
    check(r.status_code == 200, "backend hidup (/health)", r.text[:200])

    r = client.post("/chat", json={"message": "halo"})
    check(r.status_code == 401 and no_leak(r), "tanpa login ditolak (401)")

    mother = login(client, "MOTHER", "mother", register)
    if not mother:
        return summary()
    auth = {"Authorization": f"Bearer {mother}"}

    start = time.perf_counter()
    r = client.post("/chat", headers=auth,
                    json={"message": "Halo, aku baru melahirkan dua minggu lalu dan sering capek."})
    took = time.perf_counter() - start
    ok = check(r.status_code == 200 and no_leak(r), f"ibu: pesan pertama dijawab AI ({took:.1f} dtk)",
               r.json()["reply"]["content"] if r.status_code == 200 else f"{r.status_code} {r.text[:200]}")
    if not ok:
        return summary()
    body = r.json()
    sid = body["session_id"]
    print(f"      context_used={body['context_used']} urgent={body['urgent']}")

    r = client.post("/chat", headers=auth, json={"message": "Bayiku juga sering bangun malam.", "session_id": sid})
    check(r.status_code == 200, "ibu: lanjut percakapan yang sama")

    r = client.get("/chat/sessions", headers=auth)
    check(r.status_code == 200 and any(s["id"] == sid for s in r.json()["sessions"]), "ibu: sesi muncul di daftar")

    r = client.get(f"/chat/sessions/{sid}/messages", headers=auth)
    check(r.status_code == 200 and r.json()["count"] >= 4, "ibu: riwayat tersimpan (≥ 4 pesan)")

    r = client.post("/chat", headers=auth, json={"message": "   "})
    check(r.status_code == 422, "pesan kosong ditolak (422)")

    companion = login(client, "COMPANION", "companion", register)
    if companion:
        cauth = {"Authorization": f"Bearer {companion}"}
        r = client.get(f"/chat/sessions/{sid}/messages", headers=cauth)
        check(r.status_code == 404 and no_leak(r), "pendamping TIDAK bisa membaca chat ibu (404)")
        r = client.post("/chat", headers=cauth, json={"message": "halo", "session_id": sid})
        check(r.status_code == 404, "pendamping TIDAK bisa menulis ke chat ibu (404)")
        r = client.post("/chat", headers=cauth, json={"message": "Bagaimana cara mendukung istriku yang baru melahirkan?"})
        check(r.status_code == 200 and r.json()["context_used"] == [], "pendamping: dijawab AI tanpa data ibu")

    return summary()


def summary() -> int:
    failed = [t for ok, t in results if not ok]
    print(f"\n{len(results) - len(failed)}/{len(results)} OK." + (f" Gagal: {', '.join(failed)}" if failed else ""))
    return 1 if failed else 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--register", action="store_true", help="buat akun demo kalau login gagal (lokal saja)")
    args = parser.parse_args()
    base = os.getenv("CHAT_CHECK_URL", "http://127.0.0.1:8000").rstrip("/")
    print(f"Backend: {base}\n")
    with httpx.Client(base_url=base, timeout=40) as client:
        return run(client, register=args.register)


if __name__ == "__main__":
    sys.exit(main())