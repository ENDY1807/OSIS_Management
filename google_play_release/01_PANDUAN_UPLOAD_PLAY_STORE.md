# 🚀 PANDUAN LENGKAP UPLOAD APLIKASI KE GOOGLE PLAY CONSOLE
**Aplikasi:** OSIS Management  
**Package Name:** `id.sch.baknus.osisjurnal`  
**Target Rilis:** Google Play Store (Production / Closed Testing)

---

## 📋 DAFTAR ISI
1. [Persiapan Akun Google Play Console](#1-persiapan-akun-google-play-console)
2. [Build Android App Bundle (.aab)](#2-build-android-app-bundle-aab)
3. [Langkah 1: Membuat Aplikasi Baru di Console](#langkah-1-membuat-aplikasi-baru-di-console)
4. [Langkah 2: Menyiapkan Detail Listing Toko (Store Listing)](#langkah-2-menyiapkan-detail-listing-toko-store-listing)
5. [Langkah 3: Mengisi Konten Aplikasi & Kuisioner Kebijakan](#langkah-3-mengisi-konten-aplikasi--kuisioner-kebijakan)
6. [Langkah 4: Mengisi Kuisioner Keamanan Data (Data Safety)](#langkah-4-mengisi-kuisioner-keamanan-data-data-safety)
7. [Langkah 5: Mengupload File .aab & Membuat Rilis](#langkah-5-mengupload-file-aab--membuat-rilis)
8. [Langkah 6: Aturan Khusus Akun Personal (20 Penguji / Closed Testing)](#langkah-6-aturan-khusus-akun-personal-20-penguji-closed-testing)
9. [Langkah 7: Pengajuan Review & Publikasi](#langkah-7-pengajuan-review--publikasi)

---

## 1. PERSIAPAN AKUN GOOGLE PLAY CONSOLE
Jika Anda belum memiliki akun developer:
1. Kunjungi: https://play.google.com/console/signup
2. Login menggunakan akun Google Anda.
3. Pilih tipe akun:
   - **Organisasi (Sekolah / Lembaga / PT)**: Membutuhkan D-U-N-S Number, tidak memerlukan syarat 20 tester 14 hari.
   - **Pribadi (Personal)**: Lebih cepat daftar, namun wajib melewati tahap *Closed Testing (20 Penguji selama 14 hari)* sebelum bisa rilis ke publik.
4. Bayar biaya pendaftaran satu kali ($25 USD) via Kartu Kredit / Debit Online / Jenius.
5. Lengkapi verifikasi identitas (KTP/SIM/Paspor).

---

## 2. BUILD ANDROID APP BUNDLE (.AAB)
Google Play mewajibkan format **Android App Bundle (.aab)** bertanda tangan rilis (Release Signing), bukan APK biasa.

### Cara Cepat (1-Klik):
Jalankan script otomatis yang ada di folder:
```
google_play_release\08_BUILD_SCRIPTS\build_app_bundle.bat
```
*(Atau buka PowerShell dan jalankan `.\google_play_release\08_BUILD_SCRIPTS\build_app_bundle.ps1`)*

Setelah selesai, file `.aab` Anda otomatis siap di:
📁 `google_play_release\output_aab\OSIS_Management_Release_v1.0.0.aab`

---

## LANGKAH 1: MEMBUAT APLIKASI BARU DI CONSOLE
1. Buka [Google Play Console](https://play.google.com/console)
2. Klik tombol **"Create app"** (Buat aplikasi) di pojok kanan atas.
3. Isi informasi awal:
   - **App name**: `OSIS Management`
   - **Default language**: `Indonesian (id)` atau `English (United States) - en-US`
   - **App or game**: Pilih **App**
   - **Free or paid**: Pilih **Free**
4. Centang persetujuan:
   - *Developer Program Policies*
   - *US export laws*
5. Klik **"Create app"**.

---

## LANGKAH 2: MENYIAPKAN DETAIL LISTING TOKO (STORE LISTING)
Buka menu sebelah kiri: **Grow** -> **Store presence** -> **Main store listing**.

Isi metadata dari file `02_METADATA_STORE_LISTING.txt`:
1. **App name**: `OSIS Management - Jurnal Kerja`
2. **Short description**: `Aplikasi manajemen OSIS, pencatatan jurnal kerja, rapat, proposal & laporan.`
3. **Full description**: Salin teks lengkap dari `02_METADATA_STORE_LISTING.txt`.
4. **App icon**:
   - Upload file: `google_play_release\07_GRAPHICS_ASSETS\app_icon_512x512.png`
5. **Feature graphic**:
   - Upload file: `google_play_release\07_GRAPHICS_ASSETS\feature_graphic_1024x500.png`
6. **Phone screenshots**:
   - Upload minimal 2 (disarankan 4-6) screenshot aplikasi Anda. (Lihat panduan di `07_GRAPHICS_ASSETS\SCREENSHOTS_GUIDE.md`).
7. Klik **"Save"** (Simpan).

---

## LANGKAH 3: MENGISI KONTEN APLIKASI & KUISIONER KEBIJAKAN
Buka menu sebelah kiri: **Policy and programs** -> **App content**.

Selesaikan semua formulir berikut (Gunakan panduan di `04_APP_CONTENT_KUISIONER.md`):
- [x] **Privacy Policy (Kebijakan Privasi)**: Masukkan URL kebijakan privasi (lihat panduan host di folder `06_PRIVASI_DAN_SYARAT`).
- [x] **App access (Akses Aplikasi)**: Masukkan kredensial login akun demo jika aplikasi memerlukan login.
- [x] **Ads (Iklan)**: Pilih *"No, my app does not contain ads"*.
- [x] **Content Ratings (Rating Konten IARC)**: Isi kuisioner (semua "Tidak/No") -> Menghasilkan rating 3+ / Everyone.
- [x] **Target Audience and Content**: Pilih usia 13-15, 16-17, 18+.
- [x] **News apps**: Pilih *"No"*.
- [x] **COVID-19 contact tracing**: Pilih *"No"*.
- [x] **Financial features**: Pilih *"No"*.
- [x] **Advertising ID**: Pilih *"No"*.
- [x] **Government apps**: Pilih *"No"*.

---

## LANGKAH 4: MENGISI KUISIONER KEAMANAN DATA (DATA SAFETY)
Pada menu **App content** -> **Data safety**, isi sesuai panduan lengkap di:
📄 `03_DATA_SAFETY_KUISIONER.md`

Ringkasan:
- Data dienkripsi saat transit (HTTPS/SSL): **Ya**
- Pengguna dapat meminta penghapusan akun/data: **Ya**
- Data yang dikumpulkan: Info Pengguna (Nama/Akun), File/Dokumen (Laporan/Proposal), Foto (Dokumentasi kegiatan - opsional).
- Semua data digunakan murni untuk **Fungsionalitas Aplikasi (App functionality)**.

---

## LANGKAH 5: MENGUPLOAD FILE .AAB & MEMBUAT RILIS
1. Buka menu:
   - Jika akun Organisasi: **Release** -> **Production** -> **Create new release**.
   - Jika akun Pribadi: **Release** -> **Testing** -> **Closed testing** -> **Create track** / **Create new release**.
2. Klik tombol **"Upload"** pada bagian App bundles.
3. Pilih file `.aab` dari:
   📁 `google_play_release\output_aab\OSIS_Management_Release_v1.0.0.aab`
4. Masukkan **Release name**: `1.0.0 (1)`
5. Masukkan **Release notes (Catatan Rilis)**:
   ```
   id-ID
   Rilis perdana aplikasi OSIS Management:
   - Pencatatan jurnal kerja pengurus OSIS
   - Manajemen agenda & absensi rapat
   - Ekspor laporan otomatis ke PDF & Excel
   - Notifikasi pengingat kegiatan
   ```
6. Klik **"Next"** lalu periksa apakah ada error/peringatan.
7. Klik **"Save"** (Simpan).

---

## LANGKAH 6: ATURAN KHUSUS AKUN PERSONAL (20 PENGUJI / CLOSED TESTING)
> **Penting:** Jika Anda menggunakan akun Google Play Developer **Personal (Pribadi)** yang dibuat setelah November 2023:

1. Anda **wajib** melakukan **Closed Testing** dengan minimal **20 Penguji**.
2. Penguji harus opt-in dan menginstal aplikasi selama **14 hari berturut-turut**.
3. Cara mengundang penguji:
   - Buka **Closed testing** -> Tab **Testers**.
   - Buat Email List (masukkan 20+ alamat email Gmail pengurus/teman/guru).
   - Salin link "Join on Android" atau "Join on Web" dan bagikan ke 20 penguji tersebut.
   - Pastikan mereka mendownload dan membuka aplikasi secara berkala.
4. Setelah 14 hari penuh, tombol **"Apply for production"** akan aktif di dashboard Anda.

---

## LANGKAH 7: PENGAJUAN REVIEW & PUBLIKASI
1. Buka **Publishing overview**.
2. Periksa semua perubahan dan pastikan tidak ada task yang tertinggal di menu **Dashboard**.
3. Klik tombol **"Send 14 changes for review"** (Kirim untuk ditinjau).
4. Google biasanya memerlukan waktu **1 hingga 5 hari kerja** untuk meninjau aplikasi.
5. Setelah disetujui, aplikasi akan otomatis berstatus **Published** dan tersedia di Google Play Store! 🎉
