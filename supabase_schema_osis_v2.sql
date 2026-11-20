-- ============================================================
-- OSIS MANAGEMENT V2 - EXTENDED SUPABASE SCHEMA
-- Menambahkan tabel Profil OSIS, Inventaris, Agenda,
-- Pengumuman, Dokumentasi, Evaluasi, dan Audit Aktivitas
-- ============================================================

-- 1. PROFIL OSIS
CREATE TABLE IF NOT EXISTS public.profil_osis (
    id TEXT PRIMARY KEY DEFAULT 'single',
    nama_organisasi TEXT NOT NULL DEFAULT 'OSIS SMK Bakti Nusantara 666',
    nama_sekolah TEXT NOT NULL DEFAULT 'SMK Bakti Nusantara 666',
    logo_osis_url TEXT DEFAULT '',
    logo_sekolah_url TEXT DEFAULT '',
    visi TEXT DEFAULT '',
    misi JSONB DEFAULT '[]'::jsonb,
    masa_bakti TEXT DEFAULT '2026 / 2027',
    nama_ketua TEXT DEFAULT 'Ketua OSIS',
    nama_wakil TEXT DEFAULT 'Wakil Ketua OSIS',
    nama_pembina TEXT DEFAULT 'Pembina OSIS',
    nama_sekretaris TEXT DEFAULT 'Sekretaris OSIS',
    nama_bendahara TEXT DEFAULT 'Bendahara OSIS',
    ad_art TEXT DEFAULT '',
    gbho TEXT DEFAULT '',
    deskripsi TEXT DEFAULT '',
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. INVENTARIS OSIS
CREATE TABLE IF NOT EXISTS public.inventaris_osis (
    id TEXT PRIMARY KEY,
    nama_barang TEXT NOT NULL,
    kode_barang TEXT DEFAULT '',
    kategori TEXT DEFAULT 'Perlengkapan Acara',
    jumlah INT DEFAULT 1,
    kondisi TEXT DEFAULT 'Baik',
    lokasi_simpan TEXT DEFAULT 'Ruang OSIS',
    status_peminjaman TEXT DEFAULT 'Tersedia',
    peminjam TEXT DEFAULT '',
    tanggal_masuk TIMESTAMPTZ DEFAULT NOW(),
    keterangan TEXT DEFAULT ''
);

-- 3. KALENDER & AGENDA KEGIATAN
CREATE TABLE IF NOT EXISTS public.agenda_osis (
    id TEXT PRIMARY KEY,
    judul TEXT NOT NULL,
    kategori TEXT DEFAULT 'Rapat OSIS',
    bidang TEXT DEFAULT 'BPH',
    waktu_mulai TIMESTAMPTZ NOT NULL,
    waktu_selesai TIMESTAMPTZ,
    lokasi TEXT DEFAULT 'Ruang OSIS',
    penanggung_jawab TEXT DEFAULT '',
    deskripsi TEXT DEFAULT '',
    status TEXT DEFAULT 'Akan Datang',
    pengingat BOOLEAN DEFAULT TRUE
);

-- 4. INFORMASI & PENGUMUMAN
CREATE TABLE IF NOT EXISTS public.pengumuman_osis (
    id TEXT PRIMARY KEY,
    judul TEXT NOT NULL,
    isi TEXT NOT NULL,
    pengirim TEXT NOT NULL,
    role_pengirim TEXT DEFAULT 'Ketua OSIS',
    kategori TEXT DEFAULT 'Umum',
    target_bidang TEXT DEFAULT 'Semua',
    tanggal TIMESTAMPTZ DEFAULT NOW(),
    lampiran_url TEXT DEFAULT '',
    is_pinned BOOLEAN DEFAULT FALSE
);

-- 5. DOKUMENTASI KEGIATAN
CREATE TABLE IF NOT EXISTS public.dokumentasi_kegiatan (
    id TEXT PRIMARY KEY,
    judul TEXT NOT NULL,
    kategori TEXT DEFAULT 'Kegiatan Sekolah',
    tanggal TIMESTAMPTZ DEFAULT NOW(),
    deskripsi TEXT DEFAULT '',
    foto_urls JSONB DEFAULT '[]'::jsonb,
    video_url TEXT DEFAULT '',
    bidang TEXT DEFAULT 'Semua',
    penanggung_jawab TEXT DEFAULT ''
);

-- 6. EVALUASI DAN PENILAIAN KINERJA
CREATE TABLE IF NOT EXISTS public.evaluasi_proker (
    id TEXT PRIMARY KEY,
    proker_id TEXT DEFAULT '',
    nama_proker TEXT NOT NULL,
    sekbid TEXT NOT NULL,
    tanggal_evaluasi TIMESTAMPTZ DEFAULT NOW(),
    hasil_capaian TEXT DEFAULT '',
    kendala TEXT DEFAULT '',
    saran_masukan TEXT DEFAULT '',
    nilai_kinerja INT DEFAULT 85,
    penilai TEXT DEFAULT 'Pembina OSIS',
    rekomendasi TEXT DEFAULT ''
);

-- 7. RIWAYAT AKTIVITAS PENGGUNA (AUDIT LOG)
CREATE TABLE IF NOT EXISTS public.aktivitas_pengguna (
    id TEXT PRIMARY KEY,
    username TEXT NOT NULL,
    display_name TEXT DEFAULT '',
    role TEXT DEFAULT '',
    aksi TEXT NOT NULL,
    modul TEXT NOT NULL,
    waktu TIMESTAMPTZ DEFAULT NOW(),
    detail TEXT DEFAULT ''
);

-- Enable Row Level Security (RLS) & Public Access
ALTER TABLE public.profil_osis ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventaris_osis ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agenda_osis ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pengumuman_osis ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dokumentasi_kegiatan ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.evaluasi_proker ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.aktivitas_pengguna ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public Read All" ON public.profil_osis FOR SELECT USING (true);
CREATE POLICY "Public Upsert All" ON public.profil_osis FOR ALL USING (true);

CREATE POLICY "Public Read All" ON public.inventaris_osis FOR SELECT USING (true);
CREATE POLICY "Public Upsert All" ON public.inventaris_osis FOR ALL USING (true);

CREATE POLICY "Public Read All" ON public.agenda_osis FOR SELECT USING (true);
CREATE POLICY "Public Upsert All" ON public.agenda_osis FOR ALL USING (true);

CREATE POLICY "Public Read All" ON public.pengumuman_osis FOR SELECT USING (true);
CREATE POLICY "Public Upsert All" ON public.pengumuman_osis FOR ALL USING (true);

CREATE POLICY "Public Read All" ON public.dokumentasi_kegiatan FOR SELECT USING (true);
CREATE POLICY "Public Upsert All" ON public.dokumentasi_kegiatan FOR ALL USING (true);

CREATE POLICY "Public Read All" ON public.evaluasi_proker FOR SELECT USING (true);
CREATE POLICY "Public Upsert All" ON public.evaluasi_proker FOR ALL USING (true);

CREATE POLICY "Public Read All" ON public.aktivitas_pengguna FOR SELECT USING (true);
CREATE POLICY "Public Upsert All" ON public.aktivitas_pengguna FOR ALL USING (true);
