"""Data tambahan untuk chatbot (C04): mood harian ibu.

Prinsip:
- Hanya ibu, hanya datanya sendiri. Pendamping tidak pernah mendapat data ibu lewat chat.
- Minimasi data: hanya tanggal + skala 1-5. Kolom `description` (teks bebas) tidak ikut,
  supaya isi catatan pribadi tidak terkirim ke AI dan tidak bisa dipakai menyisipkan perintah.
- Kalau gagal mengambil data, chat tetap jalan tanpa konteks.
"""
import asyncio
import logging
from datetime import date, datetime, timedelta, timezone
from typing import Callable, Protocol

logger = logging.getLogger(__name__)

MOOD_DAYS = 7
MOOD_CONTEXT = "mood_7d"  # label yang dikirim ke aplikasi (transparansi)


def _utc_today() -> date:
    return datetime.now(timezone.utc).date()


class MoodSource(Protocol):
    async def recent(self, user_id: str) -> list[dict]: ...


class SupabaseMoodSource:
    """Membaca tabel moods lewat fungsi milik B."""

    def __init__(self, today: Callable[[], date] = _utc_today):
        self.today = today  # bisa diganti di tes supaya tanggalnya pasti

    async def recent(self, user_id: str) -> list[dict]:
        return await asyncio.to_thread(self._recent, user_id)

    def _recent(self, user_id: str) -> list[dict]:
        from app.moods import supabase as moods_sb

        # Mulai 7 hari lalu (UTC). Kelebihan satu hari di zona WIB/WITA/WIT tidak masalah,
        # karena yang diambil tetap maksimal 7 entri terbaru.
        start = (self.today() - timedelta(days=MOOD_DAYS)).isoformat()
        rows, _total = moods_sb.list_moods(user_id, start_date=start)  # B: terbaru dulu
        latest = rows[:MOOD_DAYS]
        return [{"date": str(r["created_at"]), "mood": int(r["mood"])} for r in reversed(latest)]


async def mother_moods(source: MoodSource | None, user_id: str, role: str) -> list[dict]:
    """Mood untuk konteks chat. Selalu [] untuk selain ibu atau kalau terjadi error."""
    if source is None or role != "mother":
        return []
    try:
        return await source.recent(user_id)
    except Exception as exc:
        logger.warning("Mood context dilewati: %s", type(exc).__name__)
        return []