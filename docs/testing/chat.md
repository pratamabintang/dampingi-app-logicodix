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