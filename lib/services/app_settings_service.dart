import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'localization_service.dart';
import 'data_service.dart';
import 'sync_service.dart';

enum InputFieldType {
  text,
  dropdown,
  select,
  date,
  file,
  number,
}

class AppCustomInputField {
  String id;
  String label;
  InputFieldType type;
  String placeholder;
  List<String> options;
  bool isRequired;

  AppCustomInputField({
    required this.id,
    required this.label,
    required this.type,
    this.placeholder = '',
    this.options = const [],
    this.isRequired = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'type': type.name,
    'placeholder': placeholder,
    'options': options,
    'isRequired': isRequired,
  };

  factory AppCustomInputField.fromJson(Map<String, dynamic> json) {
    return AppCustomInputField(
      id: json['id']?.toString() ?? const Uuid().v4(),
      label: json['label']?.toString() ?? 'Kolom Input',
      type: InputFieldType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => InputFieldType.text,
      ),
      placeholder: json['placeholder']?.toString() ?? '',
      options: (json['options'] as List?)?.map((e) => e.toString()).toList() ?? [],
      isRequired: json['isRequired'] == true,
    );
  }
}

class ThemePreset {
  final String name;
  final Color color;
  final Color darkColor;
  final String description;
  const ThemePreset({
    required this.name,
    required this.color,
    required this.darkColor,
    required this.description,
  });
}

class AppSettingsService {
  // SharedPreferences Keys
  static const _keyThemeMode = 'app_theme_mode';
  static const _keyAccentColor = 'app_accent_color';
  static const _keyAppName = 'app_custom_name';
  static const _keyAppSubtitle = 'app_custom_subtitle';
  static const _keyLogoUrl = 'app_logo_url';
  static const _keyEnabledLanguages = 'app_enabled_languages';

  // Admin Config Keys
  static const _keySp1Threshold = 'cfg_sp1_threshold';
  static const _keySp2Threshold = 'cfg_sp2_threshold';
  static const _keySp3Threshold = 'cfg_sp3_threshold';
  static const _keySkorsingThreshold = 'cfg_skorsing_threshold';
  static const _keyArsipMaxMb = 'cfg_arsip_max_mb';
  static const _keyArsipFolders = 'cfg_arsip_folders';
  static const _keyArsipAllowedExts = 'cfg_arsip_allowed_exts';
  static const _keySekbidList = 'cfg_sekbid_list';
  static const _keyLaporanCategories = 'cfg_laporan_categories';
  static const _keyLaporanFields = 'cfg_laporan_fields';
  static const _keyPelanggaranFields = 'cfg_pelanggaran_fields';
  static const _keyRekapTypes = 'cfg_rekap_types';

  // Rich, curated modern presets
  static const List<ThemePreset> presets = [
    ThemePreset(name: 'Cyan Electric (Bawaan)', color: Color(0xFF00B4D8), darkColor: Color(0xFF03045E), description: 'Segar, energik, & modern'),
    ThemePreset(name: 'Royal Sapphire', color: Color(0xFF2563EB), darkColor: Color(0xFF1E3A8A), description: 'Elegan, profesional, & berwibawa'),
    ThemePreset(name: 'Deep Indigo', color: Color(0xFF4F46E5), darkColor: Color(0xFF1E1B4B), description: 'Mewah, tenang, & futuristik'),
    ThemePreset(name: 'Emerald Aurora', color: Color(0xFF10B981), darkColor: Color(0xFF064E3B), description: 'Natural, harmonis, & sejuk'),
    ThemePreset(name: 'Teal Oceanic', color: Color(0xFF0D9488), darkColor: Color(0xFF134E4A), description: 'Modern, tenang, & stabil'),
    ThemePreset(name: 'Amethyst Purple', color: Color(0xFF8B5CF6), darkColor: Color(0xFF4C1D95), description: 'Kreatif, premium, & artistik'),
    ThemePreset(name: 'Crimson Velvet', color: Color(0xFFE11D48), darkColor: Color(0xFF881337), description: 'Tegas, berani, & dinamis'),
    ThemePreset(name: 'Sunset Coral', color: Color(0xFFF97316), darkColor: Color(0xFF7C2D12), description: 'Hangat, antusias, & ramah'),
    ThemePreset(name: 'Golden Amber', color: Color(0xFFF59E0B), darkColor: Color(0xFF78350F), description: 'Emas berkelas, bercahaya, & prestisius'),
    ThemePreset(name: 'Cyber Magenta', color: Color(0xFFEC4899), darkColor: Color(0xFF831843), description: 'Vibrant, stylish, & berkarakter'),
    ThemePreset(name: 'Slate Titanium', color: Color(0xFF64748B), darkColor: Color(0xFF0F172A), description: 'Minimalis monokrom & bersih'),
  ];

  // Core Value Notifiers
  static final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.system);
  static final ValueNotifier<Color> accentColorNotifier = ValueNotifier(const Color(0xFF00B4D8));
  static final ValueNotifier<String> appNameNotifier = ValueNotifier('OSIS Management');
  static final ValueNotifier<String> appSubtitleNotifier = ValueNotifier('Sistem Manajemen OSIS Digital');
  static final ValueNotifier<String> logoUrlNotifier = ValueNotifier('');
  static final ValueNotifier<List<String>> enabledLanguagesNotifier = ValueNotifier(['id', 'en', 'su', 'jv', 'ar', 'ja']);

  // Admin Config Value Notifiers
  static final ValueNotifier<int> sp1ThresholdNotifier = ValueNotifier(20);
  static final ValueNotifier<int> sp2ThresholdNotifier = ValueNotifier(50);
  static final ValueNotifier<int> sp3ThresholdNotifier = ValueNotifier(75);
  static final ValueNotifier<int> skorsingThresholdNotifier = ValueNotifier(100);

  static final ValueNotifier<int> arsipMaxMbNotifier = ValueNotifier(25);
  static final ValueNotifier<List<String>> arsipFoldersNotifier = ValueNotifier([
    'Surat Masuk',
    'Surat Keluar',
    'Proposal Kegiatan',
    'LPJ Kegiatan',
    'Dokumentasi',
    'SK & Sertifikat',
  ]);
  static final ValueNotifier<List<String>> arsipAllowedExtsNotifier = ValueNotifier([
    'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'jpg', 'jpeg', 'png', 'zip', 'txt',
  ]);

  static final ValueNotifier<List<String>> sekbidListNotifier = ValueNotifier([
    'SEKBID1',
    'SEKBID2',
    'SEKBID3',
    'SEKBID4',
    'SEKBID5',
    'SEKBID6',
    'SEKBID7',
    'SEKBID8',
    'SEKBID9',
    'SEKBID10',
  ]);

  static final ValueNotifier<List<String>> laporanCategoriesNotifier = ValueNotifier([
    'Kegiatan Rutin',
    'Program Unggulan',
    'Peringatan Hari Besar',
    'Lomba & Kompetisi',
    'Bakti Sosial',
    'Rapat Kerja & Pleno',
    'Lainnya',
  ]);

  static final ValueNotifier<List<String>> laporanFieldsNotifier = ValueNotifier([
    'kategori',
    'anggaran',
    'lokasi',
    'ketuplak',
    'deskripsi',
    'hasil',
    'kendala',
    'peserta',
    'dokumentasi',
  ]);

  static final ValueNotifier<List<String>> pelanggaranFieldsNotifier = ValueNotifier([
    'lokasi',
    'petugas',
    'sanksi',
    'poin',
    'keterangan',
  ]);

  static final ValueNotifier<List<String>> rekapTypesNotifier = ValueNotifier([
    'kelas',
    'siswa',
    'jenis',
    'tingkat',
    'sp_level',
  ]);

  static const _keyCustomFields = 'cfg_dynamic_custom_fields';

  static final ValueNotifier<Map<String, List<AppCustomInputField>>> customFieldsNotifier = ValueNotifier({
    'laporan': [
      AppCustomInputField(id: 'lap_nama', label: 'Nama Kegiatan', type: InputFieldType.text, placeholder: 'Contoh: LDKS 2026', isRequired: true),
      AppCustomInputField(id: 'lap_kategori', label: 'Kategori Kegiatan', type: InputFieldType.dropdown, options: ['Kegiatan Rutin', 'Program Unggulan', 'Peringatan Hari Besar', 'Lomba & Kompetisi', 'Bakti Sosial', 'Rapat Kerja & Pleno', 'Lainnya']),
      AppCustomInputField(id: 'lap_tgl', label: 'Tanggal Pelaksanaan', type: InputFieldType.date, isRequired: true),
      AppCustomInputField(id: 'lap_lokasi', label: 'Lokasi Kegiatan', type: InputFieldType.text, placeholder: 'Contoh: Aula Utama'),
      AppCustomInputField(id: 'lap_pj', label: 'Ketua Pelaksana', type: InputFieldType.text, placeholder: 'Nama Penanggung Jawab'),
      AppCustomInputField(id: 'lap_anggaran', label: 'Anggaran Dana (Rp)', type: InputFieldType.number, placeholder: '0'),
      AppCustomInputField(id: 'lap_desk', label: 'Deskripsi Kegiatan', type: InputFieldType.text, placeholder: 'Uraian ringkas kegiatan...'),
      AppCustomInputField(id: 'lap_hasil', label: 'Hasil / Capaian', type: InputFieldType.text, placeholder: 'Hasil yang diperoleh...'),
      AppCustomInputField(id: 'lap_eval', label: 'Kendala & Evaluasi', type: InputFieldType.text, placeholder: 'Evaluasi kegiatan...'),
      AppCustomInputField(id: 'lap_dok', label: 'Lampiran / Dokumentasi', type: InputFieldType.file),
    ],
    'proker': [
      AppCustomInputField(id: 'prok_nama', label: 'Nama Program Kerja', type: InputFieldType.text, placeholder: 'Nama program...', isRequired: true),
      AppCustomInputField(id: 'prok_sekbid', label: 'Divisi / Sekbid', type: InputFieldType.dropdown, options: ['Sekbid 1', 'Sekbid 2', 'Sekbid 3', 'Sekbid 4', 'Sekbid 5', 'Sekbid 6', 'Sekbid 7', 'Sekbid 8', 'Sekbid 9', 'Sekbid 10']),
      AppCustomInputField(id: 'prok_pj', label: 'Penanggung Jawab', type: InputFieldType.text, placeholder: 'Nama PJ proker'),
      AppCustomInputField(id: 'prok_tgl_rencana', label: 'Tanggal Rencana', type: InputFieldType.date, isRequired: true),
      AppCustomInputField(id: 'prok_tgl_realisasi', label: 'Tanggal Realisasi', type: InputFieldType.date),
      AppCustomInputField(id: 'prok_status', label: 'Status Proker', type: InputFieldType.dropdown, options: ['Belum Berjalan', 'Sedang Berjalan', 'Selesai']),
      AppCustomInputField(id: 'prok_desk', label: 'Deskripsi Program', type: InputFieldType.text, placeholder: 'Rincian proker...'),
      AppCustomInputField(id: 'prok_ket', label: 'Keterangan Tambahan', type: InputFieldType.text, placeholder: 'Catatan tambahan...'),
    ],
    'pelanggaran': [
      AppCustomInputField(id: 'pel_siswa', label: 'Nama Siswa', type: InputFieldType.select, placeholder: 'Pilih siswa...', isRequired: true),
      AppCustomInputField(id: 'pel_tgl', label: 'Tanggal Kejadian', type: InputFieldType.date, isRequired: true),
      AppCustomInputField(id: 'pel_jenis', label: 'Jenis Pelanggaran', type: InputFieldType.select, placeholder: 'Pilih jenis tata tertib...', isRequired: true),
      AppCustomInputField(id: 'pel_lokasi', label: 'Lokasi Kejadian', type: InputFieldType.text, placeholder: 'Contoh: Kantin / Kelas'),
      AppCustomInputField(id: 'pel_petugas', label: 'Petugas / Saksi', type: InputFieldType.text, placeholder: 'Nama pencatat atau saksi'),
      AppCustomInputField(id: 'pel_sanksi', label: 'Sanksi / Tindak Lanjut', type: InputFieldType.dropdown, options: ['Teguran Lisan', 'Teguran Tertulis (SP 1)', 'Peringatan Keras (SP 2)', 'Pemanggilan Orang Tua (SP 3)', 'Pembersihan Lingkungan', 'Skorsing']),
      AppCustomInputField(id: 'pel_ket', label: 'Keterangan Tambahan', type: InputFieldType.text, placeholder: 'Catatan detail kejadian...'),
    ],
    'rekap': [
      AppCustomInputField(id: 'rek_dimensi', label: 'Dimensi Rekap', type: InputFieldType.dropdown, options: ['Per Kelas', 'Per Siswa', 'Per Jenis Pelanggaran', 'Per Tingkat Kelas', 'Per Status SP']),
      AppCustomInputField(id: 'rek_sekolah', label: 'Nama Sekolah', type: InputFieldType.text),
      AppCustomInputField(id: 'rek_kota', label: 'Kota / Wilayah', type: InputFieldType.text),
      AppCustomInputField(id: 'rek_thn', label: 'Tahun Ajaran', type: InputFieldType.text),
    ],
    'arsip': [
      AppCustomInputField(id: 'ars_nama', label: 'Nama Dokumen / Berkas', type: InputFieldType.text, placeholder: 'Judul berkas...', isRequired: true),
      AppCustomInputField(id: 'ars_folder', label: 'Folder Kategori', type: InputFieldType.dropdown, options: ['Surat Masuk', 'Surat Keluar', 'Proposal Kegiatan', 'LPJ Kegiatan', 'Dokumentasi', 'SK & Sertifikat']),
      AppCustomInputField(id: 'ars_file', label: 'File Dokumen', type: InputFieldType.file, isRequired: true),
      AppCustomInputField(id: 'ars_ket', label: 'Keterangan Berkas', type: InputFieldType.text, placeholder: 'Keterangan tambahan...'),
    ],
  });

  /// Widget pembangun Logo yang mendukung Base64 File, Network URL, dan Asset bawaan
  static Widget buildLogoWidget({
    double width = 32,
    double height = 32,
    BoxFit fit = BoxFit.contain,
    BorderRadius? borderRadius,
  }) {
    return ValueListenableBuilder<String>(
      valueListenable: logoUrlNotifier,
      builder: (context, logoData, _) {
        final radius = borderRadius ?? BorderRadius.circular(6);
        if (logoData.isEmpty) {
          return ClipRRect(
            borderRadius: radius,
            child: Image.asset('assets/logo.png', width: width, height: height, fit: fit),
          );
        }

        if (logoData.startsWith('data:image/') || logoData.length > 100) {
          try {
            final pureBase64 = logoData.contains(',') ? logoData.split(',').last : logoData;
            final bytes = base64Decode(pureBase64.replaceAll('\n', '').trim());
            return ClipRRect(
              borderRadius: radius,
              child: Image.memory(
                bytes,
                width: width,
                height: height,
                fit: fit,
                errorBuilder: (_, __, ___) => Image.asset('assets/logo.png', width: width, height: height, fit: fit),
              ),
            );
          } catch (_) {
            return ClipRRect(
              borderRadius: radius,
              child: Image.asset('assets/logo.png', width: width, height: height, fit: fit),
            );
          }
        }

        if (logoData.startsWith('http://') || logoData.startsWith('https://')) {
          return ClipRRect(
            borderRadius: radius,
            child: Image.network(
              logoData,
              width: width,
              height: height,
              fit: fit,
              errorBuilder: (_, __, ___) => Image.asset('assets/logo.png', width: width, height: height, fit: fit),
            ),
          );
        }

        return ClipRRect(
          borderRadius: radius,
          child: Image.asset('assets/logo.png', width: width, height: height, fit: fit),
        );
      },
    );
  }

  /// Dynamic Proker unit list including Ketua OSIS, Wakil Ketua OSIS, Sekretaris, Bendahara, and all configured Sekbids
  static List<String> get dynamicProkerUnits {
    final list = <String>[
      'Ketua OSIS',
      'Wakil Ketua OSIS',
      'Sekretaris OSIS',
      'Bendahara OSIS',
    ];
    for (final s in sekbidListNotifier.value) {
      if (!list.contains(s)) {
        list.add(s);
      }
    }
    return list;
  }

  static SupabaseClient? get _supabase {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Load Theme Mode
    final modeStr = prefs.getString(_keyThemeMode) ?? 'system';
    themeModeNotifier.value = _stringToThemeMode(modeStr);

    // 2. Load Accent Color
    final colorVal = prefs.getInt(_keyAccentColor);
    if (colorVal != null) {
      accentColorNotifier.value = Color(colorVal);
    }

    // 3. Load App Branding
    final savedName = prefs.getString(_keyAppName);
    if (savedName != null && savedName.isNotEmpty) {
      appNameNotifier.value = savedName;
    }

    final savedSubtitle = prefs.getString(_keyAppSubtitle);
    if (savedSubtitle != null && savedSubtitle.isNotEmpty) {
      appSubtitleNotifier.value = savedSubtitle;
    }

    final savedLogo = prefs.getString(_keyLogoUrl);
    if (savedLogo != null) {
      logoUrlNotifier.value = savedLogo;
    }

    // 4. Load Enabled Languages
    final savedLangs = prefs.getStringList(_keyEnabledLanguages);
    if (savedLangs != null && savedLangs.isNotEmpty) {
      enabledLanguagesNotifier.value = savedLangs;
    }

    // 5. Load Admin Configs
    sp1ThresholdNotifier.value = prefs.getInt(_keySp1Threshold) ?? sp1ThresholdNotifier.value;
    sp2ThresholdNotifier.value = prefs.getInt(_keySp2Threshold) ?? sp2ThresholdNotifier.value;
    sp3ThresholdNotifier.value = prefs.getInt(_keySp3Threshold) ?? sp3ThresholdNotifier.value;
    skorsingThresholdNotifier.value = prefs.getInt(_keySkorsingThreshold) ?? skorsingThresholdNotifier.value;

    arsipMaxMbNotifier.value = prefs.getInt(_keyArsipMaxMb) ?? arsipMaxMbNotifier.value;

    final savedArsipFolders = prefs.getStringList(_keyArsipFolders);
    if (savedArsipFolders != null && savedArsipFolders.isNotEmpty) {
      arsipFoldersNotifier.value = savedArsipFolders;
    }

    final savedSekbidList = prefs.getStringList(_keySekbidList);
    if (savedSekbidList != null && savedSekbidList.isNotEmpty) {
      sekbidListNotifier.value = savedSekbidList;
    }

    final savedLaporanCats = prefs.getStringList(_keyLaporanCategories);
    if (savedLaporanCats != null && savedLaporanCats.isNotEmpty) {
      laporanCategoriesNotifier.value = savedLaporanCats;
    }

    final savedLaporanFields = prefs.getStringList(_keyLaporanFields);
    if (savedLaporanFields != null && savedLaporanFields.isNotEmpty) {
      laporanFieldsNotifier.value = savedLaporanFields;
    }

    final savedPelanggaranFields = prefs.getStringList(_keyPelanggaranFields);
    if (savedPelanggaranFields != null && savedPelanggaranFields.isNotEmpty) {
      pelanggaranFieldsNotifier.value = savedPelanggaranFields;
    }

    final savedRekapTypes = prefs.getStringList(_keyRekapTypes);
    if (savedRekapTypes != null && savedRekapTypes.isNotEmpty) {
      rekapTypesNotifier.value = savedRekapTypes;
    }

    final savedArsipExts = prefs.getStringList(_keyArsipAllowedExts);
    if (savedArsipExts != null && savedArsipExts.isNotEmpty) {
      arsipAllowedExtsNotifier.value = savedArsipExts;
    }

    final savedCustomFieldsJson = prefs.getString(_keyCustomFields);
    if (savedCustomFieldsJson != null && savedCustomFieldsJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(savedCustomFieldsJson) as Map<String, dynamic>;
        final Map<String, List<AppCustomInputField>> map = {};
        decoded.forEach((key, val) {
          if (val is List) {
            map[key] = val.map((e) => AppCustomInputField.fromJson(Map<String, dynamic>.from(e as Map))).toList();
          }
        });
        if (map.isNotEmpty) {
          customFieldsNotifier.value = map;
        }
      } catch (_) {}
    }

    // 6. Initialize Localization
    await LocalizationService.init();

    // 7. Sync from Cloud
    syncFromSupabase();
  }

  static ThemeMode _stringToThemeMode(String mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      default:
        return 'system';
    }
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    themeModeNotifier.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeMode, _themeModeToString(mode));
  }

  static DateTime _lastLocallyModifiedAt = DateTime.fromMillisecondsSinceEpoch(0);
  static DateTime get lastLocallyModifiedAt => _lastLocallyModifiedAt;

  static Timer? _colorSyncDebounce;
  static Future<void> setAccentColor(Color color, {bool syncCloud = true}) async {
    _lastLocallyModifiedAt = DateTime.now();
    accentColorNotifier.value = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyAccentColor, color.toARGB32());
    if (syncCloud) {
      _colorSyncDebounce?.cancel();
      _colorSyncDebounce = Timer(const Duration(milliseconds: 300), () {
        _saveToSupabase();
      });
    }
  }

  static Future<void> setEnabledLanguages(List<String> langs) async {
    if (langs.isEmpty) langs = ['id'];
    enabledLanguagesNotifier.value = langs;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyEnabledLanguages, langs);
  }

  static Future<void> setLogoUrl(String url) async {
    logoUrlNotifier.value = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLogoUrl, url);
    await _saveToSupabase();
  }

  static Future<void> setAppBranding({
    String? name,
    String? subtitle,
    String? logoUrl,
    Color? globalColor,
    List<String>? enabledLanguages,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (name != null) {
      appNameNotifier.value = name;
      await prefs.setString(_keyAppName, name);
    }
    if (subtitle != null) {
      appSubtitleNotifier.value = subtitle;
      await prefs.setString(_keyAppSubtitle, subtitle);
    }
    if (logoUrl != null) {
      logoUrlNotifier.value = logoUrl;
      await prefs.setString(_keyLogoUrl, logoUrl);
    }
    if (globalColor != null) {
      accentColorNotifier.value = globalColor;
      await prefs.setInt(_keyAccentColor, globalColor.toARGB32());
    }
    if (enabledLanguages != null) {
      enabledLanguagesNotifier.value = enabledLanguages;
      await prefs.setStringList(_keyEnabledLanguages, enabledLanguages);
    }

    await _saveToSupabase();
  }

  static Future<void> saveAdminConfigs({
    int? sp1,
    int? sp2,
    int? sp3,
    int? skorsing,
    int? arsipMaxMb,
    List<String>? arsipFolders,
    List<String>? arsipAllowedExts,
    List<String>? sekbidList,
    List<String>? laporanCategories,
    List<String>? laporanFields,
    List<String>? pelanggaranFields,
    List<String>? rekapTypes,
    Map<String, List<AppCustomInputField>>? customFields,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (customFields != null) {
      customFieldsNotifier.value = customFields;
      final Map<String, dynamic> serializable = {};
      customFields.forEach((k, v) {
        serializable[k] = v.map((f) => f.toJson()).toList();
      });
      await prefs.setString(_keyCustomFields, jsonEncode(serializable));
    }

    if (sp1 != null) {
      sp1ThresholdNotifier.value = sp1;
      await prefs.setInt(_keySp1Threshold, sp1);
    }
    if (sp2 != null) {
      sp2ThresholdNotifier.value = sp2;
      await prefs.setInt(_keySp2Threshold, sp2);
    }
    if (sp3 != null) {
      sp3ThresholdNotifier.value = sp3;
      await prefs.setInt(_keySp3Threshold, sp3);
    }
    if (skorsing != null) {
      skorsingThresholdNotifier.value = skorsing;
      await prefs.setInt(_keySkorsingThreshold, skorsing);
    }

    if (arsipMaxMb != null) {
      arsipMaxMbNotifier.value = arsipMaxMb;
      await prefs.setInt(_keyArsipMaxMb, arsipMaxMb);
    }
    if (arsipFolders != null) {
      arsipFoldersNotifier.value = arsipFolders;
      await prefs.setStringList(_keyArsipFolders, arsipFolders);
    }
    if (arsipAllowedExts != null) {
      arsipAllowedExtsNotifier.value = arsipAllowedExts;
      await prefs.setStringList(_keyArsipAllowedExts, arsipAllowedExts);
    }
    if (sekbidList != null) {
      sekbidListNotifier.value = sekbidList;
      await prefs.setStringList(_keySekbidList, sekbidList);
    }
    if (laporanCategories != null) {
      laporanCategoriesNotifier.value = laporanCategories;
      await prefs.setStringList(_keyLaporanCategories, laporanCategories);
    }
    if (laporanFields != null) {
      laporanFieldsNotifier.value = laporanFields;
      await prefs.setStringList(_keyLaporanFields, laporanFields);
    }
    if (pelanggaranFields != null) {
      pelanggaranFieldsNotifier.value = pelanggaranFields;
      await prefs.setStringList(_keyPelanggaranFields, pelanggaranFields);
    }
    if (rekapTypes != null) {
      rekapTypesNotifier.value = rekapTypes;
      await prefs.setStringList(_keyRekapTypes, rekapTypes);
    }

    await _saveToSupabase();
  }

  static Future<void> _saveToSupabase() async {
    final colorHex = '0x${accentColorNotifier.value.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

    // Broadcast instantly ke semua user secara real-time tanpa menunggu query database
    DataService.broadcastDataChange('app_settings', {
      'primary_color': colorHex,
      'app_name': appNameNotifier.value,
      'app_subtitle': appSubtitleNotifier.value,
      'logo_url': logoUrlNotifier.value,
    });

    final dbData = {
      'id': 'global_config',
      'app_name': appNameNotifier.value,
      'app_subtitle': appSubtitleNotifier.value,
      'logo_url': logoUrlNotifier.value,
      'primary_color': colorHex,
      'sp1_threshold': sp1ThresholdNotifier.value,
      'sp2_threshold': sp2ThresholdNotifier.value,
      'sp3_threshold': sp3ThresholdNotifier.value,
      'skorsing_threshold': skorsingThresholdNotifier.value,
      'arsip_max_mb': arsipMaxMbNotifier.value,
      'arsip_folders': arsipFoldersNotifier.value,
      'arsip_allowed_exts': arsipAllowedExtsNotifier.value,
      'sekbid_list': sekbidListNotifier.value,
      'laporan_categories': laporanCategoriesNotifier.value,
      'laporan_fields': laporanFieldsNotifier.value,
      'pelanggaran_fields': pelanggaranFieldsNotifier.value,
      'rekap_types': rekapTypesNotifier.value,
      'custom_fields': (() {
        final Map<String, dynamic> jsonMap = {};
        customFieldsNotifier.value.forEach((k, v) {
          jsonMap[k] = v.map((f) => f.toJson()).toList();
        });
        return jsonMap;
      })(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (SyncService.isOnline) {
      try {
        final client = _supabase;
        if (client != null) {
          try {
            await client.from('app_settings').upsert(dbData, onConflict: 'id');
          } catch (_) {
            // Fallback jika database belum dimigrasi kolom barunya
            final baseData = {
              'id': 'global_config',
              'app_name': appNameNotifier.value,
              'app_subtitle': appSubtitleNotifier.value,
              'logo_url': logoUrlNotifier.value,
              'primary_color': colorHex,
              'sp1_threshold': sp1ThresholdNotifier.value,
              'sp2_threshold': sp2ThresholdNotifier.value,
              'sp3_threshold': sp3ThresholdNotifier.value,
              'skorsing_threshold': skorsingThresholdNotifier.value,
              'arsip_max_mb': arsipMaxMbNotifier.value,
              'arsip_folders': arsipFoldersNotifier.value,
              'sekbid_list': sekbidListNotifier.value,
              'laporan_categories': laporanCategoriesNotifier.value,
              'updated_at': DateTime.now().toIso8601String(),
            };
            await client.from('app_settings').upsert(baseData, onConflict: 'id');
          }
          await DataService.broadcastDataChange('app_settings', {'primary_color': colorHex});
        }
      } catch (e) {
        await SyncService.enqueueAction(
          actionType: SyncActionType.upsert,
          table: 'app_settings',
          data: dbData,
          targetId: 'global_config',
        );
      }
    } else {
      await SyncService.enqueueAction(
        actionType: SyncActionType.upsert,
        table: 'app_settings',
        data: dbData,
        targetId: 'global_config',
      );
    }
  }

  static Future<void> syncFromSupabase() async {
    try {
      final client = _supabase;
      if (client == null) return;

      final rows = await client.from('app_settings').select().eq('id', 'global_config').limit(1);
      if (rows.isNotEmpty) {
        final data = rows.first;
        final name = data['app_name']?.toString();
        final sub = data['app_subtitle']?.toString();
        final logo = data['logo_url']?.toString();
        final colorStr = data['primary_color']?.toString();

        final prefs = await SharedPreferences.getInstance();

        if (name != null && name.isNotEmpty) {
          appNameNotifier.value = name;
          await prefs.setString(_keyAppName, name);
        }
        if (sub != null && sub.isNotEmpty) {
          appSubtitleNotifier.value = sub;
          await prefs.setString(_keyAppSubtitle, sub);
        }
        if (logo != null) {
          logoUrlNotifier.value = logo;
          await prefs.setString(_keyLogoUrl, logo);
        }

        if (colorStr != null && colorStr.isNotEmpty) {
          final isRecentLocalEdit = DateTime.now().difference(_lastLocallyModifiedAt).inSeconds < 5;
          if (!isRecentLocalEdit) {
            try {
              final parsedInt = int.parse(colorStr.replaceFirst('#', '').replaceFirst('0x', ''), radix: 16);
              final fullColor = (parsedInt <= 0xFFFFFF) ? 0xFF000000 | parsedInt : parsedInt;
              accentColorNotifier.value = Color(fullColor);
              await prefs.setInt(_keyAccentColor, fullColor);
            } catch (_) {}
          }
        }



        if (data['sp1_threshold'] != null) {
          sp1ThresholdNotifier.value = int.tryParse(data['sp1_threshold'].toString()) ?? 20;
          await prefs.setInt(_keySp1Threshold, sp1ThresholdNotifier.value);
        }
        if (data['sp2_threshold'] != null) {
          sp2ThresholdNotifier.value = int.tryParse(data['sp2_threshold'].toString()) ?? 50;
          await prefs.setInt(_keySp2Threshold, sp2ThresholdNotifier.value);
        }
        if (data['sp3_threshold'] != null) {
          sp3ThresholdNotifier.value = int.tryParse(data['sp3_threshold'].toString()) ?? 75;
          await prefs.setInt(_keySp3Threshold, sp3ThresholdNotifier.value);
        }
        if (data['skorsing_threshold'] != null) {
          skorsingThresholdNotifier.value = int.tryParse(data['skorsing_threshold'].toString()) ?? 100;
          await prefs.setInt(_keySkorsingThreshold, skorsingThresholdNotifier.value);
        }
        if (data['arsip_max_mb'] != null) {
          arsipMaxMbNotifier.value = int.tryParse(data['arsip_max_mb'].toString()) ?? 25;
          await prefs.setInt(_keyArsipMaxMb, arsipMaxMbNotifier.value);
        }

        if (data['arsip_folders'] != null && data['arsip_folders'] is List) {
          final folders = (data['arsip_folders'] as List).map((e) => e.toString()).toList();
          arsipFoldersNotifier.value = folders;
          await prefs.setStringList(_keyArsipFolders, folders);
        }
        if (data['arsip_allowed_exts'] != null && data['arsip_allowed_exts'] is List) {
          final exts = (data['arsip_allowed_exts'] as List).map((e) => e.toString()).toList();
          arsipAllowedExtsNotifier.value = exts;
          await prefs.setStringList(_keyArsipAllowedExts, exts);
        }
        if (data['sekbid_list'] != null && data['sekbid_list'] is List) {
          final sekbids = (data['sekbid_list'] as List).map((e) => e.toString()).toList();
          sekbidListNotifier.value = sekbids;
          await prefs.setStringList(_keySekbidList, sekbids);
        }
        if (data['laporan_categories'] != null && data['laporan_categories'] is List) {
          final cats = (data['laporan_categories'] as List).map((e) => e.toString()).toList();
          laporanCategoriesNotifier.value = cats;
          await prefs.setStringList(_keyLaporanCategories, cats);
        }
        if (data['laporan_fields'] != null && data['laporan_fields'] is List) {
          final flds = (data['laporan_fields'] as List).map((e) => e.toString()).toList();
          laporanFieldsNotifier.value = flds;
          await prefs.setStringList(_keyLaporanFields, flds);
        }
        if (data['pelanggaran_fields'] != null && data['pelanggaran_fields'] is List) {
          final pflds = (data['pelanggaran_fields'] as List).map((e) => e.toString()).toList();
          pelanggaranFieldsNotifier.value = pflds;
          await prefs.setStringList(_keyPelanggaranFields, pflds);
        }
        if (data['rekap_types'] != null && data['rekap_types'] is List) {
          final rtypes = (data['rekap_types'] as List).map((e) => e.toString()).toList();
          rekapTypesNotifier.value = rtypes;
          await prefs.setStringList(_keyRekapTypes, rtypes);
        }
        if (data['custom_fields'] != null) {
          try {
            dynamic raw = data['custom_fields'];
            if (raw is String) {
              raw = jsonDecode(raw);
            }
            if (raw is Map) {
              final Map<String, List<AppCustomInputField>> map = {};
              raw.forEach((key, val) {
                if (val is List) {
                  map[key.toString()] = val.map((e) => AppCustomInputField.fromJson(Map<String, dynamic>.from(e as Map))).toList();
                }
              });
              if (map.isNotEmpty) {
                customFieldsNotifier.value = map;
                await prefs.setString(_keyCustomFields, jsonEncode(raw));
              }
            }
          } catch (e) {
            debugPrint('AppSettingsService syncFromSupabase custom_fields warning: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('AppSettingsService syncFromSupabase warning: $e');
    }
  }
}
