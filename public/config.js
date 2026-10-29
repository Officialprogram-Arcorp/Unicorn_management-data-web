/*
 * KONFIGURASI FRONTEND UNICORN MANAGEMENT
 *
 * Kunci "publishable" Supabase di bawah ini AMAN berada di file publik: ia hanya memberi
 * hak yang diizinkan oleh aturan keamanan (RLS) di database — pengunjung hanya bisa mengirim
 * pendaftaran, tidak bisa membaca data siapa pun.
 * JANGAN PERNAH menaruh "service_role key", password database, atau token lain di file ini.
 */
window.UNICORN_CONFIG = {
  SUPABASE_URL: "https://dtinfhedaldmndezwtbj.supabase.co",
  SUPABASE_KEY: "sb_publishable_BR_EBmCFXc0QKg-HSvN3UQ_HD1wNMbP",
  BUCKET: "applicant-docs",

  // Nomor WhatsApp admin (format internasional, tanpa +, spasi, atau tanda hubung).
  ADMIN_WHATSAPP_NUMBER: "6281511938858",
  // true = setelah pendaftaran tersimpan, tampil tombol untuk mengirim ringkasan ke WhatsApp admin.
  OPEN_WHATSAPP_AFTER_SUBMIT: true,

  // Email penerima notifikasi (hanya nomor pendaftaran & posisi, tanpa data pribadi/dokumen).
  NOTIFY_EMAIL: "swasmithamanagement@gmail.com",
  // Penerima salinan (CC). Kosongkan ("") bila tidak diperlukan.
  NOTIFY_CC: "official.arcorporation@gmail.com",

  BRAND_NAME: "UNICORN MANAGEMENT",
  MAX_FILE_MB: 5
};
