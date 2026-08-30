-- ==============================================================================
-- SKRIP TABEL AKUN, HAK AKSES, SEKBID & KONFIGURASI SUPABASE (OSIS MANAGEMENT)
-- Jalankan skrip ini di Supabase SQL Editor (Dashboard Supabase -> SQL Editor)
-- ==============================================================================

-- 1. Buat Tabel 'accounts'
CREATE TABLE IF NOT EXISTS public.accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username TEXT UNIQUE NOT NULL,
    password TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'SEKBID',
    display_name TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Buat Tabel 'sekbid' untuk Pengaturan Dinamis Sekbid & Divisi
CREATE TABLE IF NOT EXISTS public.sekbid (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    urutan INTEGER DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 3. Buat Tabel 'app_settings' untuk Konfigurasi Global Aplikasi
CREATE TABLE IF NOT EXISTS public.app_settings (
    id TEXT PRIMARY KEY DEFAULT 'global_config',
    app_name TEXT DEFAULT 'OSIS Management',
    app_subtitle TEXT DEFAULT 'Sistem Manajemen OSIS Digital',
    logo_url TEXT DEFAULT '',
    primary_color TEXT DEFAULT '0xFF00B4D8',
    default_theme_mode TEXT DEFAULT 'system',
    default_language TEXT DEFAULT 'id',
    school_name TEXT DEFAULT 'SMK Bakti Nusantara 666',
    city TEXT DEFAULT 'Bandung',
    academic_year TEXT DEFAULT '2026/2027',
    kepsek_name TEXT DEFAULT 'Drs. H. Ahmad Sudrajat, M.M.',
    kepsek_nip TEXT DEFAULT '19750815 199903 1 004',
    pembina_name TEXT DEFAULT 'Rina Marlina, S.Pd.',
    pembina_nip TEXT DEFAULT '19880210 201502 2 001',
    ketos_name TEXT DEFAULT 'Endy Mahavira',
    ketos_nis TEXT DEFAULT '22231001',
    sekretaris_name TEXT DEFAULT 'Siti Nurhaliza',
    sekretaris_nis TEXT DEFAULT '22231045',
    ttd_kepsek TEXT DEFAULT '',
    ttd_pembina TEXT DEFAULT '',
    ttd_ketos TEXT DEFAULT '',
    ttd_sekretaris TEXT DEFAULT '',
    sp1_threshold INTEGER DEFAULT 20,
    sp2_threshold INTEGER DEFAULT 50,
    sp3_threshold INTEGER DEFAULT 75,
    skorsing_threshold INTEGER DEFAULT 100,
    arsip_max_mb INTEGER DEFAULT 25,
    arsip_folders JSONB DEFAULT '["Surat Masuk","Surat Keluar","Proposal Kegiatan","LPJ Kegiatan","Dokumentasi","SK & Sertifikat"]'::jsonb,
    arsip_allowed_exts JSONB DEFAULT '["pdf","docx","xlsx","pptx","png","jpg","jpeg","zip"]'::jsonb,
    sekbid_list JSONB DEFAULT '["BPH (Inti)","SEKBID 1 (Keagamaan & Ketaqwaan)","SEKBID 2 (Budi Pekerti & Ketertiban)","SEKBID 3 (Wawasan Kebangsaan & Bela Negara)","SEKBID 4 (Prestasi Akademik, Seni, Olahraga)","SEKBID 5 (Demokrasi, HAM & Pendidikan Politik)","SEKBID 6 (Kreativitas, Keterampilan & Kewirausahaan)","SEKBID 7 (Kualitas Jasmani, Kesehatan & Gizi)","SEKBID 8 (Sastra & Budaya)","SEKBID 9 (Teknologi Informasi & Komunikasi)","SEKBID 10 (Komunikasi Bahasa Asing)"]'::jsonb,
    laporan_categories JSONB DEFAULT '["Kegiatan Rutin","Program Unggulan","Peringatan Hari Besar","Lomba & Kompetisi","Bakti Sosial","Rapat Kerja & Pleno","Lainnya"]'::jsonb,
    laporan_fields JSONB DEFAULT '["Nama Kegiatan","Tanggal","Lokasi","Peserta / Sasaran","Deskripsi","Hasil / Capaian","Kendala & Evaluasi"]'::jsonb,
    pelanggaran_fields JSONB DEFAULT '["Saksi / Petugas","Lokasi Kejadian","Sanksi / Tindak Lanjut","Keterangan Tambahan"]'::jsonb,
    rekap_types JSONB DEFAULT '["Per Kelas","Per Siswa","Per Jenis Pelanggaran","Per Tingkat Kelas","Per Status SP"]'::jsonb,
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Tambahkan kolom baru jika tabel sudah ada sebelumnya (Auto-Migration)
ALTER TABLE public.app_settings ADD COLUMN IF NOT EXISTS ttd_kepsek TEXT DEFAULT '';
ALTER TABLE public.app_settings ADD COLUMN IF NOT EXISTS ttd_pembina TEXT DEFAULT '';
ALTER TABLE public.app_settings ADD COLUMN IF NOT EXISTS ttd_ketos TEXT DEFAULT '';
ALTER TABLE public.app_settings ADD COLUMN IF NOT EXISTS ttd_sekretaris TEXT DEFAULT '';
ALTER TABLE public.app_settings ADD COLUMN IF NOT EXISTS arsip_allowed_exts JSONB DEFAULT '["pdf","docx","xlsx","pptx","png","jpg","jpeg","zip"]'::jsonb;
ALTER TABLE public.app_settings ADD COLUMN IF NOT EXISTS laporan_fields JSONB DEFAULT '["Nama Kegiatan","Tanggal","Lokasi","Peserta / Sasaran","Deskripsi","Hasil / Capaian","Kendala & Evaluasi"]'::jsonb;
ALTER TABLE public.app_settings ADD COLUMN IF NOT EXISTS pelanggaran_fields JSONB DEFAULT '["Saksi / Petugas","Lokasi Kejadian","Sanksi / Tindak Lanjut","Keterangan Tambahan"]'::jsonb;
ALTER TABLE public.app_settings ADD COLUMN IF NOT EXISTS rekap_types JSONB DEFAULT '["Per Kelas","Per Siswa","Per Jenis Pelanggaran","Per Tingkat Kelas","Per Status SP"]'::jsonb;

-- 4. Aktifkan Row Level Security (RLS) & Replica Identity
ALTER TABLE public.accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sekbid ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.accounts REPLICA IDENTITY FULL;
ALTER TABLE public.app_settings REPLICA IDENTITY FULL;
ALTER TABLE public.sekbid REPLICA IDENTITY FULL;

-- 5. Kebijakan Akses (Policy) untuk Public/Anon (Read, Insert, Update, Delete)
DROP POLICY IF EXISTS "Allow all access to accounts for anon" ON public.accounts;
CREATE POLICY "Allow all access to accounts for anon"
ON public.accounts FOR ALL TO anon, authenticated
USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow all access to app_settings for anon" ON public.app_settings;
CREATE POLICY "Allow all access to app_settings for anon"
ON public.app_settings FOR ALL TO anon, authenticated
USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow all access to sekbid for anon" ON public.sekbid;
CREATE POLICY "Allow all access to sekbid for anon"
ON public.sekbid FOR ALL TO anon, authenticated
USING (true) WITH CHECK (true);

-- 6. Aktifkan Supabase Realtime (Aman / Idempotent)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'accounts'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.accounts;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'app_settings'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.app_settings;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'sekbid'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.sekbid;
    END IF;
END $$;

-- 7. Masukkan / Seed Konfigurasi Bawaan (Default App Settings)
INSERT INTO public.app_settings (id, app_name, app_subtitle, logo_url, primary_color, default_theme_mode, default_language)
VALUES ('global_config', 'OSIS Management', 'Sistem Manajemen OSIS Digital', '', '0xFF00B4D8', 'system', 'id')
ON CONFLICT (id) DO UPDATE SET
    updated_at = now();

-- 8. Masukkan / Seed Data Akun Bawaan Termasuk Super ADMIN
INSERT INTO public.accounts (username, password, role, display_name) VALUES
('ADMIN', 'EndyMahavira24!!@', 'ADMIN', 'Admin Aplikasi OSIS Management'),
('PEMBINA', 'PembinaOSIS', 'PEMBINA', 'Pembina OSIS'),
('KESISWAAN', 'KesiswaanBaknus', 'KESISWAAN', 'Staf Kesiswaan'),
('KETUA', 'OSISBN666', 'KETUA', 'Ketua OSIS'),
('WAKIL', 'OSISBN666', 'WAKIL', 'Wakil Ketua OSIS'),
('SEKRETARIS', 'OSISBN666', 'SEKRETARIS', 'Sekretaris OSIS'),
('BENDAHARA', 'OSISBN666', 'BENDAHARA', 'Bendahara OSIS'),
('SEKBID1', 'KeimananTakwa', 'SEKBID', 'Sekbid Keimanan & Takwa'),
('SEKBID2', 'BudiPekerti', 'SEKBID', 'Sekbid Budi Pekerti'),
('SEKBID3', 'Bela Negara', 'SEKBID', 'Sekbid Kepribadian'),
('SEKBID4', 'PrestasiAkademik', 'SEKBID', 'Sekbid Prestasi Akademik'),
('SEKBID5', 'Demokrasi', 'SEKBID', 'Sekbid Demokrasi'),
('SEKBID6', 'Kewirausahaan', 'SEKBID', 'Sekbid Kreativitas'),
('SEKBID7', 'KebugaranJasmani', 'SEKBID', 'Sekbid Kesehatan'),
('SEKBID8', 'SastraBudaya', 'SEKBID', 'Sekbid Sastra & Budaya'),
('SEKBID9', 'TeknologiInformasi', 'SEKBID', 'Sekbid Teknologi Informasi'),
('SEKBID10', 'KomunikasiBahasa', 'SEKBID', 'Sekbid Komunikasi & Bahasa')
ON CONFLICT (username) DO UPDATE SET
    password = EXCLUDED.password,
    role = EXCLUDED.role,
    display_name = EXCLUDED.display_name,
    updated_at = now();
