# dampingi-app-logicodix

## Penggunaan AI

### Fitur yang memakai AI

| Fitur | Layanan / model | Kode | Data yang dikirim ke AI |
|---|---|---|---|
| **Teman Dampingi** (chatbot untuk ibu dan pendamping) | Google Gemini API, model dari `GEMINI_MODEL` (default `gemini-3.1-flash-lite`), SDK `google-genai` | `backend/app/ai/`, `backend/app/chat/` | Pesan pengguna; maksimal 10 pesan riwayat (≤ 6.000 karakter) dari percakapan yang sama; khusus ibu: maksimal 7 entri mood terakhir **miliknya sendiri** (tanggal + skala 1–5 saja) |
| **Ringkasan mingguan** | Google Gemini API (`GEMINI_MODEL`), SDK `google-genai` | `backend/app/summaries/`, `backend/app/journals/extraction.py` | Data tanggal dan skala mood ibu serta tema jurnal hasil ekstraksi. Konten mentah jurnal tidak diteruskan ke AI pembuat ringkasan. |

Kunci API (`GEMINI_API_KEY`) hanya ada di server (`backend/.env`). Aplikasi mobile tidak pernah memanggil AI langsung.

### Pengaman pada chatbot

- **Bukan diagnosis.** Instruksi sistem melarang diagnosis serta nama/dosis obat, dan mengarahkan keluhan medis ke bidan, dokter, atau puskesmas (`backend/app/chat/prompts.py`).
- **Tanda bahaya.** AI wajib mengisi `urgent: true` bila ada tanda bahaya (pikiran menyakiti diri/bayi, perdarahan hebat, dll.). Aplikasi lalu menampilkan kontak darurat (119 / IGD terdekat).
- **Jawaban terstruktur dan diperiksa.** Gemini diminta menjawab dengan skema JSON `{reply, urgent}`; backend memeriksa ulang dengan Pydantic. Jawaban yang tidak sesuai tidak pernah sampai ke pengguna.
- **Gagal dengan aman.** Bila AI lambat (> 20 dtk) atau error, pengguna menerima pesan ramah (503) dan **tidak ada yang tersimpan**, sehingga bisa langsung kirim ulang.
- **Batas pemakaian.** Maksimal 50 pesan per pengguna per 24 jam (`CHAT_DAILY_LIMIT`) dan satu pesan dalam proses per pengguna (429), supaya kuota tetap tersedia.
- **Transparansi.** Setiap jawaban membawa `context_used` (mis. `["mood_7d"]`) sehingga aplikasi bisa memberi tahu ibu data apa yang ikut dipakai.

### Data dan privasi

### Data dan privasi

- **Jurnal tidak dikirim ke chatbot.** Untuk weekly summary, isi jurnal ibu diproses oleh AI khusus untuk mengekstrak tema. Konten mentah jurnal tidak diteruskan ke AI pembuat ringkasan.
- Catatan teks pada mood (`description`) tidak dikirim ke AI.
- Ringkasan mingguan hanya menggunakan data milik ibu yang terautentikasi.
- Pendamping tidak mendapat data jurnal pribadi ibu tanpa persetujuan eksplisit.
- Riwayat chat disimpan di Supabase (`chat_sessions`, `chat_messages`) dengan RLS aktif; hanya backend yang mengaksesnya, dan setiap query difilter per pemilik.
- Tier Gemini API yang dipakai saat penilaian: **(isi: gratis / berbayar)**. Pada tier gratis, Google dapat memakai dan meninjau isi permintaan untuk mengembangkan produknya, sehingga demo memakai akun dan isi **fiktif**.

### Cara mencoba dengan Gemini sungguhan

1. Isi `backend/.env`: `AI_PROVIDER=gemini`, `GEMINI_API_KEY=...`, `GEMINI_MODEL=gemini-3.1-flash-lite`.
2. Dari folder `backend`: `python scripts/ai_smoke.py` (5 skenario fiktif: biasa, memakai mood, tanda bahaya, pendamping, prompt injection).

Tanpa kunci, `AI_PROVIDER=fake` (default) memberi jawaban tetap tanpa biaya; seluruh tes (`pytest -m local`) memakai mode ini dan tidak memanggil AI.

### AI dalam proses pengembangan

Tim memakai AI coding assistant **(isi: nama alat, mis. Claude)** untuk membantu menulis, menjelaskan, dan meninjau kode. Seluruh kode ditinjau, diuji, dan dipahami oleh anggota tim.

## Weekly Summary API

**Endpoint**

`POST /summaries/weekly`

**Request Body**

| Field | Type | Description |
|---|---|---|
| `period_start` | `date` | Tanggal awal periode. Harus hari Senin. |

**Response**

| Field | Type | Description |
|---|---|---|
| `period_start` | `date` | Tanggal awal periode. |
| `period_end` | `date` | Tanggal akhir periode, yaitu enam hari setelah `period_start`. |
| `audience` | `string` | Penerima ringkasan, saat ini `mother`. |
| `status` | `string` | Status pemrosesan ringkasan. |
| `overview` | `string` atau `null` | Ringkasan mingguan yang dihasilkan AI. |
| `limitations` | `array[string]` | Keterbatasan atau data yang tidak tersedia selama periode tersebut. |
| `source_refs` | `array` | Referensi ID sumber data yang digunakan dalam ringkasan. |
| `prompt_version` | `string` | Versi prompt AI yang digunakan. |

**Contoh Request**

```json
{
  "period_start": "2026-11-09"
}
```

**Contoh Response**

```json
{
  "period_start": "2026-11-09",
  "period_end": "2026-11-15",
  "audience": "mother",
  "status": "completed",
  "overview": "Ringkasan kondisi ibu selama satu minggu.",
  "limitations": [
    "Catatan mood tersedia pada 3 dari 7 hari."
  ],
  "source_refs": [
    {
      "source_type": "mother_mood",
      "source_id": "mood-1"
    }
  ],
  "prompt_version": "weekly-summary-v2"
}
```

**Catatan**

- Periode ringkasan selalu tujuh hari dan harus dimulai pada hari Senin.
- Ringkasan dapat menggunakan data mood dan tema jurnal yang berhasil diekstrak.
- Konten mentah jurnal tidak diteruskan ke AI pembuat ringkasan.
- Ringkasan bersifat informatif dan bukan diagnosis klinis.
- Evaluasi klinis EPDS belum diaktifkan.