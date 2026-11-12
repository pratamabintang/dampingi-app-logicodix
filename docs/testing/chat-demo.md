# Chatbot: persiapan demo dan penilaian (C13)

Target rencana kerja C13: **chatbot dapat digunakan, atau gagal dengan pesan yang jelas**.
Aturan sejak C11: **prompt dan konfigurasi tidak diubah mendadak** menjelang demo.

## 1. Daftar cek sebelum submission (14 Nov) dan sebelum demo final

Jalankan dari root repo.

| # | Cek | Perintah / tempat | Lulus bila |
|---|---|---|---|
| 1 | Tes offline | `python backend/scripts/chat_regression.py` | 3 langkah offline **lulus** |
| 2 | Tidak ada kunci di repo + riwayat | `python backend/scripts/check_secrets.py --history` | "Aman" |
| 3 | Tidak ada kunci di APK final | `python backend/scripts/check_secrets.py --apk <app>.apk` | "Aman", dan tidak ada "aplikasi memanggil Gemini langsung" |
| 4 | Backend ter-host hidup | buka `<URL>/health` | `{"status":"healthy"}` |
| 5 | Pengaturan AI di server | dashboard hosting → environment | `AI_PROVIDER=gemini`, `GEMINI_API_KEY` terisi, `GEMINI_MODEL=gemini-3.1-flash-lite` |
| 6 | Chat ujung ke ujung di server | `CHAT_CHECK_URL=<URL> … python backend/scripts/chat_regression.py` (akun seed, lihat `chat_live_check.py`) | Uji HTTP **lulus** |
| 7 | Kuota Gemini | Google AI Studio / Cloud → kuota & budget alert | Ada sisa kuota sampai pengumuman finalis (21 Nov) |
| 8 | Batas harian cukup untuk juri | environment `CHAT_DAILY_LIMIT` | Lihat catatan di bawah |

**Batas harian berlaku per akun.** Kalau semua juri memakai **satu** akun demo yang sama, 50 pesan per 24 jam bisa habis. Pilihannya: siapkan satu akun demo per juri, atau naikkan `CHAT_DAILY_LIMIT` di server selama masa penilaian (mis. 150). Pengaman biaya tetap ada di budget/kuota Google.

## 2. Skenario chatbot di video demo (± 60–75 detik dari 3–5 menit)

Video wajib merekam aplikasi yang benar-benar berjalan dari commit final, dan menampilkan integrasi AI secara langsung (guidebook hal. 19). Pakai akun **seed / demo fiktif**, bukan data sungguhan.

| Urutan | Aksi di aplikasi (akun ibu) | Yang terlihat |
|---|---|---|
| 1 | Buka menu chat, kirim: *"Akhir-akhir ini aku capek dan gampang sedih."* | Indikator mengetik, lalu jawaban hangat yang menyapa "Bunda"; keterangan "Konteks suasana hati 7 hari digunakan" |
| 2 | Kirim lanjutan: *"Bayiku sering bangun malam, aku harus gimana?"* | AI menyambung percakapan yang sama (riwayat) |
| 3 | Kirim: *"Kadang aku kepikiran ingin menyakiti diri sendiri."* | Banner darurat merah + jawaban yang mengarahkan ke 119 / IGD / orang terdekat |

Sambil menampilkan, narasi/teks singkat: AI hanya memakai mood milik ibu (tanggal + skala), **tidak pernah** membaca jurnal; kunci AI hanya ada di server.

**Kalau AI gagal saat merekam** (pesan "butuh waktu terlalu lama" / "sedang banyak dipakai"): rekam ulang. Video harus utuh dan tidak boleh disunting untuk mengubah hasil, dan tidak boleh memakai jawaban palsu (`AI_PROVIDER=fake`) sebagai pengganti demonstrasi.

## 3. Saat penilaian dan final

- **Fallback yang jelas** sudah ada di aplikasi: setiap kegagalan menampilkan pesan berbahasa Indonesia, tidak ada yang tersimpan, pengguna bisa langsung kirim ulang (`docs/api/chat.md`, kode status).
- **Final (29 Nov, offline, localhost)**: backend dijalankan di laptop dengan `backend/.env` berisi `AI_PROVIDER=gemini` dan kunci tim; aplikasi dijalankan dengan `--dart-define=API_BASE_URL=http://<IP-laptop>:8000 --dart-define=USE_BACKEND_AUTH=true` (emulator Android: `http://10.0.2.2:8000`; lihat `mobile/README.md`). Jalankan cek #1, #6 (ke `http://127.0.0.1:8000`), dan #7 sekitar 30 menit sebelum tampil.
- Jika Gemini sedang gangguan saat live demo: tunjukkan pesan fallback-nya (itu bagian dari desain), lalu coba kirim ulang.
- Pertanyaan juri soal keamanan/privasi: lihat `docs/testing/chat.md` (peta risiko → tes, keterbatasan).