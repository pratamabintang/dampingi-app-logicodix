# API Auth Dampingi

Kontrak antara backend (FastAPI) dan aplikasi Flutter untuk pendaftaran,
login, verifikasi email, dan pengiriman ulang kode verifikasi.
Bentuk data persisnya ada di `backend/app/auth/schemas.py`.

## Aturan umum

- Register hanya menerima alamat **Gmail** (`@gmail.com`). Alamat lain `422`.
- Password minimal 8 karakter, maksimal 72.
- Error selalu berbentuk `{"detail": "..."}` (pesan siap ditampilkan ke pengguna),
  kecuali `422` yang `detail`-nya berupa daftar kesalahan validasi.
- Setelah verifikasi email diaktifkan di Supabase, akun **belum bisa login**
  sebelum alamatnya diverifikasi.

## Alur verifikasi email

1. `POST /auth/register` → akun dibuat, kode verifikasi dikirim ke email.
   Respons `201` dengan `access_token` bernilai `null`.
2. Pengguna memasukkan kode dari email.
3. `POST /auth/verify-email` → kode ditukar dengan sesi. Pengguna langsung
   masuk (dapat `access_token`), tidak perlu login lagi.
4. Kalau kode tidak sampai, `POST /auth/resend-confirmation` mengirim ulang.

Selama verifikasi belum selesai, `POST /auth/login` membalas `403`
(lihat "Kode status"). Kode verifikasi kedaluwarsa setelah 1 jam.

## Alur lupa sandi

1. `POST /auth/forgot-password` → kode reset dikirim ke email (kalau alamat
   terdaftar). Respons `202` selalu sama, untuk alamat apa pun.
2. Pengguna memasukkan kode dari email.
3. `POST /auth/reset-password` → password diganti dan semua sesi dicabut.
   Pengguna lalu login lagi dengan password baru.

Kode reset berlaku 1 jam. Sengaja tidak ada auto-login setelah reset: sesi
yang dibuat saat menukar kode langsung dicabut, supaya kode dari email tidak
berubah menjadi sesi permanen.

## Endpoint

### `POST /auth/register`

Request:
```json
{ "name": "Bunda", "email": "bunda@gmail.com", "password": "rahasia123", "role": "mother", "timezone": "Asia/Jakarta" }
```
- `name`: 1–100 karakter.
- `email`: wajib `@gmail.com`.
- `role`: `mother` | `companion` | `professional`.
- `timezone`: nama zona IANA (mis. `Asia/Jakarta`, `Asia/Makassar`, `Asia/Jayapura`). Opsional; kalau tidak dikirim, default `Asia/Jakarta`. Zona yang tidak dikenal → `422`. Klien mobile mengirim zona perangkat secara otomatis.

Response `201`:
```json
{
  "user": { "id": "6f1c2a52-0d3e-4c1b-9a7e-2b9f4f0c1a11", "email": "bunda@gmail.com", "name": "Bunda", "role": "mother" },
  "access_token": null
}
```
- Saat verifikasi email **mati**, `access_token` berisi token dan pengguna
  langsung masuk.
- Saat verifikasi email **hidup**, `access_token` `null`: arahkan pengguna ke
  layar "cek email / masukkan kode".
- Alamat Gmail yang **sudah terdaftar dan terverifikasi** → `409`. Supabase
  tidak membalas error untuk kasus ini, melainkan `200` berisi user palsu
  (id acak, `identities` kosong) supaya tidak bocor akun mana yang ada;
  backend mengenali user palsu itu dan menerjemahkannya jadi `409`.
- Alamat yang terdaftar **tetapi belum terverifikasi** → `201` (kode dikirim
  ulang).
- Kalau Supabase sedang membatasi pengiriman email ke alamat itu (cooldown
  ~60 detik, `over_email_send_rate_limit`), balasannya `429` dengan header
  `Retry-After`, bukan `503`.

### `POST /auth/login`

Request:
```json
{ "email": "bunda@gmail.com", "password": "rahasia123" }
```

Response `200`:
```json
{
  "access_token": "eyJhbGciOi...",
  "user": { "id": "...", "email": "bunda@gmail.com", "name": "Bunda", "role": "mother" }
}
```
`access_token` dipakai sebagai `Authorization: Bearer <access_token>` di
endpoint lain.

### `POST /auth/verify-email`

Menukar kode verifikasi dari email dengan sesi. Pengguna langsung masuk.

Request:
```json
{ "email": "bunda@gmail.com", "token": "12345678" }
```
- `token`: kode yang dikirim ke email (biasanya 8 digit).

Response `200` — persis seperti `POST /auth/login`:
```json
{
  "access_token": "eyJhbGciOi...",
  "user": { "id": "...", "email": "bunda@gmail.com", "name": "Bunda", "role": "mother" }
}
```
- Kode salah **atau** kedaluwarsa → `400` dengan pesan yang sama, supaya tidak
  bisa dipakai menebak email mana yang terdaftar.

### `POST /auth/resend-confirmation`

Minta kode verifikasi baru.

Request:
```json
{ "email": "bunda@gmail.com" }
```

Response `202` (selalu sama, untuk email apa pun):
```json
{ "detail": "Jika email terdaftar, kode verifikasi sudah dikirim ulang." }
```
- Sengaja tidak membedakan email terdaftar / tidak: ini menutup celah
  penebakan akun.
- Kalau Supabase membatasi pengiriman ke alamat itu (cooldown ~60 detik),
  balasannya `429` + `Retry-After`.

### `POST /auth/forgot-password`

Minta kode reset password.

Request:
```json
{ "email": "bunda@gmail.com" }
```

Response `202` (selalu sama, untuk email apa pun):
```json
{ "detail": "Jika email terdaftar, kode reset sudah dikirim." }
```
- Sengaja tidak membedakan email terdaftar / tidak.
- Kalau Supabase membatasi pengiriman ke alamat itu (cooldown ~60 detik),
  balasannya `429` + `Retry-After`.

### `POST /auth/reset-password`

Menukar kode reset dengan password baru.

Request:
```json
{ "email": "bunda@gmail.com", "token": "12345678", "new_password": "rahasiaBaru123" }
```
- `token`: kode dari email (biasanya 8 digit).
- `new_password`: 8–72 karakter.

Response `204` tanpa body.
- Semua sesi dicabut; pengguna harus login lagi dengan password baru.
- Kode salah **atau** kedaluwarsa → `400` dengan pesan yang sama, supaya tidak
  bisa dipakai menebak email mana yang terdaftar.

## Kode status

| Kode | Kapan | Yang dilakukan aplikasi |
|---|---|---|
| 201 | register berhasil | kalau `access_token` `null`, buka layar masukkan kode |
| 200 | login / verify-email berhasil | simpan `access_token`, masuk ke beranda |
| 202 | resend / forgot-password diterima | tampilkan `detail`, tunggu pengguna memasukkan kode |
| 204 | reset-password / ganti sandi berhasil | arahkan ke halaman login |
| 400 | kode verifikasi salah / kedaluwarsa | tampilkan `detail`, biarkan pengguna coba lagi / kirim ulang |
| 401 | email atau password salah | tampilkan `detail` |
| 403 | email **belum diverifikasi** (login), atau akun sudah dihapus | saat belum verifikasi: arahkan ke layar masukkan kode / kirim ulang |
| 409 | email Gmail sudah terdaftar | arahkan ke login |
| 422 | email bukan Gmail / field tidak valid | tampilkan pesan validasi |
| 429 | terlalu banyak percobaan (register/login/verify/resend), atau Supabase membatasi pengiriman email ke alamat itu | tampilkan `detail`, hormati header `Retry-After` |
| 503 | layanan auth/database sedang bermasalah | tampilkan `detail`, coba lagi nanti |

Pesan `403` saat belum verifikasi:
`"Email belum diverifikasi. Cek email untuk kode verifikasi."`

Pesan `400` saat kode reset salah atau kedaluwarsa:
`"Kode reset salah atau sudah kedaluwarsa."`

## Batas percobaan

Dihitung per alamat IP dan per akun dalam jendela 15 menit:

| Aksi | Per alamat | Per akun |
|---|---|---|
| register | 10 | 5 |
| login | 30 | 10 |
| verify-email | 30 | 10 |
| resend-confirmation | 5 | 3 |
| forgot-password | 5 | 3 |
| reset-password | 30 | 10 |

Supabase juga punya batas sendiri untuk pengiriman email
(`rate_limit_email_sent`); batas itu berlaku per project, jadi batas lokal di
atas dipasang supaya satu pengguna tidak menghabiskan kuota semua orang.
