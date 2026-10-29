# UNICORN MANAGEMENT — Website, Formulir Rekrutmen & Dashboard Admin

## Berkas

| Berkas | Fungsi |
|---|---|
| `public/home.html` | Website perusahaan + formulir pendaftaran (sudah tersemat di bagian **Karier**) |
| `public/apply.js` | Logika formulir: unggah dokumen → simpan pendaftaran → notifikasi |
| `public/admin.html` | Dashboard admin (login, statistik, cari/filter, ubah status, dokumen, ekspor CSV, hapus) |
| `public/config.js` | URL & kunci publik Supabase, nomor WhatsApp admin, email notifikasi |
| `public/assets/logo.webp` | Logo |
| `supabase/schema.sql` | Skema database + aturan keamanan (sudah diterapkan ke proyek Supabase) |
| `public/index.html` | Starter lama (formulir untuk backend lain). **Tidak dipakai lagi**; boleh dihapus |
| `api-contract.json` | Kontrak API starter lama. **Tidak berlaku lagi** |

## Arsitektur

```
Pengunjung ──► home.html ──► Supabase Storage (bucket PRIVAT "applicant-docs")   ← hanya bisa menambah berkas
                        └──► fungsi submit_application() ──► tabel applications  ← validasi di server
Admin ───────► admin.html ──► login Supabase Auth ──► baca/ubah data (RLS: hanya email di tabel admins)
```

Proyek Supabase: `dtinfhedaldmndezwtbj` (Singapura). Proyek ini juga dipakai tabel `ar_*` (aplikasi HR lain); skema ini tidak menyentuhnya.

## Keamanan (sudah diuji)

- Pengunjung **tidak bisa membaca** tabel pelamar, tabel admin, maupun berkas. Mereka hanya bisa mengirim pendaftaran.
- Umur dihitung ulang **di server**; di bawah 18 tahun ditolak.
- Bucket privat, maks 5 MB, hanya JPG/PNG/WEBP/PDF, nama berkas dikunci polanya.
- Batas laju sederhana: maks 3 pendaftaran/24 jam per nomor WhatsApp, 100/jam keseluruhan.
- Dokumen dibuka admin lewat tautan sementara (2 menit).
- Kunci `sb_publishable_…` di `config.js` memang boleh publik. **Jangan pernah** menaruh `service_role` key di file mana pun.

## Langkah wajib sebelum dipakai

1. **Buat akun admin.** Email yang sudah didaftarkan sebagai admin: `swasmithamanagement@gmail.com` dan `official.arcorporation@gmail.com`. Supabase Dashboard → Authentication → Users → *Add user* → email tersebut + password kuat (**wajib centang *Auto Confirm User***; admin hanya sah bila emailnya terverifikasi):
   https://supabase.com/dashboard/project/dtinfhedaldmndezwtbj/auth/users
   (Admin tambahan: tambahkan emailnya, huruf kecil semua, ke tabel `public.admins`, lalu buat user Auth-nya.)
2. **Aktifkan email notifikasi.** Pendaftaran pertama memicu email aktivasi dari FormSubmit ke `swasmithamanagement@gmail.com`; klik tautan di dalamnya sekali. Cek juga folder Spam.
3. **Hapus data uji.** Buka `admin.html`, login, buka `UM-2026-0001` (TEST Uji Sistem), klik **Hapus data** (ini juga menghapus berkasnya).
4. **Upload** isi folder `public` (kecuali `index.html`) ke hosting statis (mis. Cloudflare Pages, Netlify, GitHub Pages — semuanya punya paket gratis). Gunakan HTTPS.

## Notifikasi

- **WhatsApp:** setelah pendaftaran tersimpan, pelamar melihat tombol yang membuka chat ke `+62 815 1193 8858` dengan ringkasan (nomor, posisi, nama); pelamar tetap menekan *Kirim*. Ini bukan notifikasi otomatis dari server.
- **Email:** dikirim via FormSubmit (gratis) ke `swasmithamanagement@gmail.com` dengan salinan (CC) ke `official.arcorporation@gmail.com`, berisi **hanya nomor pendaftaran & posisi**. Ubah `NOTIFY_EMAIL` / `NOTIFY_CC` di `config.js`.

## Batasan paket gratis (penting)

- **Proyek dijeda otomatis** bila tidak ada aktivitas ±7 hari. Saat dijeda, formulir gagal mengirim sampai proyek diaktifkan lagi (Supabase Dashboard → *Restore project*). Pencegahan: pastikan ada aktivitas rutin (mis. aplikasi HR AR Corporation), atau jadwalkan ping berkala ke API.
- Kuota gratis: database 500 MB, penyimpanan berkas 1 GB. Dokumen berukuran ±1–5 MB, jadi ±200–1000 pelamar. Pantau di dashboard Supabase.
- Cadangan otomatis tidak termasuk paket gratis: ekspor CSV berkala dari dashboard admin.
- Belum ada CAPTCHA. Jika mulai ada spam, tambahkan Cloudflare Turnstile.

## Privasi

KTP/KK/foto adalah data pribadi. Tentukan tujuan, masa simpan, dan siapa yang boleh mengakses; hapus data pelamar yang tidak diterima sesuai kebijakan Anda. Tampilkan pemberitahuan privasi sebelum produksi.
