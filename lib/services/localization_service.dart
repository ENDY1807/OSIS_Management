import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalizationService {
  static const _keyLanguage = 'selected_language';
  static final ValueNotifier<Locale> currentLocale = ValueNotifier(const Locale('id'));

  static const Map<String, Map<String, String>> _localizedValues = {
    'id': {
      // App & Navigation
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

      // Actions
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

      // Settings
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

      // Auth & Roles
      'username': 'Username',
      'password': 'Password',
      'new_password': 'Password Baru',
      'confirm_logout': 'Konfirmasi Logout',
      'logout_prompt': 'Apakah Anda yakin ingin keluar?',
      'role_admin': 'Super Admin Sistem',
      'role_pembina': 'Pembina OSIS',
      'role_kesiswaan': 'Staf Kesiswaan',
      'role_ketua': 'Ketua OSIS',
      'role_wakil': 'Wakil Ketua OSIS',
      'role_sekretaris': 'Sekretaris OSIS',
      'role_bendahara': 'Bendahara OSIS',

      // Messages
      'msg_saved': 'Perubahan berhasil disimpan',
      'msg_deleted': 'Data berhasil dihapus',
      'msg_error': 'Terjadi kesalahan',
      'msg_sync_success': 'Sinkronisasi berhasil',
    },
    'en': {
      // App & Navigation
      'app_title': 'OSIS Management',
      'app_subtitle': 'Digital OSIS Management System',
      'login_as': 'Logged in as:',
      'nav_proker': 'Work Plan',
      'nav_laporan': 'Reports',
      'nav_arsip': 'Archive',
      'nav_pelanggaran': 'Discipline',
      'nav_rekap': 'Recap',
      'nav_manajemen': 'Management',
      'nav_admin': 'Admin Panel',
      'nav_settings': 'Settings',

      // Actions
      'btn_login': 'Sign In',
      'btn_logout': 'Sign Out',
      'btn_save': 'Save',
      'btn_cancel': 'Cancel',
      'btn_delete': 'Delete',
      'btn_edit': 'Edit',
      'btn_add': 'Add',
      'btn_search': 'Search...',
      'btn_refresh': 'Refresh',
      'btn_close': 'Close',
      'btn_reset': 'Reset',
      'btn_apply': 'Apply',

      // Settings
      'settings_title': 'Settings & Preferences',
      'theme_mode': 'Display Mode',
      'theme_light': 'White (Light) Mode',
      'theme_dark': 'Dark Mode',
      'theme_system': 'System Default',
      'theme_color': 'Theme Accent Color',
      'language': 'App Language',
      'language_id': 'Indonesian (Bahasa Indonesia)',
      'language_en': 'English',
      'change_password': 'Change Account Password',
      'admin_config': 'System Configuration (Admin)',
      'about_app': 'About App',
      'notifications': 'Notification Center',
      'cloud_status': 'Cloud Connection Status',

      // Auth & Roles
      'username': 'Username',
      'password': 'Password',
      'new_password': 'New Password',
      'confirm_logout': 'Confirm Sign Out',
      'logout_prompt': 'Are you sure you want to sign out?',
      'role_admin': 'Super System Admin',
      'role_pembina': 'OSIS Supervisor (Pembina)',
      'role_kesiswaan': 'Student Affairs Staff (Kesiswaan)',
      'role_ketua': 'OSIS President (Ketua)',
      'role_wakil': 'OSIS Vice President (Wakil)',
      'role_sekretaris': 'OSIS Secretary (Sekretaris)',
      'role_bendahara': 'OSIS Treasurer (Bendahara)',

      // Messages
      'msg_saved': 'Changes saved successfully',
      'msg_deleted': 'Data deleted successfully',
      'msg_error': 'An error occurred',
      'msg_sync_success': 'Synchronization successful',
    },
  };

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final langCode = prefs.getString(_keyLanguage) ?? 'id';
    currentLocale.value = Locale(langCode);
  }

  static Future<void> setLanguage(String langCode) async {
    final code = (langCode == 'en') ? 'en' : 'id';
    currentLocale.value = Locale(code);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLanguage, code);
  }

  static String tr(String key) {
    final code = currentLocale.value.languageCode;
    final dict = _localizedValues[code] ?? _localizedValues['id']!;
    return dict[key] ?? _localizedValues['id']?[key] ?? key;
  }
}

extension AppLocalizationExtension on BuildContext {
  String tr(String key) => LocalizationService.tr(key);
}
