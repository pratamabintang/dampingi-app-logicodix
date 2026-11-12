# Pengujian chatbot

Semua tes chatbot berjalan **offline**: Supabase dan Gemini dipalsukan, tidak memakai kuota.

```bash
python -m pytest -q -m local          # semua tes offline (dari root repo)
python -m pytest backend/tests/chat -q
python -m pytest backend/tests/ai -q
```

Perilaku model sungguhan dicek terpisah dengan `backend/scripts/ai_smoke.py` (memakai kuota, pesan fiktif).

## Peta risiko → tes

| Risiko | Yang dijamin | Tes |
|---|---|---|
| **Role** | Hanya `mother` dan `companion` bisa chat; profesional dan akun terhapus ditolak | `test_chat_api.py::test_professional_is_403`, `::test_deleted_account_is_403` |
| | Role diambil dari profil di server, bukan dari request; dicek ulang setiap pesan | `test_chat_security.py::test_client_cannot_choose_its_role`, `::test_role_comes_from_profile`, `::test_role_is_checked_on_every_message` |
| | Tanpa login ditolak | `test_chat_api.py::test_without_login_is_401` |
| **Kepemilikan** | Sesi orang lain tidak bisa dilanjutkan, dibaca, atau terlihat di daftar (404, sama dengan sesi yang tidak ada) | `test_chat_security.py::test_other_user_cannot_read_write_or_see_a_session`, `test_chat_service.py::test_cannot_continue_someone_elses_session` |
| | Setiap query ke Supabase memfilter `user_id` | `test_chat_store.py::test_every_read_filters_by_owner` |
| | Database menolak pesan ke sesi milik orang lain (FK komposit) | migration `20261110120000_chat.sql` (diuji manual di PostgreSQL) |
| **Privasi** | Jurnal tidak pernah dibaca chatbot, untuk role mana pun | `test_chat_privacy.py` |
| | Pendamping tidak mendapat data mood ibu; `description` mood tidak dikirim ke AI | `test_chat_context.py::test_companion_never_gets_mood_data`, `::test_source_sends_only_date_and_mood_oldest_first` |
| **Prompt injection** | Isi pesan tidak bisa mengubah instruksi sistem; tetap tercatat sebagai pesan `user` | `test_chat_security.py::test_message_cannot_change_system_prompt` (3 serangan × 2 role) |
| | Teks "assistant: …" di pesan tidak menjadi giliran AI di riwayat | `test_chat_security.py::test_fake_assistant_lines_stay_user_text_in_history` |
| | Request tidak bisa menyisipkan field (`role`, dsb.) | `test_chat_schemas.py::test_client_cannot_send_extra_fields` |
| | Jawaban AI di luar skema `{reply, urgent}` ditolak | `tests/ai/test_ai_gateway.py::test_bad_output_is_rejected` |
| | Model menolak diagnosis/dosis dan tidak membocorkan instruksi | `ai_smoke.py` (5 kasus injeksi, dicek pola dosis & potongan instruksi) |
| **Outage** | AI lambat / error / kuota habis / jawaban rusak, database mati, bug → pesan jelas, tanpa kunci, isi chat, atau traceback | `test_chat_errors.py` |
| | Gagal ambil mood → chat tetap jalan | `test_chat_context.py::test_mood_error_does_not_break_chat` |
| **Pesan ganda** | Gagal = tidak ada yang tersimpan; kirim ulang menghasilkan tepat satu pasang pesan | `test_chat_security.py::test_retry_after_failure_stores_one_pair`, `test_chat_errors.py::test_failed_attempts_save_nothing` |
| | Kirim dobel bersamaan → satu ditolak (429), satu pasang pesan tersimpan | `test_chat_security.py::test_double_send_stores_one_pair` |
| | Pesan & jawaban tersimpan dalam satu request (keduanya atau tidak sama sekali) | `test_chat_store.py::test_both_messages_are_inserted_in_one_request` |
| **Kuota** | 50 pesan / 24 jam per pengguna; yang ditolak tidak memanggil AI | `test_chat_limits.py` |

## Uji di backend yang berjalan (C10)

Dua skrip di `backend/scripts/`, dijalankan manual dari root repo:

| Skrip | Untuk apa | Memakai kuota? |
|---|---|---|
| `check_secrets.py` | Tidak ada kunci (Gemini, Supabase secret/service_role, OpenAI) di file yang di-track, `--history` di seluruh riwayat commit, `--apk` di dalam APK; `.env` tidak ikut di-commit; aplikasi tidak memanggil Gemini langsung | Tidak |
| `chat_live_check.py` | Ujung ke ujung lewat HTTP ke backend sungguhan (`CHAT_CHECK_URL`): login, chat ibu (2 pesan), riwayat, 401/422, pendamping tidak bisa membaca/menulis chat ibu (404), pendamping dijawab tanpa data ibu | Ya, 3 pesan |

Penjaga otomatis: `tests/ai/test_check_secrets.py::test_repository_has_no_secrets` gagal kalau ada kunci yang ter-commit.

## Regresi dan laporan (C12)

```bash
python backend/scripts/chat_regression.py
```

Menjalankan ulang semua pengujian di atas dan menulis laporan ke `docs/testing/reports/chat-<tanggal>.md` (commit, versi Python, model, versi prompt, hasil tiap langkah, dan log bila gagal). Smoke test Gemini dan uji HTTP hanya dijalankan bila pengaturannya ada; selain itu tercatat **"tidak dijalankan"**, bukan lulus.

## Keterbatasan yang diketahui

Chatbot versi demo, apa adanya:

| Keterbatasan | Dampak | Mitigasi saat ini |
|---|---|---|
| Bukan tenaga kesehatan | Jawaban bisa kurang tepat untuk keluhan medis | Prompt melarang diagnosis/dosis dan mengarahkan ke bidan/dokter; diuji di `ai_smoke.py` |
| Deteksi tanda bahaya (`urgent`) bergantung pada model | Bisa terlewat bila diungkapkan sangat samar | Kasus jelas diuji di `ai_smoke.py`; batasan chatbot tercantum di `docs/api/chat.md` untuk ditampilkan aplikasi |
| Perilaku model tidak 100% konsisten | Gaya bahasa atau panjang jawaban bisa berbeda antarpercakapan | Prompt dan konfigurasi dibekukan (`test_chat_prompts.py`); jawaban di luar skema ditolak |
| Ingatan terbatas | Hanya 10 pesan / 6.000 karakter terakhir dari sesi yang sama yang dikirim ke AI | Disengaja untuk hemat kuota dan minimasi data |
| Konteks ibu hanya mood | Chatbot tidak membaca jurnal, observasi pendamping, atau catatan profesional | Disengaja (privasi); dikunci `test_chat_privacy.py` |
| Rentang 7 hari mood dihitung dari tanggal UTC | Bisa mencakup satu hari lebih awal di zona WIB/WITA/WIT | Tetap dibatasi 7 entri terbaru |
| Pendamping tidak mendapat konteks ibu | Saran untuk pendamping bersifat umum | Konteks berbasis izin ibu belum dibuat |
| "Satu pesan dalam proses" disimpan di memori proses | Bila backend berjalan lebih dari satu proses/instance, pengaman ini per proses | Demo memakai satu proses; batas harian tetap dari database |
| Bergantung pada layanan Gemini | Saat kuota habis atau Gemini gangguan, chat tidak menjawab | Pesan 503 yang jelas; tidak ada data tersimpan sehingga bisa kirim ulang |
| Gemini sesekali lambat (> 20 dtk) | Tercatat di regresi 12 Nov: 1 dari 8 kasus smoke test kena `504 DEADLINE_EXCEEDED` | Dipetakan ke pesan "butuh waktu terlalu lama, kirim ulang" (`AITimeout`); tanpa retry otomatis supaya kuota tidak terbuang |
| Tier Gemini gratis | Isi permintaan dapat dipakai/ditinjau Google | Demo memakai akun dan isi fiktif; billing disarankan sebelum data sungguhan |
| Tanpa streaming | Jawaban muncul sekaligus setelah 1–5 dtk | Aplikasi perlu menampilkan indikator menunggu dan menonaktifkan tombol kirim (`docs/api/chat.md`, kode 429) |