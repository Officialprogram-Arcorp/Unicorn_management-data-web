# Proyek: UNICORN MANAGEMENT — website + rekrutmen

Baca `README.md` untuk arsitektur, langkah setup, dan batasan paket gratis.

## Ringkasan
- Website statis (tanpa build): `public/index.html` (halaman utama + formulir tersemat), `public/admin.html` (dashboard), `public/apply.js` (logika formulir), `public/config.js` (konfigurasi publik).
- Penyimpanan: Supabase proyek `dtinfhedaldmndezwtbj` (Singapura). Skema & aturan keamanan: `supabase/schema.sql` (sudah diterapkan). Proyek ini juga dipakai tabel `ar_*` milik aplikasi HR lain — **jangan disentuh**.
- Tema: rose-gold/pearl + wine/emas. Logo: `public/assets/logo.webp`.
- Bahasa konten: Indonesia.

## Aturan penting
- Jangan pernah menaruh `service_role` key atau password apa pun di file frontend. Kunci `sb_publishable_…` di `config.js` memang publik.
- Menambah posisi lowongan = ubah 3 tempat: opsi `<select id="posisi">` di `index.html`, CHECK constraint `applications_position_check` di database (migrasi), dan `supabase/schema.sql`.
- Berkas di Supabase Storage tidak bisa dihapus lewat SQL; hapus lewat dashboard admin (tombol "Hapus data") atau Storage API.
- `public/starter-lama.html` (diabaikan Git) dan `api-contract.json` adalah sisa starter lama, tidak dipakai.

## Status / sisa pekerjaan
- [ ] Buat akun admin di Supabase Auth (email `swasmithamanagement@gmail.com` dan/atau `official.arcorporation@gmail.com`, keduanya sudah ada di tabel `admins`; wajib *Auto Confirm User*), lalu login ke `admin.html`.
- [ ] Hapus data uji `UM-2026-0001` lewat dashboard.
- [ ] Klik email aktivasi FormSubmit setelah pendaftaran pertama.
- [x] Deploy: Cloudflare Pages dari repo GitHub `Officialprogram-Arcorp/Unicorn_management-data-web` (branch `main`, output directory `public`), alamat https://unicorn-management-data-web.pages.dev — `git push` ke `main` = deploy otomatis.
- [x] "Jam kerja" kini: sesuai venue penempatan (bukan lagi pukul 12.00). Baris "Pendapatan" (Rp 4 juta) sudah dihapus dari lowongan.
- [x] Formulir: hanya posisi Guest Relation Ladies (hidden input), kesiapan 3 pilihan (Segera / Dalam 3 hari / Diskusi lebih lanjut), kolom keahlian dihapus, centang opsional izin keluarga (kolom `family_permission`).
- [x] Font web: Oswald (judul) + Muli (isi) di `public/fonts/`; kontak memakai Courier New tebal. Katalog font lokal: `public/katalog-font/` (git-ignored, jangan dideploy).
