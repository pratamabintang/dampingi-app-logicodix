# API Chatbot Dampingi

Kontrak antara backend (FastAPI) dan aplikasi Flutter untuk fitur chatbot.
Bentuk data persisnya ada di `backend/app/chat/schemas.py`.

## Aturan umum

- Semua endpoint wajib `Authorization: Bearer <access_token>` dari login.
- Yang boleh chat: role `mother` dan `companion`. Role lain dapat `403`.
- Error selalu berbentuk `{"detail": "..."}` (pesan siap ditampilkan ke pengguna),
  kecuali `422` yang `detail`-nya berupa daftar kesalahan validasi.
- Kunci API AI hanya ada di server. Aplikasi tidak pernah memanggil AI langsung.

## Endpoint

### `POST /chat`

Kirim pesan dan terima jawaban AI.

Request:
```json
{ "message": "Aku capek banget hari ini", "session_id": null }
```
- `message`: 1–2000 karakter, spasi di awal/akhir dibuang, tidak boleh kosong.
- `session_id`: opsional. Kosong = percakapan baru; isi = lanjutkan percakapan itu.
- Field lain ditolak (`422`).

Response `200`:
```json
{
  "session_id": "6f1c2a52-0d3e-4c1b-9a7e-2b9f4f0c1a11",
  "user_message": {
    "id": "0b6c7d2e-1111-4a2b-8c3d-000000000001",
    "role": "user",
    "content": "Aku capek banget hari ini",
    "created_at": "2026-11-10T13:00:00Z"
  },
  "reply": {
    "id": "0b6c7d2e-1111-4a2b-8c3d-000000000002",
    "role": "assistant",
    "content": "Wajar sekali merasa capek di masa ini...",
    "created_at": "2026-11-10T13:00:02Z"
  }
}
```

### `GET /chat/sessions`

Daftar percakapan milik pengguna, terbaru dulu.
```json
{ "sessions": [ { "id": "...", "title": "Aku capek banget hari ini", "created_at": "...", "updated_at": "..." } ], "count": 1 }
```
`title` = potongan pesan pertama.

### `GET /chat/sessions/{session_id}/messages`

Isi satu percakapan, urut dari yang terlama.
```json
{ "messages": [ { "id": "...", "role": "user", "content": "...", "created_at": "..." } ], "count": 2 }
```

## Kode status

| Kode | Kapan | Yang dilakukan aplikasi |
|---|---|---|
| 401 | token tidak ada / kedaluwarsa | arahkan ke login |
| 403 | role tidak boleh chat | sembunyikan menu chat |
| 404 | `session_id` tidak ada **atau milik orang lain** | kembali ke daftar percakapan |
| 422 | pesan kosong / terlalu panjang / field asing | tampilkan pesan validasi |
| 503 | AI atau database sedang bermasalah | tampilkan `detail`, pesan pengguna tetap di kolom input |

## Batasan chatbot

- Chatbot memberi dukungan emosional dan informasi umum, **bukan diagnosis** atau pengganti tenaga kesehatan.
- Untuk tanda bahaya (pikiran menyakiti diri/bayi, perdarahan hebat, demam tinggi),
  chatbot mengarahkan ke layanan darurat / tenaga kesehatan.
- Pendamping tidak pernah mendapat isi jurnal pribadi ibu lewat chatbot.