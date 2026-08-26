import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLanguage {
  final String code;
  final String name;
  final String flag;
  const AppLanguage({required this.code, required this.name, required this.flag});
}

class LocalizationService {
  static const _keyLanguage = 'selected_language';
  static final ValueNotifier<Locale> currentLocale = ValueNotifier(const Locale('id'));

  // Only Indonesian and English as requested
  static const List<AppLanguage> allSupportedLanguages = [
    AppLanguage(code: 'id', name: 'Bahasa Indonesia', flag: '🇮🇩'),
    AppLanguage(code: 'en', name: 'English (US)', flag: '🇬🇧'),
  ];

  static const Map<String, Map<String, String>> _localizedValues = {
    'id': {
      'app_title': 'OSIS Management',
      'app_subtitle': 'Sistem Manajemen OSIS Digital',
      'login_as': 'Login sebagai:',
      'nav_proker': 'Proker',
      'nav_laporan': 'Laporan',
      'nav_arsip': 'Arsip',
      'nav_pelanggaran': 'Pelanggaran',
      'nav_rekap': 'Rekap',
      'nav_manajemen': 'Manajemen',
      'nav_admin': 'Admin Panel',
      'nav_settings': 'Pengaturan',
      'btn_login': 'Masuk',
      'btn_logout': 'Logout',
      'btn_save': 'Simpan',
      'btn_cancel': 'Batal',
      'btn_delete': 'Hapus',
      'btn_edit': 'Edit',
      'btn_add': 'Tambah',
      'btn_search': 'Cari...',
      'btn_refresh': 'Segarkan',
      'btn_close': 'Tutup',
      'btn_reset': 'Reset',
      'btn_apply': 'Terapkan',
      'btn_export': 'Ekspor',
      'btn_upload': 'Unggah Berkas',
      'btn_download': 'Unduh',
      'btn_copy': 'Salin',
      'btn_cut': 'Potong',
      'btn_paste': 'Tempel',
      'btn_print': 'Cetak PDF',
      'settings_title': 'Pengaturan & Preferensi',
      'theme_mode': 'Mode Tampilan',
      'theme_light': 'White (Light) Mode',
      'theme_dark': 'Dark Mode',
      'theme_system': 'Ikuti Sistem',
      'theme_color': 'Warna Aksen Tema',
      'language': 'Bahasa Aplikasi',
      'language_id': 'Bahasa Indonesia',
      'language_en': 'English',
      'change_password': 'Ganti Password Akun',
      'admin_config': 'Konfigurasi Sistem (Admin)',
      'about_app': 'Tentang Aplikasi',
      'notifications': 'Pusat Notifikasi',
      'cloud_status': 'Status Koneksi Cloud',
      'username': 'Username',
      'password': 'Password',
      'new_password': 'Password Baru',
      'confirm_logout': 'Konfirmasi Logout',
      'logout_prompt': 'Apakah Anda yakin ingin keluar?',
      'press_back_again_to_exit': 'Tekan sekali lagi untuk keluar dari aplikasi',
      'role_admin': 'Super Admin Sistem',
      'role_pembina': 'Pembina OSIS',
      'role_kesiswaan': 'Staf Kesiswaan',
      'role_ketua': 'Ketua OSIS',
      'role_wakil': 'Wakil Ketua OSIS',
      'role_sekretaris': 'Sekretaris OSIS',
      'role_bendahara': 'Bendahara OSIS',
      'msg_saved': 'Perubahan berhasil disimpan',
      'msg_deleted': 'Data berhasil dihapus',
      'msg_error': 'Terjadi kesalahan',
      'msg_sync_success': 'Sinkronisasi berhasil',
      'live_preview': 'Pratinjau Langsung (Live Preview)',
      'palette_custom_hex': 'Kode Warna HEX (#RRGGBB)',
      'palette_presets': 'Pilihan Palet Warna Elegan',
      'palette_wheel_title': 'Roda Warna Interaktif (Color Wheel)',
      'proker_heading': 'Program Kerja OSIS',
      'laporan_heading': 'Laporan Kegiatan OSIS',
      'arsip_heading': 'Arsip & Berkas Digital',
      'pelanggaran_heading': 'Catatan Pelanggaran Siswa',
      'rekap_heading': 'Rekapitulasi & Statistik',
      'status_draft': 'Perencanaan',
      'status_pending': 'Pengajuan',
      'status_approved': 'Disetujui',
      'status_running': 'Berjalan',
      'status_done': 'Selesai',
      'status_eval': 'Evaluasi',
      'status_rejected': 'Ditolak',
      'tab_branding': 'Tema & Tampilan',
      'tab_accounts': 'Kelola Akun',
      'tab_module_configs': 'Konfigurasi Fitur & Modul',
      'tab_signatures': 'Format Dokumen & PDF',
      'admin_section_arsip': 'Pengaturan Arsip Dokumen',
      'admin_section_pelanggaran': 'Pengaturan Poin Pelanggaran',
      'admin_section_rekap': 'Pengaturan Rekapitulasi & Surat',
      'admin_section_proker': 'Pengaturan Proker & Sekbid',
      'admin_section_laporan': 'Pengaturan Laporan & LPJ',
    },
    'en': {
      'app_title': 'OSIS Management',
      'app_subtitle': 'Digital Student Council System',
      'login_as': 'Logged in as:',
      'nav_proker': 'Work Plan',
      'nav_laporan': 'Reports',
      'nav_arsip': 'Archive',
      'nav_pelanggaran': 'Discipline',
      'nav_rekap': 'Recap',
      'nav_manajemen': 'Management',
      'nav_admin': 'Admin Panel',
      'nav_settings': 'Settings',
      'btn_login': 'Sign In',
      'btn_logout': 'Sign Out',
      'btn_save': 'Save Changes',
      'btn_cancel': 'Cancel',
      'btn_delete': 'Delete',
      'btn_edit': 'Edit',
      'btn_add': 'Add New',
      'btn_search': 'Search...',
      'btn_refresh': 'Refresh Data',
      'btn_close': 'Close',
      'btn_reset': 'Reset Default',
      'btn_apply': 'Apply Theme',
      'btn_export': 'Export Data',
      'btn_upload': 'Upload Document',
      'btn_download': 'Download',
      'btn_copy': 'Copy',
      'btn_cut': 'Cut',
      'btn_paste': 'Paste',
      'btn_print': 'Print PDF',
      'settings_title': 'Settings & Preferences',
      'theme_mode': 'Display Mode',
      'theme_light': 'White (Light) Mode',
      'theme_dark': 'Dark Mode',
      'theme_system': 'Follow System',
      'theme_color': 'Theme Accent Color',
      'language': 'App Language',
      'language_id': 'Indonesian (Bahasa Indonesia)',
      'language_en': 'English (English US)',
      'change_password': 'Change Account Password',
      'admin_config': 'System Configuration (Admin)',
      'about_app': 'About OSIS Management',
      'notifications': 'Notification Center',
      'cloud_status': 'Cloud Sync Status',
      'username': 'Username',
      'password': 'Password',
      'new_password': 'New Password',
      'confirm_logout': 'Confirm Sign Out',
      'logout_prompt': 'Are you sure you want to sign out from the application?',
      'press_back_again_to_exit': 'Press back button once more to exit',
      'role_admin': 'Super System Admin',
      'role_pembina': 'Faculty Advisor (Pembina)',
      'role_kesiswaan': 'Student Affairs Staff',
      'role_ketua': 'Council President (Ketua)',
      'role_wakil': 'Council Vice President (Wakil)',
      'role_sekretaris': 'General Secretary',
      'role_bendahara': 'Treasurer (Bendahara)',
      'msg_saved': 'All changes have been successfully saved',
      'msg_deleted': 'Data successfully removed',
      'msg_error': 'An unexpected error occurred',
      'msg_sync_success': 'Cloud synchronization successful',
      'live_preview': 'Interactive Live Preview',
      'palette_custom_hex': 'Custom Hex Color Code (#RRGGBB)',
      'palette_presets': 'Curated Theme Color Presets',
      'palette_wheel_title': 'Interactive Color Wheel',
      'proker_heading': 'Annual Work Programs',
      'laporan_heading': 'Activity Reports & LPJ',
      'arsip_heading': 'Digital Document Archives',
      'pelanggaran_heading': 'Student Discipline Records',
      'rekap_heading': 'Recapitulation & Statistics',
      'status_draft': 'Planning',
      'status_pending': 'Pending Review',
      'status_approved': 'Approved',
      'status_running': 'In Progress',
      'status_done': 'Completed',
      'status_eval': 'Evaluation',
      'status_rejected': 'Rejected',
      'tab_branding': 'Theme & Visual Design',
      'tab_accounts': 'User & Account Management',
      'tab_module_configs': 'Feature & Module Configuration',
      'tab_signatures': 'Document & PDF Format',
      'admin_section_arsip': 'Archive & File Management Settings',
      'admin_section_pelanggaran': 'Discipline Point Warning Thresholds',
      'admin_section_rekap': 'Recapitulation & Official Signatures',
      'admin_section_proker': 'Work Program & Division Settings',
      'admin_section_laporan': 'Activity Report & LPJ Settings',
    },
  };

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final langCode = prefs.getString(_keyLanguage) ?? 'id';
    currentLocale.value = Locale(_localizedValues.containsKey(langCode) ? langCode : 'id');
  }

  static Future<void> setLanguage(String langCode) async {
    final code = _localizedValues.containsKey(langCode) ? langCode : 'id';
    currentLocale.value = Locale(code);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLanguage, code);
  }

  static String tr(String key) {
    final code = currentLocale.value.languageCode;
    return _localizedValues[code]?[key] ?? _localizedValues['id']?[key] ?? key;
  }
}

extension AppLocalizationExtension on BuildContext {
  String tr(String key) => LocalizationService.tr(key);
}
