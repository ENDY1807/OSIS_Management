# 🛡️ PANDUAN KUISIONER KEAMANAN DATA (DATA SAFETY)
**Google Play Console** mewajibkan setiap aplikasi mendeklarasikan data apa saja yang dikumpulkan, dibagikan, dan bagaimana data tersebut diamankan.

Ikuti panduan jawaban berikut saat mengisi bagian **App content** -> **Data safety** di Google Play Console:

---

## 1. PENGANTAR (DATA COLLECTION & SECURITY OVERVIEW)

| Pertanyaan di Google Play | Jawaban | Catatan / Alasan |
| :--- | :--- | :--- |
| **Apakah aplikasi Anda mengumpulkan atau membagikan jenis data pengguna yang diperlukan?** | **Ya (Yes)** | Aplikasi mengumpulkan nama/email login dan catatan jurnal kerja. |
| **Apakah semua data pengguna yang dikumpulkan oleh aplikasi Anda dienkripsi saat transit?** | **Ya (Yes)** | Semua komunikasi ke database Supabase Cloud menggunakan protokol HTTPS/TLS terenkripsi. |
| **Apakah Anda menyediakan cara bagi pengguna untuk meminta agar data mereka dihapus?** | **Ya (Yes)** | Pengguna dapat menghapus catatan atau menghubungi admin/pengembang untuk menghapus akun. |
| **Apakah ada tautan URL permintaan penghapusan data?** | **Ya (Yes)** | Masukkan URL Kebijakan Privasi Anda (misal: `https://your-domain.com/privacy-policy#delete-data`). |

---

## 2. DETAIL JENIS DATA YANG DIKUMPULKAN (DATA TYPES)

Centang jenis data berikut:

### A. Informasi Pribadi (Personal Info)
- [x] **Nama (Name)**
  - *Dikumpulkan (Collected)*: **Ya**
  - *Dibagikan (Shared)*: **Tidak**
  - *Tujuan*: Fungsionalitas Aplikasi (App functionality), Manajemen Akun (Account management).
  - *Diproses secara efemeral*: Tidak.
  - *Wajib atau Opsional*: Wajib (untuk identitas pengurus).

- [x] **Alamat Email (Email Address)**
  - *Dikumpulkan (Collected)*: **Ya**
  - *Dibagikan (Shared)*: **Tidak**
  - *Tujuan*: Fungsionalitas Aplikasi (App functionality), Autentikasi Pengguna (Account management).
  - *Diproses secara efemeral*: Tidak.
  - *Wajib atau Opsional*: Wajib jika menggunakan fitur login email.

- [x] **ID Pengguna (User IDs)**
  - *Dikumpulkan (Collected)*: **Ya** (User UUID dari Supabase Auth).
  - *Dibagikan (Shared)*: **Tidak**
  - *Tujuan*: Fungsionalitas Aplikasi & Manajemen Akun.

---

### B. Foto dan Video (Photos and Videos)
- [x] **Foto (Photos)** *(Opsional / Jika ada fitur upload dokumentasi kegiatan)*
  - *Dikumpulkan (Collected)*: **Ya**
  - *Dibagikan (Shared)*: **Tidak**
  - *Tujuan*: Fungsionalitas Aplikasi (Lampiran dokumentasi program kerja/jurnal).
  - *Wajib atau Opsional*: Opsional (pengguna memilih sendiri foto kegiatan).

---

### C. File dan Dokumen (Files and Docs)
- [x] **File dan Dokumen (Files and Docs)**
  - *Dikumpulkan (Collected)*: **Ya**
  - *Dibagikan (Shared)*: **Tidak**
  - *Tujuan*: Fungsionalitas Aplikasi (Menyimpan dan mengekspor dokumen proposal/LPJ PDF/Excel).

---

### D. Aktivitas Aplikasi (App Activity)
- [x] **Interaksi Aplikasi (App Interactions)**
  - *Dikumpulkan (Collected)*: **Ya** (Catatan jurnal, notula rapat, status tugas).
  - *Dibagikan (Shared)*: **Tidak**
  - *Tujuan*: Fungsionalitas Aplikasi (Penyimpanan database kegiatan OSIS).

---

## 3. DATA YANG TIDAK DIKUMPULKAN (JANGAN CENTANG)
Pastikan Anda memilih **TIDAK / JANGAN CENTANG** untuk kategori berikut:
- ❌ Lokasi (Location)
- ❌ Info Finansial / Pembayaran (Financial info)
- ❌ Info Kesehatan & Kebugaran (Health & Fitness)
- ❌ Pesan SMS / Kontak Telepon (Contacts / SMS)
- ❌ ID Perangkat untuk Iklan (Advertising ID)
- ❌ Riwayat Penjelajahan Web (Web browsing)

---

## 4. PRAKTIK KEAMANAN (SECURITY PRACTICES)
- **Data dienkripsi saat transit**: Ya (Enkripsi SSL/TLS standar industri).
- **Penghapusan data**: Pengguna dapat meminta penghapusan data dengan mengirim email ke admin atau melalui menu pengaturan aplikasi.
- **Kepatuhan Kebijakan Keluarga (Families Policy)**: Aplikasi ditujukan untuk siswa/pengurus usia 13 tahun ke atas.
