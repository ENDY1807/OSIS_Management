# 📦 Google Play Console Release Package - OSIS Management

Folder ini berisi seluruh kelengkapan dokumen, aset grafis, metadata, kebijakan privasi, serta skrip otomatis untuk mempublikasikan aplikasi **OSIS Management** (`id.sch.baknus.osisjurnal`) ke **Google Play Store Console**.

---

## 🗂️ Struktur & Isi Folder:

| No | File / Folder | Deskripsi & Kegunaan |
| :--- | :--- | :--- |
| **01** | [`01_PANDUAN_UPLOAD_PLAY_STORE.md`](./01_PANDUAN_UPLOAD_PLAY_STORE.md) | **Panduan Master A-Z** langkah demi langkah dari pendaftaran akun hingga aplikasi disetujui Google. |
| **02** | [`02_METADATA_STORE_LISTING.txt`](./02_METADATA_STORE_LISTING.txt) | **Teks Siap Salin**: Nama Aplikasi, Deskripsi Singkat, Deskripsi Lengkap, Kategori, dan Tag. |
| **03** | [`03_DATA_SAFETY_KUISIONER.md`](./03_DATA_SAFETY_KUISIONER.md) | **Jawaban Formulir Keamanan Data** (Data Safety) agar lolos validasi Google. |
| **04** | [`04_APP_CONTENT_KUISIONER.md`](./04_APP_CONTENT_KUISIONER.md) | **Jawaban Kuisioner Konten**: Rating Umur IARC (3+), Iklan (No Ads), Akses Aplikasi, dll. |
| **05** | [`05_KEYSTORE_DAN_SIGNING.txt`](./05_KEYSTORE_DAN_SIGNING.txt) | Informasi Keystore rilis, key alias, passwords, serta SHA-1 & SHA-256 fingerprints. |
| **06** | [`06_PRIVASI_DAN_SYARAT/`](./06_PRIVASI_DAN_SYARAT/) | Berisi `privacy_policy.html` (siap host online) & panduan gratis pasang di GitHub Pages / Netlify. |
| **07** | [`07_GRAPHICS_ASSETS/`](./07_GRAPHICS_ASSETS/) | Icon Play Store (`512x512 PNG`), Banner Promosi (`1024x500 PNG`), & panduan screenshot HP. |
| **08** | [`08_BUILD_SCRIPTS/`](./08_BUILD_SCRIPTS/) | Script 1-klik (`build_app_bundle.bat` & `.ps1`) untuk build bundle `.aab` rilis otomatis. |
| **📁** | [`output_aab/`](./output_aab/) | Folder tujuan tempat file `.aab` hasil build siap diunggah ke Google Play Console. |

---

## ⚡ Langkah Cepat Memulai (Quick Start):
1. **Build AAB**: Double-click file `08_BUILD_SCRIPTS\build_app_bundle.bat`.
2. **Host Privasi**: Buka `06_PRIVASI_DAN_SYARAT\CARA_HOSTING_PRIVACY_POLICY.md` untuk mendapatkan URL Kebijakan Privasi gratis dalam 1 menit.
3. **Buka Console**: Ikuti instruksi bertahap di `01_PANDUAN_UPLOAD_PLAY_STORE.md` dan salin data dari `02_METADATA_STORE_LISTING.txt`.
