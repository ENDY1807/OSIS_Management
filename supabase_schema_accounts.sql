-- ==============================================================================
-- SKRIP TABEL AKUN & AUTENTIKASI SUPABASE (OSIS MANAGEMENT)
-- Jalankan skrip ini di Supabase SQL Editor (Dashboard Supabase -> SQL Editor)
-- ==============================================================================

-- 1. Buat Tabel 'accounts'
CREATE TABLE IF NOT EXISTS public.accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username TEXT UNIQUE NOT NULL,
    password TEXT NOT NULL,
    role TEXT,
    display_name TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Aktifkan Row Level Security (RLS)
ALTER TABLE public.accounts ENABLE ROW LEVEL SECURITY;

-- 3. Kebijakan Akses (Policy) untuk Public/Anon (Read, Insert, Update, Delete)
DROP POLICY IF EXISTS "Allow all access to accounts for anon" ON public.accounts;
CREATE POLICY "Allow all access to accounts for anon"
ON public.accounts
FOR ALL
TO anon, authenticated
USING (true)
WITH CHECK (true);

-- 4. Aktifkan Supabase Realtime untuk tabel 'accounts'
ALTER PUBLICATION supabase_realtime ADD TABLE public.accounts;

-- 5. Masukkan / Seed Data Akun Bawaan (Default Accounts)
INSERT INTO public.accounts (username, password, role, display_name) VALUES
('PEMBINA', 'PembinaOSIS', 'PEMBINA', 'Pembina OSIS'),
('KESISWAAN', 'KesiswaanBaknus', 'KESISWAAN', 'Staf Kesiswaan'),
('KETUA', 'OSISBN666', 'KETUA', 'Ketua OSIS'),
('WAKIL', 'OSISBN666', 'WAKIL', 'Wakil Ketua OSIS'),
('SEKRETARIS', 'OSISBN666', 'SEKRETARIS', 'Sekretaris OSIS'),
('BENDAHARA', 'OSISBN66', 'BENDAHARA', 'Bendahara OSIS'),
('SEKBID1', 'KeimananTakwa', 'SEKBID', 'Sekbid Keimanan & Takwa'),
('SEKBID2', 'BudiPekerti', 'SEKBID', 'Sekbid Budi Pekerti'),
('SEKBID3', 'Kepribadian', 'SEKBID', 'Sekbid Kepribadian'),
('SEKBID4', 'PrestasiAkademik', 'SEKBID', 'Sekbid Prestasi Akademik'),
('SEKBID5', 'Demokrasi', 'SEKBID', 'Sekbid Demokrasi'),
('SEKBID6', 'Kreativitas', 'SEKBID', 'Sekbid Kreativitas'),
('SEKBID7', 'Kesehatan', 'SEKBID', 'Sekbid Kesehatan'),
('SEKBID8', 'SastraBudaya', 'SEKBID', 'Sekbid Sastra & Budaya'),
('SEKBID9', 'TeknologiInformasi', 'SEKBID', 'Sekbid Teknologi Informasi'),
('SEKBID10', 'KomunikasiBahasa', 'SEKBID', 'Sekbid Komunikasi & Bahasa')
ON CONFLICT (username) DO NOTHING;
