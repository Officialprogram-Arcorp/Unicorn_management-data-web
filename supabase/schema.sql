-- UNICORN MANAGEMENT — skema penyimpanan pelamar (Supabase / Postgres)
-- Prinsip: pengunjung (anon) TIDAK bisa membaca tabel apa pun. Mereka hanya bisa
--   1) mengunggah berkas ke bucket privat (insert saja, tidak bisa melihat/mengganti), dan
--   2) memanggil fungsi submit_application() yang memvalidasi di server.
-- Hanya admin (email terdaftar di tabel admins + login Supabase Auth) yang bisa membaca data.

-- ---------- Admin ----------
create table if not exists public.admins (
  email text primary key check (email = lower(email))
);
alter table public.admins enable row level security;   -- tanpa policy: tidak bisa diakses lewat API
revoke all on public.admins from anon, authenticated;

create or replace function public.is_admin()
returns boolean
language sql stable security definer set search_path = ''
as $$
  -- Admin sah hanya bila: user login, emailnya terdaftar di tabel admins, DAN emailnya sudah terverifikasi.
  select exists (
    select 1
    from auth.users u
    join public.admins a on a.email = lower(u.email)
    where u.id = auth.uid()
      and u.email_confirmed_at is not null
  );
$$;
revoke all on function public.is_admin() from public;
revoke execute on function public.is_admin() from anon;   -- Supabase memberi izin otomatis ke anon; cabut
grant execute on function public.is_admin() to authenticated;

-- ---------- Pelamar ----------
create sequence if not exists public.applications_seq;

create table if not exists public.applications (
  id                 text primary key,
  upload_folder      uuid not null unique,
  full_name          text not null check (char_length(full_name) between 2 and 100),
  date_of_birth      date not null,
  gender             text check (gender in ('Perempuan','Laki-laki','Tidak ingin menyebutkan')),
  applicant_whatsapp text not null check (applicant_whatsapp ~ '^[0-9+][0-9 +-]{7,24}$'),
  address            text not null check (char_length(address) between 5 and 500),
  position           text not null check (position in ('Guest Relation Ladies','Host Live Streaming','Admin','Staff Operasional','Customer Service','Posisi lainnya')),
  preferred_location text not null check (char_length(preferred_location) between 2 and 100),
  education          text not null check (char_length(education) between 2 and 60),
  height_cm          numeric(5,1) not null check (height_cm between 50 and 250),
  weight_kg          numeric(5,1) not null check (weight_kg between 10 and 350),
  availability       text check (char_length(availability) <= 60),
  experience         text check (char_length(experience) <= 1000),
  skills             text check (char_length(skills) <= 800),
  ktp_path           text not null,
  kk_path            text,
  alt_path           text,
  photo_path         text not null,
  status             text not null default 'Baru' check (status in ('Baru','Seleksi','Wawancara','Diterima','Ditolak')),
  admin_note         text check (char_length(admin_note) <= 1000),
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);
create index if not exists applications_created_idx on public.applications (created_at desc);

alter table public.applications enable row level security;
revoke all on public.applications from anon, authenticated;
grant select, delete on public.applications to authenticated;
grant update (status, admin_note) on public.applications to authenticated;   -- admin hanya boleh ubah dua kolom ini

drop policy if exists admin_select on public.applications;
drop policy if exists admin_update on public.applications;
drop policy if exists admin_delete on public.applications;
create policy admin_select on public.applications for select to authenticated using (public.is_admin());
create policy admin_update on public.applications for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy admin_delete on public.applications for delete to authenticated using (public.is_admin());

create or replace function public.touch_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin new.updated_at = now(); return new; end $$;
drop trigger if exists applications_touch on public.applications;
create trigger applications_touch before update on public.applications
  for each row execute function public.touch_updated_at();

-- ---------- Penerimaan pendaftaran (validasi di server) ----------
create or replace function public.submit_application(payload jsonb)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  v_folder uuid;
  v_dob    date;
  v_id     text;
  v_wa     text := btrim(payload ->> 'applicant_whatsapp');
  v_ktp    text := payload ->> 'ktp_path';
  v_kk     text := nullif(payload ->> 'kk_path', '');
  v_alt    text := nullif(payload ->> 'alt_path', '');
  v_photo  text := payload ->> 'photo_path';
  p        text;
begin
  v_folder := (payload ->> 'upload_folder')::uuid;
  v_dob    := (payload ->> 'date_of_birth')::date;

  -- Umur dihitung ulang di server: minimal 18 tahun.
  if v_dob is null or v_dob > current_date or v_dob < date '1930-01-01'
     or age(current_date, v_dob) < interval '18 years' then
    raise exception 'UNDER_AGE: pelamar harus berusia minimal 18 tahun' using errcode = 'P0001';
  end if;

  -- Pembatasan laju sederhana (anti-spam): per nomor WhatsApp dan keseluruhan.
  if (select count(*) from public.applications
        where applicant_whatsapp = v_wa and created_at > now() - interval '24 hours') >= 3 then
    raise exception 'RATE_LIMIT: terlalu banyak pendaftaran dari nomor ini' using errcode = 'P0001';
  end if;
  if (select count(*) from public.applications where created_at > now() - interval '1 hour') >= 100 then
    raise exception 'RATE_LIMIT: sistem sedang sibuk, coba lagi nanti' using errcode = 'P0001';
  end if;

  -- Path berkas harus berada di folder unggahan milik pendaftaran ini dan benar-benar sudah ada.
  foreach p in array array[v_ktp, v_kk, v_alt, v_photo] loop
    if p is not null then
      if p !~ ('^' || v_folder::text || '/(ktp|kk|alt|foto)\.(jpg|png|webp|pdf)$') then
        raise exception 'BAD_FILE_PATH' using errcode = 'P0001';
      end if;
      if not exists (select 1 from storage.objects where bucket_id = 'applicant-docs' and name = p) then
        raise exception 'FILE_MISSING: %', p using errcode = 'P0001';
      end if;
    end if;
  end loop;
  if v_ktp is null or v_photo is null then
    raise exception 'KTP dan foto wajib' using errcode = 'P0001';
  end if;

  v_id := 'UM-' || to_char(now() at time zone 'Asia/Jakarta', 'YYYY') || '-' || lpad(nextval('public.applications_seq')::text, 4, '0');

  insert into public.applications (
    id, upload_folder, full_name, date_of_birth, gender, applicant_whatsapp, address, position,
    preferred_location, education, height_cm, weight_kg, availability, experience, skills,
    ktp_path, kk_path, alt_path, photo_path
  ) values (
    v_id, v_folder, btrim(payload ->> 'full_name'), v_dob, nullif(payload ->> 'gender', ''), v_wa,
    btrim(payload ->> 'address'), payload ->> 'position', btrim(payload ->> 'preferred_location'),
    payload ->> 'education', (payload ->> 'height_cm')::numeric, (payload ->> 'weight_kg')::numeric,
    nullif(payload ->> 'availability', ''), nullif(payload ->> 'experience', ''), nullif(payload ->> 'skills', ''),
    v_ktp, v_kk, v_alt, v_photo
  );
  return v_id;
end $$;
revoke all on function public.submit_application(jsonb) from public;
grant execute on function public.submit_application(jsonb) to anon, authenticated;

-- ---------- Penyimpanan berkas (bucket PRIVAT) ----------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('applicant-docs', 'applicant-docs', false, 5242880,
        array['image/jpeg','image/png','image/webp','application/pdf'])
on conflict (id) do update
  set public = false, file_size_limit = 5242880,
      allowed_mime_types = array['image/jpeg','image/png','image/webp','application/pdf'];

drop policy if exists applicant_docs_insert on storage.objects;
drop policy if exists applicant_docs_admin_read on storage.objects;
drop policy if exists applicant_docs_admin_delete on storage.objects;

-- Pengunjung hanya boleh MENAMBAH berkas dengan pola nama yang ketat; tidak bisa membaca/mengganti/menghapus.
create policy applicant_docs_insert on storage.objects for insert to anon, authenticated
  with check (
    bucket_id = 'applicant-docs'
    and name ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/(ktp|kk|alt|foto)\.(jpg|png|webp|pdf)$'
  );
create policy applicant_docs_admin_read on storage.objects for select to authenticated
  using (bucket_id = 'applicant-docs' and public.is_admin());
create policy applicant_docs_admin_delete on storage.objects for delete to authenticated
  using (bucket_id = 'applicant-docs' and public.is_admin());

-- ---------- Admin pertama ----------
-- Ganti email ini bila perlu. Pengguna Auth dengan email yang sama harus dibuat di
-- Supabase Dashboard > Authentication > Users > Add user.
insert into public.admins (email) values ('swasmithamanagement@gmail.com'), ('official.arcorporation@gmail.com') on conflict do nothing;
