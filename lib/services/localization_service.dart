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

  static const List<AppLanguage> allSupportedLanguages = [
    AppLanguage(code: 'id', name: 'Bahasa Indonesia', flag: '🇮🇩'),
    AppLanguage(code: 'en', name: 'English (US)', flag: '🇬🇧'),
  ];

  static const Map<String, Map<String, String>> _localizedValues = {
    'id': {
      // General & Navigation
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

      // Buttons
      'btn_login': 'Masuk',
      'btn_logout': 'Logout',
      'btn_save': 'Simpan',
      'btn_save_changes': 'Simpan Perubahan',
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
      'btn_back': 'Kembali',
      'btn_filter': 'Filter',
      'btn_all': 'Semua',
      'btn_select_all': 'Pilih Semua',
      'btn_clear': 'Bersihkan',
      'btn_yes': 'Ya',
      'btn_no': 'Tidak',
      'btn_choose_file': 'Pilih File...',
      'btn_open_file': 'Buka File',
      'btn_move': 'Pindahkan',
      'btn_rename': 'Ganti Nama',
      'btn_create_folder': 'Buat Folder',

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
      'old_password': 'Password Lama',
      'new_password': 'Password Baru',
      'confirm_password': 'Konfirmasi Password',
      'admin_config': 'Konfigurasi Sistem (Admin)',
      'about_app': 'Tentang Aplikasi',
      'notifications': 'Pusat Notifikasi',
      'cloud_status': 'Status Koneksi Cloud',
      'username': 'Username',
      'password': 'Password',
      'confirm_logout': 'Konfirmasi Logout',
      'logout_prompt': 'Apakah Anda yakin ingin keluar dari aplikasi?',
      'press_back_again_to_exit': 'Tekan sekali lagi untuk keluar dari aplikasi',
      'login_instruction': 'Masukkan username dan password akun Anda',
      'change_theme': 'Ganti Mode Tema',
      'err_username_empty': 'Username tidak boleh kosong.',
      'err_password_empty': 'Password tidak boleh kosong.',
      'err_invalid_credentials': 'Username atau password salah.',
      'students': 'siswa',
      'records': 'catatan',
      'violations': 'pelanggaran',

      // Roles
      'role_admin': 'Super Admin',
      'role_pembina': 'Pembina OSIS',
      'role_kesiswaan': 'Staf Kesiswaan',
      'role_ketua': 'Ketua OSIS',
      'role_wakil': 'Wakil Ketua OSIS',
      'role_sekretaris': 'Sekretaris OSIS',
      'role_bendahara': 'Bendahara OSIS',

      // Status
      'status_draft': 'Belum Mulai',
      'status_pending': 'Pengajuan',
      'status_approved': 'Disetujui',
      'status_running': 'Berjalan',
      'status_done': 'Selesai',
      'status_eval': 'Evaluasi',
      'status_rejected': 'Ditolak',
      'status_all': 'Semua Status',

      // Module Titles & Headings
      'proker_heading': 'Program Kerja OSIS',
      'proker_add': 'Tambah Program Kerja',
      'proker_edit': 'Edit Program Kerja',
      'proker_delete_confirm': 'Hapus Proker?',
      'proker_delete_msg': 'Apakah Anda yakin ingin menghapus program kerja ini?',
      'proker_name': 'Nama Program Kerja',
      'proker_desc': 'Deskripsi',
      'proker_sekbid': 'Sekbid',
      'proker_pj': 'Penanggung Jawab',
      'proker_plan_date': 'Tanggal Rencana',
      'proker_real_date': 'Tanggal Realisasi',
      'proker_notes': 'Keterangan',
      'proker_empty': 'Belum ada program kerja',

      'laporan_heading': 'Laporan Kegiatan OSIS',
      'laporan_add': 'Buat Laporan Kegiatan',
      'laporan_edit': 'Edit Laporan',
      'laporan_delete_confirm': 'Hapus Laporan Kegiatan?',
      'laporan_name': 'Nama Kegiatan',
      'laporan_date': 'Tanggal Kegiatan',
      'laporan_location': 'Lokasi Kegiatan',
      'laporan_leader': 'Ketua Pelaksana (Ketuplak)',
      'laporan_result': 'Hasil & Capaian Kegiatan',
      'laporan_eval': 'Kendala & Saran Evaluasi',
      'laporan_participants': 'Peserta (pisahkan dengan koma)',
      'laporan_empty': 'Belum ada laporan kegiatan',

      'arsip_heading': 'Arsip & Berkas Digital',
      'arsip_folder_create': 'Buat Folder Baru',
      'arsip_folder_rename': 'Ganti Nama Folder',
      'arsip_folder_name': 'Nama Folder',
      'arsip_folder_loc': 'Lokasi Folder:',
      'arsip_file_add': 'Tambah File Baru',
      'arsip_file_edit': 'Edit Informasi File',
      'arsip_file_name': 'Nama File / Judul Dokumen',
      'arsip_file_number': 'Nomor Dokumen / Surat',
      'arsip_file_date': 'Tanggal Dokumen',
      'arsip_file_desc': 'Deskripsi Singkat',
      'arsip_file_upload': 'Upload File dari HP / Komputer',
      'arsip_file_uploader': 'Diupload Oleh',
      'arsip_delete_confirm': 'Hapus Dokumen?',
      'arsip_empty': 'Folder ini masih kosong',
      'arsip_root': 'Root (/)',

      'pelanggaran_heading': 'Catatan Pelanggaran Siswa',
      'pelanggaran_add': 'Catat Pelanggaran',
      'pelanggaran_search_student': 'Cari Siswa (nama / NIS / kelas)',
      'pelanggaran_date': 'Tanggal Pelanggaran',
      'pelanggaran_type': 'Jenis Pelanggaran',
      'pelanggaran_type_today': 'Jenis Pelanggaran Hari Ini',
      'pelanggaran_notes': 'Keterangan (opsional)',
      'pelanggaran_total_points': 'Total Poin',
      'pelanggaran_delete_confirm': 'Hapus Catatan Pelanggaran?',
      'pelanggaran_empty': 'Belum ada data pelanggaran pada tanggal ini',
      'pelanggaran_sp1': 'Peringatan SP 1',
      'pelanggaran_sp2': 'Peringatan SP 2',
      'pelanggaran_sp3': 'Peringatan SP 3',
      'pelanggaran_skorsing': 'Status Skorsing',

      'rekap_heading': 'Rekapitulasi & Statistik',
      'rekap_monthly': 'Rekap Pelanggaran Bulanan',
      'rekap_top_violations': 'Siswa Sering Melanggar',
      'rekap_proker_stat': 'Statistik Program Kerja',
      'rekap_laporan_stat': 'Statistik Laporan',
      'rekap_export_excel': 'Ekspor Excel / CSV',
      'rekap_print_sp': 'Cetak Surat Peringatan (SP)',
      'rekap_filter_month': 'Pilih Bulan',
      'rekap_filter_year': 'Pilih Tahun',

      'manajemen_heading': 'Manajemen Data Master',
      'manajemen_students': 'Data Siswa',
      'manajemen_violations': 'Jenis Pelanggaran',
      'manajemen_import': 'Impor Siswa (Excel/CSV)',
      'manajemen_add_student': 'Tambah Data Siswa',
      'manajemen_edit_student': 'Edit Siswa',
      'manajemen_student_name': 'Nama Lengkap',
      'manajemen_class': 'Kelas',
      'manajemen_nis': 'Nomor Induk Siswa (NIS)',
      'manajemen_active_days': 'Hari Aktif Berlaku',

      'admin_heading': 'Konfigurasi Sistem (Admin)',
      'tab_branding': 'Tema & Tampilan',
      'tab_accounts': 'Kelola Akun',
      'tab_module_configs': 'Konfigurasi Fitur',
      'tab_signatures': 'Format Dokumen & PDF',

      // Messages & Notifications
      'msg_saved': 'Perubahan berhasil disimpan',
      'msg_deleted': 'Data berhasil dihapus',
      'msg_error': 'Terjadi kesalahan',
      'msg_sync_success': 'Sinkronisasi cloud berhasil',
      'notifications_empty': 'Belum ada notifikasi',
      'notifications_mark_all': 'Tandai Semua Dibaca',
      'notifications_clear_all': 'Hapus Semua Notifikasi',

      // Days & Months
      'day_monday': 'Senin',
      'day_tuesday': 'Selasa',
      'day_wednesday': 'Rabu',
      'day_thursday': 'Kamis',
      'day_friday': 'Jumat',
      'day_saturday': 'Sabtu',
      'day_sunday': 'Minggu',
    },
    'en': {
      // General & Navigation
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

      // Buttons
      'btn_login': 'Sign In',
      'btn_logout': 'Sign Out',
      'btn_save': 'Save',
      'btn_save_changes': 'Save Changes',
      'btn_cancel': 'Cancel',
      'btn_delete': 'Delete',
      'btn_edit': 'Edit',
      'btn_add': 'Add New',
      'btn_search': 'Search...',
      'btn_refresh': 'Refresh',
      'btn_close': 'Close',
      'btn_reset': 'Reset',
      'btn_apply': 'Apply',
      'btn_export': 'Export',
      'btn_upload': 'Upload File',
      'btn_download': 'Download',
      'btn_copy': 'Copy',
      'btn_cut': 'Cut',
      'btn_paste': 'Paste',
      'btn_print': 'Print PDF',
      'btn_back': 'Back',
      'btn_filter': 'Filter',
      'btn_all': 'All',
      'btn_select_all': 'Select All',
      'btn_clear': 'Clear',
      'btn_yes': 'Yes',
      'btn_no': 'No',
      'btn_choose_file': 'Choose File...',
      'btn_open_file': 'Open Document',
      'btn_move': 'Move',
      'btn_rename': 'Rename',
      'btn_create_folder': 'Create Folder',

      // Settings
      'settings_title': 'Settings & Preferences',
      'theme_mode': 'Display Mode',
      'theme_light': 'White (Light) Mode',
      'theme_dark': 'Dark Mode',
      'theme_system': 'Follow System',
      'theme_color': 'Theme Accent Color',
      'language': 'App Language',
      'language_id': 'Indonesian (Bahasa Indonesia)',
      'language_en': 'English (US)',
      'change_password': 'Change Password',
      'old_password': 'Current Password',
      'new_password': 'New Password',
      'confirm_password': 'Confirm New Password',
      'admin_config': 'System Configuration (Admin)',
      'about_app': 'About Application',
      'notifications': 'Notification Center',
      'cloud_status': 'Cloud Connection Status',
      'username': 'Username',
      'password': 'Password',
      'confirm_logout': 'Confirm Sign Out',
      'logout_prompt': 'Are you sure you want to sign out from the application?',
      'press_back_again_to_exit': 'Press back button once more to exit',
      'login_instruction': 'Enter your username and account password',
      'change_theme': 'Toggle Theme Mode',
      'err_username_empty': 'Username cannot be empty.',
      'err_password_empty': 'Password cannot be empty.',
      'err_invalid_credentials': 'Invalid username or password.',
      'students': 'students',
      'records': 'records',
      'violations': 'violations',

      // Roles
      'role_admin': 'Super Admin',
      'role_pembina': 'Faculty Advisor (Pembina)',
      'role_kesiswaan': 'Student Affairs Staff',
      'role_ketua': 'Council President (Ketua)',
      'role_wakil': 'Council Vice President (Wakil)',
      'role_sekretaris': 'General Secretary',
      'role_bendahara': 'Treasurer (Bendahara)',

      // Status
      'status_draft': 'Not Started',
      'status_pending': 'Pending Review',
      'status_approved': 'Approved',
      'status_running': 'In Progress',
      'status_done': 'Completed',
      'status_eval': 'Evaluation',
      'status_rejected': 'Rejected',
      'status_all': 'All Statuses',

      // Module Titles & Headings
      'proker_heading': 'Annual Work Programs',
      'proker_add': 'Add Work Program',
      'proker_edit': 'Edit Work Program',
      'proker_delete_confirm': 'Delete Work Program?',
      'proker_delete_msg': 'Are you sure you want to permanently delete this program?',
      'proker_name': 'Work Program Name',
      'proker_desc': 'Description',
      'proker_sekbid': 'Division (Sekbid)',
      'proker_pj': 'Person In Charge (PJ)',
      'proker_plan_date': 'Planned Date',
      'proker_real_date': 'Realized Date',
      'proker_notes': 'Notes / Remarks',
      'proker_empty': 'No work programs found',

      'laporan_heading': 'Activity Reports & LPJ',
      'laporan_add': 'Create Activity Report',
      'laporan_edit': 'Edit Report',
      'laporan_delete_confirm': 'Delete Activity Report?',
      'laporan_name': 'Event / Activity Name',
      'laporan_date': 'Event Date',
      'laporan_location': 'Event Location',
      'laporan_leader': 'Organizing Leader (Ketuplak)',
      'laporan_result': 'Results & Achievements',
      'laporan_eval': 'Challenges & Recommendations',
      'laporan_participants': 'Participants (comma-separated)',
      'laporan_empty': 'No activity reports found',

      'arsip_heading': 'Digital Document Archives',
      'arsip_folder_create': 'Create New Folder',
      'arsip_folder_rename': 'Rename Folder',
      'arsip_folder_name': 'Folder Name',
      'arsip_folder_loc': 'Folder Location:',
      'arsip_file_add': 'Upload New Document',
      'arsip_file_edit': 'Edit Document Details',
      'arsip_file_name': 'Document Title / File Name',
      'arsip_file_number': 'Document / Reference Number',
      'arsip_file_date': 'Document Date',
      'arsip_file_desc': 'Brief Description',
      'arsip_file_upload': 'Upload Document from Device',
      'arsip_file_uploader': 'Uploaded By',
      'arsip_delete_confirm': 'Delete Document?',
      'arsip_empty': 'This folder is empty',
      'arsip_root': 'Root (/)',

      'pelanggaran_heading': 'Student Discipline Records',
      'pelanggaran_add': 'Record Violation',
      'pelanggaran_search_student': 'Search Student (Name / NIS / Class)',
      'pelanggaran_date': 'Violation Date',
      'pelanggaran_type': 'Violation Category',
      'pelanggaran_type_today': 'Violation Types for Today',
      'pelanggaran_notes': 'Remarks (optional)',
      'pelanggaran_total_points': 'Total Points',
      'pelanggaran_delete_confirm': 'Delete Violation Record?',
      'pelanggaran_empty': 'No violation records on this date',
      'pelanggaran_sp1': 'Warning Letter 1 (SP 1)',
      'pelanggaran_sp2': 'Warning Letter 2 (SP 2)',
      'pelanggaran_sp3': 'Warning Letter 3 (SP 3)',
      'pelanggaran_skorsing': 'Suspension Status',

      'rekap_heading': 'Recapitulation & Statistics',
      'rekap_monthly': 'Monthly Discipline Recap',
      'rekap_top_violations': 'Frequent Violators',
      'rekap_proker_stat': 'Work Program Statistics',
      'rekap_laporan_stat': 'Activity Report Statistics',
      'rekap_export_excel': 'Export to Excel / CSV',
      'rekap_print_sp': 'Print Warning Letter (SP)',
      'rekap_filter_month': 'Select Month',
      'rekap_filter_year': 'Select Year',

      'manajemen_heading': 'Master Data Management',
      'manajemen_students': 'Student Data',
      'manajemen_violations': 'Violation Types',
      'manajemen_import': 'Import Students (Excel/CSV)',
      'manajemen_add_student': 'Add Student Record',
      'manajemen_edit_student': 'Edit Student',
      'manajemen_student_name': 'Full Name',
      'manajemen_class': 'Class / Grade',
      'manajemen_nis': 'Student ID Number (NIS)',
      'manajemen_active_days': 'Active Days',

      'admin_heading': 'System Configuration (Admin)',
      'tab_branding': 'Theme & Branding',
      'tab_accounts': 'Account Management',
      'tab_module_configs': 'Module Configuration',
      'tab_signatures': 'Document & Signatures Format',

      // Messages & Notifications
      'msg_saved': 'Changes saved successfully',
      'msg_deleted': 'Record deleted successfully',
      'msg_error': 'An unexpected error occurred',
      'msg_sync_success': 'Cloud synchronization successful',
      'notifications_empty': 'No notifications available',
      'notifications_mark_all': 'Mark All as Read',
      'notifications_clear_all': 'Clear All Notifications',

      // Days & Months
      'day_monday': 'Monday',
      'day_tuesday': 'Tuesday',
      'day_wednesday': 'Wednesday',
      'day_thursday': 'Thursday',
      'day_friday': 'Friday',
      'day_saturday': 'Saturday',
      'day_sunday': 'Sunday',
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

  static String formatDay(int weekday) {
    switch (weekday) {
      case 1: return tr('day_monday');
      case 2: return tr('day_tuesday');
      case 3: return tr('day_wednesday');
      case 4: return tr('day_thursday');
      case 5: return tr('day_friday');
      case 6: return tr('day_saturday');
      case 7: return tr('day_sunday');
      default: return '';
    }
  }

  static String formatStatus(String status) {
    final s = status.toLowerCase();
    if (s.contains('belum') || s.contains('draft')) return tr('status_draft');
    if (s.contains('jalan') || s.contains('progress') || s.contains('berjalan')) return tr('status_running');
    if (s.contains('selesai') || s.contains('done') || s.contains('complete')) return tr('status_done');
    if (s.contains('tunda') || s.contains('pending')) return tr('status_pending');
    if (s.contains('setuju') || s.contains('approved')) return tr('status_approved');
    if (s.contains('tolak') || s.contains('rejected')) return tr('status_rejected');
    return status;
  }
}

extension AppLocalizationExtension on BuildContext {
  String tr(String key) => LocalizationService.tr(key);
}

