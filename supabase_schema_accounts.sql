-- ==============================================================================
-- SKRIP LENGKAP TABEL, HAK AKSES, REALTIME & SEED DATA (OSIS MANAGEMENT)
-- Jalankan skrip ini di Supabase SQL Editor (Dashboard Supabase -> SQL Editor)
-- Skrip ini memastikan:
-- 1. Semua kolom input (Laporan, Proker, Pelanggaran, Rekap, Arsip) terdaftar & sinkron
--    baik dalam mode Offline (Local Cache + Sync Queue) maupun Online (Supabase Realtime).
-- 2. Setiap tabel memiliki kolom extra_fields (JSONB) untuk menyimpan input fleksibel/dinamis.
-- 3. Warna tema (primary_color) & pengaturan input tersinkronisasi realtime ke semua akun.
-- 4. RLS, Publikasi Realtime, dan Hak Akses anon/authenticated aktif penuh.
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

-- 3. Buat Tabel 'app_settings' (Konfigurasi Global, Form Builder & Realtime Sync)
CREATE TABLE IF NOT EXISTS public.app_settings (
    id TEXT PRIMARY KEY DEFAULT 'global_config',
    app_name TEXT DEFAULT 'OSIS Management',
    app_subtitle TEXT DEFAULT 'Sistem Manajemen OSIS Digital',
    logo_url TEXT DEFAULT '',
    primary_color TEXT DEFAULT '0xFF00B4D8',
    default_theme_mode TEXT DEFAULT 'system',
    default_language TEXT DEFAULT 'id',
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
    custom_fields JSONB DEFAULT '{"laporan":[{"id":"lap_nama","label":"Nama Kegiatan","type":"text","placeholder":"Contoh: LDKS 2026","isRequired":true,"options":[]},{"id":"lap_kategori","label":"Kategori Kegiatan","type":"dropdown","placeholder":"","isRequired":false,"options":["Kegiatan Rutin","Program Unggulan","Peringatan Hari Besar","Lomba & Kompetisi","Bakti Sosial","Rapat Kerja & Pleno","Lainnya"]},{"id":"lap_tgl","label":"Tanggal Pelaksanaan","type":"date","placeholder":"","isRequired":true,"options":[]},{"id":"lap_lokasi","label":"Lokasi Kegiatan","type":"text","placeholder":"Contoh: Aula Utama","isRequired":false,"options":[]},{"id":"lap_pj","label":"Ketua Pelaksana","type":"text","placeholder":"Nama Penanggung Jawab","isRequired":false,"options":[]},{"id":"lap_anggaran","label":"Anggaran Dana (Rp)","type":"number","placeholder":"0","isRequired":false,"options":[]},{"id":"lap_desk","label":"Deskripsi Kegiatan","type":"text","placeholder":"Uraian ringkas kegiatan...","isRequired":false,"options":[]},{"id":"lap_hasil","label":"Hasil / Capaian","type":"text","placeholder":"Hasil yang diperoleh...","isRequired":false,"options":[]},{"id":"lap_eval","label":"Kendala & Evaluasi","type":"text","placeholder":"Evaluasi kegiatan...","isRequired":false,"options":[]},{"id":"lap_dok","label":"Lampiran / Dokumentasi","type":"file","placeholder":"","isRequired":false,"options":[]}],"proker":[{"id":"prok_nama","label":"Nama Program Kerja","type":"text","placeholder":"Nama program...","isRequired":true,"options":[]},{"id":"prok_sekbid","label":"Divisi / Sekbid","type":"dropdown","placeholder":"","isRequired":false,"options":["Sekbid 1","Sekbid 2","Sekbid 3","Sekbid 4","Sekbid 5","Sekbid 6","Sekbid 7","Sekbid 8","Sekbid 9","Sekbid 10"]},{"id":"prok_pj","label":"Penanggung Jawab","type":"text","placeholder":"Nama PJ proker","isRequired":false,"options":[]},{"id":"prok_tgl_rencana","label":"Tanggal Rencana","type":"date","placeholder":"","isRequired":true,"options":[]},{"id":"prok_tgl_realisasi","label":"Tanggal Realisasi","type":"date","placeholder":"","isRequired":false,"options":[]},{"id":"prok_status","label":"Status Proker","type":"dropdown","placeholder":"","isRequired":false,"options":["Belum Berjalan","Sedang Berjalan","Selesai"]},{"id":"prok_desk","label":"Deskripsi Program","type":"text","placeholder":"Rincian proker...","isRequired":false,"options":[]},{"id":"prok_ket","label":"Keterangan Tambahan","type":"text","placeholder":"Catatan tambahan...","isRequired":false,"options":[]}],"pelanggaran":[{"id":"pel_siswa","label":"Nama Siswa","type":"select","placeholder":"Pilih siswa...","isRequired":true,"options":[]},{"id":"pel_tgl","label":"Tanggal Kejadian","type":"date","placeholder":"","isRequired":true,"options":[]},{"id":"pel_jenis","label":"Jenis Pelanggaran","type":"select","placeholder":"Pilih jenis tata tertib...","isRequired":true,"options":[]},{"id":"pel_lokasi","label":"Lokasi Kejadian","type":"text","placeholder":"Contoh: Kantin / Kelas","isRequired":false,"options":[]},{"id":"pel_petugas","label":"Petugas / Saksi","type":"text","placeholder":"Nama pencatat atau saksi","isRequired":false,"options":[]},{"id":"pel_sanksi","label":"Sanksi / Tindak Lanjut","type":"dropdown","placeholder":"","isRequired":false,"options":["Teguran Lisan","Teguran Tertulis (SP 1)","Peringatan Keras (SP 2)","Pemanggilan Orang Tua (SP 3)","Pembersihan Lingkungan","Skorsing"]},{"id":"pel_ket","label":"Keterangan Tambahan","type":"text","placeholder":"Catatan detail kejadian...","isRequired":false,"options":[]}],"rekap":[{"id":"rek_dimensi","label":"Dimensi Rekap","type":"dropdown","placeholder":"","isRequired":false,"options":["Per Kelas","Per Siswa","Per Jenis Pelanggaran","Per Tingkat Kelas","Per Status SP"]}],"arsip":[{"id":"ars_nama","label":"Nama Dokumen / Berkas","type":"text","placeholder":"Judul berkas...","isRequired":true,"options":[]},{"id":"ars_folder","label":"Folder Kategori","type":"dropdown","placeholder":"","isRequired":true,"options":["Surat Masuk","Surat Keluar","Proposal Kegiatan","LPJ Kegiatan","Dokumentasi","SK & Sertifikat"]},{"id":"ars_file","label":"File Dokumen","type":"file","placeholder":"","isRequired":true,"options":[]},{"id":"ars_ket","label":"Keterangan Berkas","type":"text","placeholder":"Keterangan tambahan...","isRequired":false,"options":[]}]}'::jsonb,
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Pastikan semua kolom app_settings selalu ada jika tabel sudah dibuat sebelumnya
ALTER TABLE public.app_settings ADD COLUMN IF NOT EXISTS app_name TEXT DEFAULT 'OSIS Management';
ALTER TABLE public.app_settings ADD COLUMN IF NOT EXISTS app_subtitle TEXT DEFAULT 'Sistem Manajemen OSIS Digital';
ALTER TABLE public.app_settings ADD COLUMN IF NOT EXISTS logo_url TEXT DEFAULT '';
ALTER TABLE public.app_settings ADD COLUMN IF NOT EXISTS primary_color TEXT DEFAULT '0xFF00B4D8';
ALTER TABLE public.app_settings ADD COLUMN IF NOT EXISTS default_theme_mode TEXT DEFAULT 'system';
ALTER TABLE public.app_settings ADD COLUMN IF NOT EXISTS default_language TEXT DEFAULT 'id';
ALTER TABLE public.app_settings ADD COLUMN IF NOT EXISTS sp1_threshold INTEGER DEFAULT 20;
ALTER TABLE public.app_settings ADD COLUMN IF NOT EXISTS sp2_threshold INTEGER DEFAULT 50;
ALTER TABLE public.app_settings ADD COLUMN IF NOT EXISTS sp3_threshold INTEGER DEFAULT 75;
ALTER TABLE public.app_settings ADD COLUMN IF NOT EXISTS skorsing_threshold INTEGER DEFAULT 100;
ALTER TABLE public.app_settings ADD COLUMN IF NOT EXISTS arsip_max_mb INTEGER DEFAULT 25;
ALTER TABLE public.app_settings ADD COLUMN IF NOT EXISTS arsip_folders JSONB DEFAULT '["Surat Masuk","Surat Keluar","Proposal Kegiatan","LPJ Kegiatan","Dokumentasi","SK & Sertifikat"]'::jsonb;
ALTER TABLE public.app_settings ADD COLUMN IF NOT EXISTS arsip_allowed_exts JSONB DEFAULT '["pdf","docx","xlsx","pptx","png","jpg","jpeg","zip"]'::jsonb;
ALTER TABLE public.app_settings ADD COLUMN IF NOT EXISTS sekbid_list JSONB DEFAULT '["SEKBID1","SEKBID2","SEKBID3","SEKBID4","SEKBID5","SEKBID6","SEKBID7","SEKBID8","SEKBID9","SEKBID10"]'::jsonb;
ALTER TABLE public.app_settings ADD COLUMN IF NOT EXISTS laporan_categories JSONB DEFAULT '["Kegiatan Rutin","Program Unggulan","Peringatan Hari Besar","Lomba & Kompetisi","Bakti Sosial","Rapat Kerja & Pleno","Lainnya"]'::jsonb;
ALTER TABLE public.app_settings ADD COLUMN IF NOT EXISTS laporan_fields JSONB DEFAULT '["Nama Kegiatan","Tanggal","Lokasi","Peserta / Sasaran","Deskripsi","Hasil / Capaian","Kendala & Evaluasi"]'::jsonb;
ALTER TABLE public.app_settings ADD COLUMN IF NOT EXISTS pelanggaran_fields JSONB DEFAULT '["Saksi / Petugas","Lokasi Kejadian","Sanksi / Tindak Lanjut","Keterangan Tambahan"]'::jsonb;
ALTER TABLE public.app_settings ADD COLUMN IF NOT EXISTS rekap_types JSONB DEFAULT '["Per Kelas","Per Siswa","Per Jenis Pelanggaran","Per Tingkat Kelas","Per Status SP"]'::jsonb;
ALTER TABLE public.app_settings ADD COLUMN IF NOT EXISTS custom_fields JSONB DEFAULT '{}'::jsonb;

-- 4. Buat Tabel Data Operasional & Kolom-Kolom Terstandarisasi

-- A. Tabel 'siswa'
CREATE TABLE IF NOT EXISTS public.siswa (
    id TEXT PRIMARY KEY,
    nama TEXT NOT NULL,
    kelas TEXT NOT NULL,
    nis TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- B. Tabel 'jenis_pelanggaran'
CREATE TABLE IF NOT EXISTS public.jenis_pelanggaran (
    id TEXT PRIMARY KEY,
    nama TEXT NOT NULL,
    poin INTEGER NOT NULL DEFAULT 5,
    kategori TEXT DEFAULT 'Umum',
    hari_aktif JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.jenis_pelanggaran ADD COLUMN IF NOT EXISTS hari_aktif JSONB DEFAULT '[]'::jsonb;

-- C. Tabel 'pelanggaran'
CREATE TABLE IF NOT EXISTS public.pelanggaran (
    id TEXT PRIMARY KEY,
    siswa_id TEXT NOT NULL,
    jenis_id TEXT NOT NULL,
    tanggal TIMESTAMPTZ DEFAULT now(),
    keterangan TEXT DEFAULT '',
    nama_siswa TEXT DEFAULT '',
    kelas_siswa TEXT DEFAULT '',
    nis_siswa TEXT DEFAULT '',
    petugas TEXT DEFAULT '',
    foto TEXT DEFAULT '',
    extra_fields JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.pelanggaran ADD COLUMN IF NOT EXISTS nama_siswa TEXT DEFAULT '';
ALTER TABLE public.pelanggaran ADD COLUMN IF NOT EXISTS kelas_siswa TEXT DEFAULT '';
ALTER TABLE public.pelanggaran ADD COLUMN IF NOT EXISTS nis_siswa TEXT DEFAULT '';
ALTER TABLE public.pelanggaran ADD COLUMN IF NOT EXISTS petugas TEXT DEFAULT '';
ALTER TABLE public.pelanggaran ADD COLUMN IF NOT EXISTS foto TEXT DEFAULT '';
ALTER TABLE public.pelanggaran ADD COLUMN IF NOT EXISTS extra_fields JSONB DEFAULT '{}'::jsonb;

-- D. Tabel 'proker'
CREATE TABLE IF NOT EXISTS public.proker (
    id TEXT PRIMARY KEY,
    nama TEXT NOT NULL,
    deskripsi TEXT DEFAULT '',
    sekbid TEXT NOT NULL,
    penanggung_jawab TEXT DEFAULT '',
    tanggal_rencana TIMESTAMPTZ DEFAULT now(),
    tanggal_realisasi TIMESTAMPTZ,
    status TEXT DEFAULT 'Belum',
    keterangan TEXT DEFAULT '',
    extra_fields JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.proker ADD COLUMN IF NOT EXISTS deskripsi TEXT DEFAULT '';
ALTER TABLE public.proker ADD COLUMN IF NOT EXISTS penanggung_jawab TEXT DEFAULT '';
ALTER TABLE public.proker ADD COLUMN IF NOT EXISTS tanggal_rencana TIMESTAMPTZ DEFAULT now();
ALTER TABLE public.proker ADD COLUMN IF NOT EXISTS tanggal_realisasi TIMESTAMPTZ;
ALTER TABLE public.proker ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'Belum';
ALTER TABLE public.proker ADD COLUMN IF NOT EXISTS keterangan TEXT DEFAULT '';
ALTER TABLE public.proker ADD COLUMN IF NOT EXISTS extra_fields JSONB DEFAULT '{}'::jsonb;

-- E. Tabel 'laporan_kegiatan'
CREATE TABLE IF NOT EXISTS public.laporan_kegiatan (
    id TEXT PRIMARY KEY,
    judul TEXT NOT NULL,
    sekbid TEXT DEFAULT '',
    penanggung_jawab TEXT DEFAULT '',
    tanggal_kegiatan TIMESTAMPTZ DEFAULT now(),
    lokasi TEXT DEFAULT '',
    deskripsi TEXT DEFAULT '',
    hasil_capaian TEXT DEFAULT '',
    kendala_saran TEXT DEFAULT '',
    status TEXT DEFAULT 'Draft',
    tanggal_buat TIMESTAMPTZ DEFAULT now(),
    peserta JSONB DEFAULT '[]'::jsonb,
    pembuat_id TEXT DEFAULT '',
    extra_fields JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.laporan_kegiatan ADD COLUMN IF NOT EXISTS judul TEXT;
ALTER TABLE public.laporan_kegiatan ADD COLUMN IF NOT EXISTS sekbid TEXT DEFAULT '';
ALTER TABLE public.laporan_kegiatan ADD COLUMN IF NOT EXISTS penanggung_jawab TEXT DEFAULT '';
ALTER TABLE public.laporan_kegiatan ADD COLUMN IF NOT EXISTS tanggal_kegiatan TIMESTAMPTZ DEFAULT now();
ALTER TABLE public.laporan_kegiatan ADD COLUMN IF NOT EXISTS lokasi TEXT DEFAULT '';
ALTER TABLE public.laporan_kegiatan ADD COLUMN IF NOT EXISTS deskripsi TEXT DEFAULT '';
ALTER TABLE public.laporan_kegiatan ADD COLUMN IF NOT EXISTS hasil_capaian TEXT DEFAULT '';
ALTER TABLE public.laporan_kegiatan ADD COLUMN IF NOT EXISTS kendala_saran TEXT DEFAULT '';
ALTER TABLE public.laporan_kegiatan ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'Draft';
ALTER TABLE public.laporan_kegiatan ADD COLUMN IF NOT EXISTS tanggal_buat TIMESTAMPTZ DEFAULT now();
ALTER TABLE public.laporan_kegiatan ADD COLUMN IF NOT EXISTS peserta JSONB DEFAULT '[]'::jsonb;
ALTER TABLE public.laporan_kegiatan ADD COLUMN IF NOT EXISTS pembuat_id TEXT DEFAULT '';
ALTER TABLE public.laporan_kegiatan ADD COLUMN IF NOT EXISTS extra_fields JSONB DEFAULT '{}'::jsonb;

-- F. Tabel 'arsip'
CREATE TABLE IF NOT EXISTS public.arsip (
    id TEXT PRIMARY KEY,
    judul TEXT NOT NULL,
    kategori TEXT DEFAULT 'Lainnya',
    deskripsi TEXT DEFAULT '',
    nomor_surat TEXT DEFAULT '',
    tanggal TIMESTAMPTZ DEFAULT now(),
    pembuat_id TEXT DEFAULT '',
    file_url TEXT DEFAULT '',
    keterangan TEXT DEFAULT '',
    extra_fields JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.arsip ADD COLUMN IF NOT EXISTS judul TEXT;
ALTER TABLE public.arsip ADD COLUMN IF NOT EXISTS kategori TEXT DEFAULT 'Lainnya';
ALTER TABLE public.arsip ADD COLUMN IF NOT EXISTS deskripsi TEXT DEFAULT '';
ALTER TABLE public.arsip ADD COLUMN IF NOT EXISTS nomor_surat TEXT DEFAULT '';
ALTER TABLE public.arsip ADD COLUMN IF NOT EXISTS tanggal TIMESTAMPTZ DEFAULT now();
ALTER TABLE public.arsip ADD COLUMN IF NOT EXISTS pembuat_id TEXT DEFAULT '';
ALTER TABLE public.arsip ADD COLUMN IF NOT EXISTS file_url TEXT DEFAULT '';
ALTER TABLE public.arsip ADD COLUMN IF NOT EXISTS keterangan TEXT DEFAULT '';
ALTER TABLE public.arsip ADD COLUMN IF NOT EXISTS extra_fields JSONB DEFAULT '{}'::jsonb;

-- G. Tabel 'file_riwayat'
CREATE TABLE IF NOT EXISTS public.file_riwayat (
    id TEXT PRIMARY KEY,
    nama_file TEXT NOT NULL,
    tanggal_upload TIMESTAMPTZ DEFAULT now(),
    nis_list JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.file_riwayat ADD COLUMN IF NOT EXISTS nis_list JSONB DEFAULT '[]'::jsonb;

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

-- 6. Hak Akses (Policy & Grant) untuk anon, authenticated, dan service_role
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;

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
        EXECUTE format('DROP POLICY IF EXISTS "Enable all access for all users" ON public.%I', tbl, tbl);
        EXECUTE format('CREATE POLICY "Allow all access to %I for all" ON public.%I FOR ALL TO anon, authenticated USING (true) WITH CHECK (true)', tbl, tbl);
        EXECUTE format('GRANT ALL ON public.%I TO anon, authenticated, service_role', tbl, tbl);
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

-- 8. Masukkan / Seed Konfigurasi Bawaan (Default App Settings & Form Builder Custom Fields)
INSERT INTO public.app_settings (
    id, app_name, app_subtitle, logo_url, primary_color, default_theme_mode, default_language,
    sp1_threshold, sp2_threshold, sp3_threshold, skorsing_threshold, arsip_max_mb, arsip_folders, arsip_allowed_exts,
    sekbid_list, laporan_categories, laporan_fields, pelanggaran_fields, rekap_types, custom_fields
)
VALUES (
    'global_config',
    'OSIS Management',
    'Sistem Manajemen OSIS Digital',
    '',
    '0xFF00B4D8',
    'system',
    'id',
    20,
    50,
    75,
    100,
    25,
    '["Surat Masuk","Surat Keluar","Proposal Kegiatan","LPJ Kegiatan","Dokumentasi","SK & Sertifikat"]'::jsonb,
    '["pdf","docx","xlsx","pptx","png","jpg","jpeg","zip"]'::jsonb,
    '["SEKBID1","SEKBID2","SEKBID3","SEKBID4","SEKBID5","SEKBID6","SEKBID7","SEKBID8","SEKBID9","SEKBID10"]'::jsonb,
    '["Kegiatan Rutin","Program Unggulan","Peringatan Hari Besar","Lomba & Kompetisi","Bakti Sosial","Rapat Kerja & Pleno","Lainnya"]'::jsonb,
    '["Nama Kegiatan","Tanggal","Lokasi","Peserta / Sasaran","Deskripsi","Hasil / Capaian","Kendala & Evaluasi"]'::jsonb,
    '["Saksi / Petugas","Lokasi Kejadian","Sanksi / Tindak Lanjut","Keterangan Tambahan"]'::jsonb,
    '["Per Kelas","Per Siswa","Per Jenis Pelanggaran","Per Tingkat Kelas","Per Status SP"]'::jsonb,
    '{"laporan":[{"id":"lap_nama","label":"Nama Kegiatan","type":"text","placeholder":"Contoh: LDKS 2026","isRequired":true,"options":[]},{"id":"lap_kategori","label":"Kategori Kegiatan","type":"dropdown","placeholder":"","isRequired":false,"options":["Kegiatan Rutin","Program Unggulan","Peringatan Hari Besar","Lomba & Kompetisi","Bakti Sosial","Rapat Kerja & Pleno","Lainnya"]},{"id":"lap_tgl","label":"Tanggal Pelaksanaan","type":"date","placeholder":"","isRequired":true,"options":[]},{"id":"lap_lokasi","label":"Lokasi Kegiatan","type":"text","placeholder":"Contoh: Aula Utama","isRequired":false,"options":[]},{"id":"lap_pj","label":"Ketua Pelaksana","type":"text","placeholder":"Nama Penanggung Jawab","isRequired":false,"options":[]},{"id":"lap_anggaran","label":"Anggaran Dana (Rp)","type":"number","placeholder":"0","isRequired":false,"options":[]},{"id":"lap_desk","label":"Deskripsi Kegiatan","type":"text","placeholder":"Uraian ringkas kegiatan...","isRequired":false,"options":[]},{"id":"lap_hasil","label":"Hasil / Capaian","type":"text","placeholder":"Hasil yang diperoleh...","isRequired":false,"options":[]},{"id":"lap_eval","label":"Kendala & Evaluasi","type":"text","placeholder":"Evaluasi kegiatan...","isRequired":false,"options":[]},{"id":"lap_dok","label":"Lampiran / Dokumentasi","type":"file","placeholder":"","isRequired":false,"options":[]}],"proker":[{"id":"prok_nama","label":"Nama Program Kerja","type":"text","placeholder":"Nama program...","isRequired":true,"options":[]},{"id":"prok_sekbid","label":"Divisi / Sekbid","type":"dropdown","placeholder":"","isRequired":false,"options":["Sekbid 1","Sekbid 2","Sekbid 3","Sekbid 4","Sekbid 5","Sekbid 6","Sekbid 7","Sekbid 8","Sekbid 9","Sekbid 10"]},{"id":"prok_pj","label":"Penanggung Jawab","type":"text","placeholder":"Nama PJ proker","isRequired":false,"options":[]},{"id":"prok_tgl_rencana","label":"Tanggal Rencana","type":"date","placeholder":"","isRequired":true,"options":[]},{"id":"prok_tgl_realisasi","label":"Tanggal Realisasi","type":"date","placeholder":"","isRequired":false,"options":[]},{"id":"prok_status","label":"Status Proker","type":"dropdown","placeholder":"","isRequired":false,"options":["Belum Berjalan","Sedang Berjalan","Selesai"]},{"id":"prok_desk","label":"Deskripsi Program","type":"text","placeholder":"Rincian proker...","isRequired":false,"options":[]},{"id":"prok_ket","label":"Keterangan Tambahan","type":"text","placeholder":"Catatan tambahan...","isRequired":false,"options":[]}],"pelanggaran":[{"id":"pel_siswa","label":"Nama Siswa","type":"select","placeholder":"Pilih siswa...","isRequired":true,"options":[]},{"id":"pel_tgl","label":"Tanggal Kejadian","type":"date","placeholder":"","isRequired":true,"options":[]},{"id":"pel_jenis","label":"Jenis Pelanggaran","type":"select","placeholder":"Pilih jenis tata tertib...","isRequired":true,"options":[]},{"id":"pel_lokasi","label":"Lokasi Kejadian","type":"text","placeholder":"Contoh: Kantin / Kelas","isRequired":false,"options":[]},{"id":"pel_petugas","label":"Petugas / Saksi","type":"text","placeholder":"Nama pencatat atau saksi","isRequired":false,"options":[]},{"id":"pel_sanksi","label":"Sanksi / Tindak Lanjut","type":"dropdown","placeholder":"","isRequired":false,"options":["Teguran Lisan","Teguran Tertulis (SP 1)","Peringatan Keras (SP 2)","Pemanggilan Orang Tua (SP 3)","Pembersihan Lingkungan","Skorsing"]},{"id":"pel_ket","label":"Keterangan Tambahan","type":"text","placeholder":"Catatan detail kejadian...","isRequired":false,"options":[]}],"rekap":[{"id":"rek_dimensi","label":"Dimensi Rekap","type":"dropdown","placeholder":"","isRequired":false,"options":["Per Kelas","Per Siswa","Per Jenis Pelanggaran","Per Tingkat Kelas","Per Status SP"]}],"arsip":[{"id":"ars_nama","label":"Nama Dokumen / Berkas","type":"text","placeholder":"Judul berkas...","isRequired":true,"options":[]},{"id":"ars_folder","label":"Folder Kategori","type":"dropdown","placeholder":"","isRequired":true,"options":["Surat Masuk","Surat Keluar","Proposal Kegiatan","LPJ Kegiatan","Dokumentasi","SK & Sertifikat"]},{"id":"ars_file","label":"File Dokumen","type":"file","placeholder":"","isRequired":true,"options":[]},{"id":"ars_ket","label":"Keterangan Berkas","type":"text","placeholder":"Keterangan tambahan...","isRequired":false,"options":[]}]}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
    primary_color = COALESCE(public.app_settings.primary_color, EXCLUDED.primary_color),
    custom_fields = CASE 
        WHEN public.app_settings.custom_fields IS NULL OR public.app_settings.custom_fields = '{}'::jsonb 
        THEN EXCLUDED.custom_fields 
        ELSE public.app_settings.custom_fields 
    END,
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
