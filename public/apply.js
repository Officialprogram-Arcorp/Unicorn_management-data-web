/* Pengiriman formulir pendaftaran -> Supabase (storage privat + fungsi validasi server). */
(() => {
  const cfg = window.UNICORN_CONFIG || {};
  const form = document.getElementById("applyForm");
  if (!form) return;

  const statusBox = document.getElementById("status");
  const submitBtn = form.querySelector('button[type="submit"]');
  const maxBytes = (Number(cfg.MAX_FILE_MB) || 5) * 1024 * 1024;
  const EXT = { "image/jpeg": "jpg", "image/png": "png", "image/webp": "webp", "application/pdf": "pdf" };
  const dob = document.getElementById("lahir");

  const say = (msg, isError) => { statusBox.textContent = msg; statusBox.style.color = isError ? "#b3261e" : ""; };

  // Tanggal lahir terbaru yang diizinkan = 18 tahun lalu (hanya kemudahan; server menghitung ulang).
  const t = new Date(), max = new Date(t.getFullYear() - 18, t.getMonth(), t.getDate());
  dob.max = `${max.getFullYear()}-${String(max.getMonth() + 1).padStart(2, "0")}-${String(max.getDate()).padStart(2, "0")}`;

  function fileCheck() {
    for (const input of form.querySelectorAll('input[type="file"]')) {
      const f = input.files[0];
      if (!f) continue;
      if (f.size > maxBytes) { say(`Berkas ${f.name} melebihi batas ${cfg.MAX_FILE_MB || 5} MB.`, true); input.value = ""; return false; }
      if (!EXT[f.type] || (input.id === "foto" && f.type === "application/pdf")) {
        say(`Format berkas ${f.name} tidak didukung.`, true); input.value = ""; return false;
      }
    }
    return true;
  }
  form.querySelectorAll('input[type="file"]').forEach(i => i.addEventListener("change", fileCheck));

  const preview = document.getElementById("photoPreview");
  document.getElementById("foto").addEventListener("change", e => {
    const f = e.target.files[0];
    if (f && f.type.startsWith("image/")) { preview.src = URL.createObjectURL(f); preview.style.display = "block"; }
    else { preview.style.display = "none"; preview.removeAttribute("src"); }
  });

  async function upload(folder, slot, file) {
    const path = `${folder}/${slot}.${EXT[file.type]}`;
    const res = await fetch(`${cfg.SUPABASE_URL}/storage/v1/object/${cfg.BUCKET}/${path}`, {
      method: "POST",
      headers: { apikey: cfg.SUPABASE_KEY, "Content-Type": file.type, "x-upsert": "false" },
      body: file
    });
    if (!res.ok) throw new Error("Unggah berkas gagal (" + res.status + ")");
    return path;
  }

  function friendly(msg) {
    if (/UNDER_AGE/.test(msg)) return "Pelamar harus berusia minimal 18 tahun berdasarkan tanggal lahir.";
    if (/RATE_LIMIT/.test(msg)) return "Terlalu banyak pendaftaran dalam waktu singkat. Coba lagi nanti.";
    return msg;
  }

  function notifyEmail(id, position) {
    if (!cfg.NOTIFY_EMAIL) return;
    // Hanya nomor pendaftaran & posisi — tanpa nama, kontak, atau dokumen.
    fetch("https://formsubmit.co/ajax/" + encodeURIComponent(cfg.NOTIFY_EMAIL), {
      method: "POST",
      headers: { "Content-Type": "application/json", Accept: "application/json" },
      body: JSON.stringify({ _subject: `Pendaftaran baru ${id} — ${cfg.BRAND_NAME}`, _template: "table",
        ...(cfg.NOTIFY_CC ? { _cc: cfg.NOTIFY_CC } : {}),
        "Nomor pendaftaran": id, "Posisi": position, "Catatan": "Buka dashboard admin untuk melihat detail." })
    }).catch(() => {});
  }

  function showSuccess(id, name, position) {
    statusBox.textContent = `Pendaftaran berhasil dikirim. Nomor pendaftaran: ${id}. Simpan nomor ini.`;
    statusBox.style.color = "#2e6b3a";
    if (cfg.OPEN_WHATSAPP_AFTER_SUBMIT && /^62\d{8,15}$/.test(cfg.ADMIN_WHATSAPP_NUMBER || "")) {
      const msg = `Pendaftaran baru ${cfg.BRAND_NAME}\nNomor: ${id}\nPosisi: ${position}\nNama: ${name}`;
      const a = document.createElement("a");
      a.href = `https://wa.me/${cfg.ADMIN_WHATSAPP_NUMBER}?text=${encodeURIComponent(msg)}`;
      a.target = "_blank"; a.rel = "noopener noreferrer";
      a.textContent = "Kirim konfirmasi ke WhatsApp admin →";
      a.style.cssText = "display:inline-block;margin-top:10px;font-weight:700;color:#7b352e";
      statusBox.appendChild(document.createElement("br"));
      statusBox.appendChild(a);
    }
  }

  form.addEventListener("submit", async e => {
    e.preventDefault();
    say("");
    if (!form.reportValidity() || !fileCheck()) return;

    const fd = new FormData(form);
    const val = k => (fd.get(k) || "").toString().trim();
    const folder = crypto.randomUUID();
    submitBtn.disabled = true;
    try {
      say("Mengunggah dokumen…");
      const files = { ktp: form.ktp_document.files[0], foto: form.portrait_photo.files[0],
                      kk: form.family_card.files[0], alt: form.alternative_document.files[0] };
      const paths = {};
      for (const slot of ["ktp", "foto", "kk", "alt"]) if (files[slot]) paths[slot] = await upload(folder, slot, files[slot]);

      say("Menyimpan pendaftaran…");
      const payload = {
        upload_folder: folder, full_name: val("full_name"), date_of_birth: val("date_of_birth"), gender: val("gender"),
        applicant_whatsapp: val("applicant_whatsapp"), address: val("address"), position: val("position"),
        preferred_location: val("preferred_location"), education: val("education"), height_cm: val("height_cm"),
        weight_kg: val("weight_kg"), availability: val("availability"), experience: val("experience"),
        family_permission: form.family_permission.checked,
        ktp_path: paths.ktp, photo_path: paths.foto, kk_path: paths.kk || "", alt_path: paths.alt || ""
      };
      const res = await fetch(`${cfg.SUPABASE_URL}/rest/v1/rpc/submit_application`, {
        method: "POST",
        headers: { apikey: cfg.SUPABASE_KEY, "Content-Type": "application/json" },
        body: JSON.stringify({ payload })
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) throw new Error(friendly(data.message || ("HTTP " + res.status)));

      const id = typeof data === "string" ? data : String(data);
      notifyEmail(id, payload.position);
      showSuccess(id, payload.full_name, payload.position);
      form.reset(); preview.style.display = "none";
    } catch (err) {
      say("Pendaftaran belum terkirim: " + err.message, true);
    } finally {
      submitBtn.disabled = false;
    }
  });
})();
