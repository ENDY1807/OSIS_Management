-- ==============================================================================
-- SKRIP LENGKAP TABEL, HAK AKSES, REALTIME & SEED DATA (OSIS MANAGEMENT)
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

-- 2. Buat Tabel 'sekbid'
CREATE TABLE IF NOT EXISTS public.sekbid (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    urutan INTEGER DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 3. Buat Tabel 'app_settings' (Konfigurasi Global & Realtime Sync)
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
    sekbid_list JSONB DEFAULT '["SEKBID1","SEKBID2","SEKBID3","SEKBID4","SEKBID5","SEKBID6","SEKBID7","SEKBID8","SEKBID9","SEKBID10"]'::jsonb,
    laporan_categories JSONB DEFAULT '["Kegiatan Rutin","Program Unggulan","Peringatan Hari Besar","Lomba & Kompetisi","Bakti Sosial","Rapat Kerja & Pleno","Lainnya"]'::jsonb,
    laporan_fields JSONB DEFAULT '["Nama Kegiatan","Tanggal","Lokasi","Peserta / Sasaran","Deskripsi","Hasil / Capaian","Kendala & Evaluasi"]'::jsonb,
    pelanggaran_fields JSONB DEFAULT '["Saksi / Petugas","Lokasi Kejadian","Sanksi / Tindak Lanjut","Keterangan Tambahan"]'::jsonb,
    rekap_types JSONB DEFAULT '["Per Kelas","Per Siswa","Per Jenis Pelanggaran","Per Tingkat Kelas","Per Status SP"]'::jsonb,
    custom_fields JSONB DEFAULT '{"laporan":[{"id":"lap_nama","label":"Nama Kegiatan","type":"text","placeholder":"Contoh: LDKS 2026","isRequired":true,"options":[]},{"id":"lap_kategori","label":"Kategori Kegiatan","type":"dropdown","placeholder":"","isRequired":false,"options":["Kegiatan Rutin","Program Unggulan","Peringatan Hari Besar","Lomba & Kompetisi","Bakti Sosial","Rapat Kerja & Pleno","Lainnya"]},{"id":"lap_tgl","label":"Tanggal Pelaksanaan","type":"date","placeholder":"","isRequired":true,"options":[]},{"id":"lap_lokasi","label":"Lokasi Kegiatan","type":"text","placeholder":"Contoh: Aula Utama","isRequired":false,"options":[]},{"id":"lap_pj","label":"Ketua Pelaksana","type":"text","placeholder":"Nama Penanggung Jawab","isRequired":false,"options":[]},{"id":"lap_anggaran","label":"Anggaran Dana (Rp)","type":"number","placeholder":"0","isRequired":false,"options":[]},{"id":"lap_desk","label":"Deskripsi Kegiatan","type":"text","placeholder":"Uraian ringkas kegiatan...","isRequired":false,"options":[]},{"id":"lap_hasil","label":"Hasil / Capaian","type":"text","placeholder":"Hasil yang diperoleh...","isRequired":false,"options":[]},{"id":"lap_eval","label":"Kendala & Evaluasi","type":"text","placeholder":"Evaluasi kegiatan...","isRequired":false,"options":[]},{"id":"lap_dok","label":"Lampiran / Dokumentasi","type":"file","placeholder":"","isRequired":false,"options":[]}],"proker":[{"id":"prok_nama","label":"Nama Program Kerja","type":"text","placeholder":"Nama program...","isRequired":true,"options":[]},{"id":"prok_sekbid","label":"Divisi / Sekbid","type":"dropdown","placeholder":"","isRequired":false,"options":["SEKBID1","SEKBID2","SEKBID3","SEKBID4","SEKBID5","SEKBID6","SEKBID7","SEKBID8","SEKBID9","SEKBID10"]}],"pelanggaran":[{"id":"pel_saksi","label":"Saksi / Petugas Pencatat","type":"text","placeholder":"Nama petugas...","isRequired":false,"options":[]},{"id":"pel_lokasi","label":"Lokasi Kejadian","type":"text","placeholder":"Contoh: Kantin / Lapangan","isRequired":false,"options":[]},{"id":"pel_sanksi","label":"Sanksi / Tindak Lanjut","type":"text","placeholder":"Tindakan yang diberikan...","isRequired":false,"options":[]},{"id":"pel_ket","label":"Keterangan Tambahan","type":"text","placeholder":"Catatan tambahan...","isRequired":false,"options":[]}],"rekap":[{"id":"rek_dimensi","label":"Dimensi Rekap","type":"select","placeholder":"","isRequired":false,"options":["Per Kelas","Per Siswa","Per Jenis Pelanggaran","Per Tingkat Kelas","Per Status SP"]}],"arsip":[{"id":"ars_folder","label":"Kategori Berkas","type":"dropdown","placeholder":"","isRequired":true,"options":["Surat Masuk","Surat Keluar","Proposal Kegiatan","LPJ Kegiatan","Dokumentasi","SK & Sertifikat"]}]}'::jsonb,
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Auto-migration kolom baru pada app_settings
ALTER TABLE public.app_settings ADD COLUMN IF NOT EXISTS ttd_kepsek TEXT DEFAULT '';
ALTER TABLE public.app_settings ADD COLUMN IF NOT EXISTS ttd_pembina TEXT DEFAULT '';
ALTER TABLE public.app_settings ADD COLUMN IF NOT EXISTS ttd_ketos TEXT DEFAULT '';
ALTER TABLE public.app_settings ADD COLUMN IF NOT EXISTS ttd_sekretaris TEXT DEFAULT '';
ALTER TABLE public.app_settings ADD COLUMN IF NOT EXISTS arsip_allowed_exts JSONB DEFAULT '["pdf","docx","xlsx","pptx","png","jpg","jpeg","zip"]'::jsonb;
ALTER TABLE public.app_settings ADD COLUMN IF NOT EXISTS laporan_fields JSONB DEFAULT '["Nama Kegiatan","Tanggal","Lokasi","Peserta / Sasaran","Deskripsi","Hasil / Capaian","Kendala & Evaluasi"]'::jsonb;
ALTER TABLE public.app_settings ADD COLUMN IF NOT EXISTS pelanggaran_fields JSONB DEFAULT '["Saksi / Petugas","Lokasi Kejadian","Sanksi / Tindak Lanjut","Keterangan Tambahan"]'::jsonb;
ALTER TABLE public.app_settings ADD COLUMN IF NOT EXISTS rekap_types JSONB DEFAULT '["Per Kelas","Per Siswa","Per Jenis Pelanggaran","Per Tingkat Kelas","Per Status SP"]'::jsonb;
ALTER TABLE public.app_settings ADD COLUMN IF NOT EXISTS custom_fields JSONB DEFAULT '{}'::jsonb;

-- 4. Buat Tabel Data Operasional Jika Belum Ada
CREATE TABLE IF NOT EXISTS public.siswa (
    id TEXT PRIMARY KEY,
    nama TEXT NOT NULL,
    kelas TEXT NOT NULL,
    nis TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.jenis_pelanggaran (
    id TEXT PRIMARY KEY,
    nama TEXT NOT NULL,
    poin INTEGER NOT NULL DEFAULT 5,
    kategori TEXT DEFAULT 'Umum',
    hari_aktif JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.pelanggaran (
    id TEXT PRIMARY KEY,
    siswa_id TEXT NOT NULL,
    jenis_id TEXT NOT NULL,
    tanggal TIMESTAMPTZ DEFAULT now(),
    keterangan TEXT DEFAULT '',
    petugas TEXT DEFAULT '',
    foto TEXT DEFAULT '',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.proker (
    id TEXT PRIMARY KEY,
    nama TEXT NOT NULL,
    deskripsi TEXT DEFAULT '',
    sekbid TEXT NOT NULL,
    penanggung_jawab TEXT DEFAULT '',
    tanggal_rencana TIMESTAMPTZ DEFAULT now(),
    tanggal_realisasi TIMESTAMPTZ,
    status TEXT DEFAULT 'belum',
    keterangan TEXT DEFAULT '',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.laporan_kegiatan (
    id TEXT PRIMARY KEY,
    nama_kegiatan TEXT NOT NULL,
    kategori TEXT DEFAULT 'Umum',
    tanggal TIMESTAMPTZ DEFAULT now(),
    lokasi TEXT DEFAULT '',
    penanggung_jawab TEXT DEFAULT '',
    anggaran NUMERIC DEFAULT 0,
    deskripsi TEXT DEFAULT '',
    hasil TEXT DEFAULT '',
    kendala TEXT DEFAULT '',
    dokumentasi TEXT DEFAULT '',
    sekbid TEXT DEFAULT '',
    created_by TEXT DEFAULT '',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.arsip (
    id TEXT PRIMARY KEY,
    nama_file TEXT NOT NULL,
    kategori TEXT DEFAULT 'Umum',
    file_path TEXT DEFAULT '',
    ukuran_kb INTEGER DEFAULT 0,
    tipe_file TEXT DEFAULT '',
    tanggal_unggah TIMESTAMPTZ DEFAULT now(),
    diunggah_oleh TEXT DEFAULT '',
    keterangan TEXT DEFAULT '',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.file_riwayat (
    id TEXT PRIMARY KEY,
    arsip_id TEXT NOT NULL,
    nama_file TEXT NOT NULL,
    file_path TEXT DEFAULT '',
    diubah_oleh TEXT DEFAULT '',
    tanggal_ubah TIMESTAMPTZ DEFAULT now(),
    keterangan TEXT DEFAULT ''
);

-- 5. Aktifkan Row Level Security (RLS) & Replica Identity untuk Semua Tabel
ALTER TABLE public.accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sekbid ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.siswa ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.jenis_pelanggaran ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pelanggaran ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.proker ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.laporan_kegiatan ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.arsip ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.file_riwayat ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.accounts REPLICA IDENTITY FULL;
ALTER TABLE public.app_settings REPLICA IDENTITY FULL;
ALTER TABLE public.sekbid REPLICA IDENTITY FULL;
ALTER TABLE public.siswa REPLICA IDENTITY FULL;
ALTER TABLE public.jenis_pelanggaran REPLICA IDENTITY FULL;
ALTER TABLE public.pelanggaran REPLICA IDENTITY FULL;
ALTER TABLE public.proker REPLICA IDENTITY FULL;
ALTER TABLE public.laporan_kegiatan REPLICA IDENTITY FULL;
ALTER TABLE public.arsip REPLICA IDENTITY FULL;
ALTER TABLE public.file_riwayat REPLICA IDENTITY FULL;

-- 6. Kebijakan Akses (Policy) untuk Public & Authenticated
DO $$
DECLARE
    tbl text;
BEGIN
    FOR tbl IN SELECT unnest(ARRAY[
        'accounts', 'app_settings', 'sekbid', 'siswa',
        'jenis_pelanggaran', 'pelanggaran', 'proker',
        'laporan_kegiatan', 'arsip', 'file_riwayat'
    ])
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS "Allow all access to %I for all" ON public.%I', tbl, tbl);
        EXECUTE format('CREATE POLICY "Allow all access to %I for all" ON public.%I FOR ALL TO anon, authenticated USING (true) WITH CHECK (true)', tbl, tbl);
    END LOOP;
END $$;

-- 7. Aktifkan Supabase Realtime untuk Semua Tabel
DO $$
DECLARE
    tbl text;
BEGIN
    FOR tbl IN SELECT unnest(ARRAY[
        'accounts', 'app_settings', 'sekbid', 'siswa',
        'jenis_pelanggaran', 'pelanggaran', 'proker',
        'laporan_kegiatan', 'arsip', 'file_riwayat'
    ])
    LOOP
        IF NOT EXISTS (
            SELECT 1 FROM pg_publication_tables
            WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = tbl
        ) THEN
            EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', tbl);
        END IF;
    END LOOP;
END $$;

-- 8. Masukkan / Seed Konfigurasi Bawaan (Default App Settings)
INSERT INTO public.app_settings (id, app_name, app_subtitle, logo_url, primary_color, default_theme_mode, default_language)
VALUES ('global_config', 'OSIS Management', 'Sistem Manajemen OSIS Digital', '', '0xFF00B4D8', 'system', 'id')
ON CONFLICT (id) DO UPDATE SET
    updated_at = now();

-- 9. Masukkan / Seed Data Akun Bawaan (Sesuai Struktur Database OSIS)
INSERT INTO public.accounts (username, password, role, display_name) VALUES
('ADMIN', 'EndyMahavira24!!@', 'ADMIN', 'Admin Aplikasi OSIS Management'),
('PEMBINA', 'PembinaOSIS', 'PEMBINA', 'Pembina OSIS'),
('KESISWAAN', 'KesiswaanBaknus', 'KESISWAAN', 'Staf Kesiswaan'),
('KETUA', 'OSISBN666', 'KETUA', 'Ketua OSIS'),
('WAKIL', 'OSISBN666', 'WAKIL', 'Wakil Ketua OSIS'),
('SEKRETARIS', 'OSISBN666', 'SEKRETARIS', 'Sekretaris OSIS'),
('BENDAHARA', 'OSISBN666', 'BENDAHARA', 'Bendahara OSIS'),
('SEKBID1', 'KeimananTakwa', 'SEKBID', 'Sekbid 1 (Keimanan & Ketakwaan)'),
('SEKBID2', 'BudiPekerti', 'SEKBID', 'Sekbid 2 (Budi Pekerti)'),
('SEKBID3', 'Bela Negara', 'SEKBID', 'Sekbid 3 (Bela Negara)'),
('SEKBID4', 'PrestasiAkademik', 'SEKBID', 'Sekbid 4 (Prestasi Akademik)'),
('SEKBID5', 'Demokrasi', 'SEKBID', 'Sekbid 5 (Demokrasi)'),
('SEKBID6', 'Kewirausahaan', 'SEKBID', 'Sekbid 6 (Kewirausahaan)'),
('SEKBID7', 'KebugaranJasmani', 'SEKBID', 'Sekbid 7 (Kebugaran Jasmani)'),
('SEKBID8', 'SastraBudaya', 'SEKBID', 'Sekbid 8 (Sastra & Budaya)'),
('SEKBID9', 'TeknologiInformasi', 'SEKBID', 'Sekbid 9 (Teknologi Informasi)'),
('SEKBID10', 'KomunikasiBahasa', 'SEKBID', 'Sekbid 10 (Komunikasi & Bahasa)')
ON CONFLICT (username) DO UPDATE SET
    password = EXCLUDED.password,
    role = EXCLUDED.role,
    display_name = EXCLUDED.display_name,
    updated_at = now();
