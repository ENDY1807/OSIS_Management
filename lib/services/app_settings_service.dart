import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'localization_service.dart';
import 'data_service.dart';
import 'sync_service.dart';

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
  static const _keySchoolName = 'cfg_school_name';
  static const _keyCity = 'cfg_city';
  static const _keyAcademicYear = 'cfg_academic_year';
  static const _keyKepsekName = 'cfg_kepsek_name';
  static const _keyKepsekNip = 'cfg_kepsek_nip';
  static const _keyPembinaName = 'cfg_pembina_name';
  static const _keyPembinaNip = 'cfg_pembina_nip';
  static const _keyKetosName = 'cfg_ketos_name';
  static const _keyKetosNis = 'cfg_ketos_nis';
  static const _keySekretarisName = 'cfg_sekretaris_name';
  static const _keySekretarisNis = 'cfg_sekretaris_nis';
  static const _keyTtdKepsek = 'cfg_ttd_kepsek';
  static const _keyTtdPembina = 'cfg_ttd_pembina';
  static const _keyTtdKetos = 'cfg_ttd_ketos';
  static const _keyTtdSekretaris = 'cfg_ttd_sekretaris';
  static const _keySp1Threshold = 'cfg_sp1_threshold';
  static const _keySp2Threshold = 'cfg_sp2_threshold';
  static const _keySp3Threshold = 'cfg_sp3_threshold';
  static const _keySkorsingThreshold = 'cfg_skorsing_threshold';
  static const _keyArsipMaxMb = 'cfg_arsip_max_mb';
  static const _keyArsipFolders = 'cfg_arsip_folders';
  static const _keySekbidList = 'cfg_sekbid_list';
  static const _keyLaporanCategories = 'cfg_laporan_categories';

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
  static final ValueNotifier<String> schoolNameNotifier = ValueNotifier('SMK Bakti Nusantara 666');
  static final ValueNotifier<String> cityNotifier = ValueNotifier('Bandung');
  static final ValueNotifier<String> academicYearNotifier = ValueNotifier('2026/2027');

  static final ValueNotifier<String> kepsekNameNotifier = ValueNotifier('Drs. H. Ahmad Sudrajat, M.M.');
  static final ValueNotifier<String> kepsekNipNotifier = ValueNotifier('19750815 199903 1 004');
  static final ValueNotifier<String> pembinaNameNotifier = ValueNotifier('Rina Marlina, S.Pd.');
  static final ValueNotifier<String> pembinaNipNotifier = ValueNotifier('19880210 201502 2 001');
  static final ValueNotifier<String> ketosNameNotifier = ValueNotifier('Endy Mahavira');
  static final ValueNotifier<String> ketosNisNotifier = ValueNotifier('22231001');
  static final ValueNotifier<String> sekretarisNameNotifier = ValueNotifier('Siti Nurhaliza');
  static final ValueNotifier<String> sekretarisNisNotifier = ValueNotifier('22231045');

  static final ValueNotifier<String> ttdKepsekNotifier = ValueNotifier('');
  static final ValueNotifier<String> ttdPembinaNotifier = ValueNotifier('');
  static final ValueNotifier<String> ttdKetosNotifier = ValueNotifier('');
  static final ValueNotifier<String> ttdSekretarisNotifier = ValueNotifier('');

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

  static final ValueNotifier<List<String>> sekbidListNotifier = ValueNotifier([
    'BPH (Inti)',
    'SEKBID 1 (Keagamaan & Ketaqwaan)',
    'SEKBID 2 (Budi Pekerti & Ketertiban)',
    'SEKBID 3 (Wawasan Kebangsaan & Bela Negara)',
    'SEKBID 4 (Prestasi Akademik, Seni, Olahraga)',
    'SEKBID 5 (Demokrasi, HAM & Pendidikan Politik)',
    'SEKBID 6 (Kreativitas, Keterampilan & Kewirausahaan)',
    'SEKBID 7 (Kualitas Jasmani, Kesehatan & Gizi)',
    'SEKBID 8 (Sastra & Budaya)',
    'SEKBID 9 (Teknologi Informasi & Komunikasi)',
    'SEKBID 10 (Komunikasi Bahasa Asing)',
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
    schoolNameNotifier.value = prefs.getString(_keySchoolName) ?? schoolNameNotifier.value;
    cityNotifier.value = prefs.getString(_keyCity) ?? cityNotifier.value;
    academicYearNotifier.value = prefs.getString(_keyAcademicYear) ?? academicYearNotifier.value;

    kepsekNameNotifier.value = prefs.getString(_keyKepsekName) ?? kepsekNameNotifier.value;
    kepsekNipNotifier.value = prefs.getString(_keyKepsekNip) ?? kepsekNipNotifier.value;
    pembinaNameNotifier.value = prefs.getString(_keyPembinaName) ?? pembinaNameNotifier.value;
    pembinaNipNotifier.value = prefs.getString(_keyPembinaNip) ?? pembinaNipNotifier.value;
    ketosNameNotifier.value = prefs.getString(_keyKetosName) ?? ketosNameNotifier.value;
    ketosNisNotifier.value = prefs.getString(_keyKetosNis) ?? ketosNisNotifier.value;
    sekretarisNameNotifier.value = prefs.getString(_keySekretarisName) ?? sekretarisNameNotifier.value;
    sekretarisNisNotifier.value = prefs.getString(_keySekretarisNis) ?? sekretarisNisNotifier.value;

    ttdKepsekNotifier.value = prefs.getString(_keyTtdKepsek) ?? '';
    ttdPembinaNotifier.value = prefs.getString(_keyTtdPembina) ?? '';
    ttdKetosNotifier.value = prefs.getString(_keyTtdKetos) ?? '';
    ttdSekretarisNotifier.value = prefs.getString(_keyTtdSekretaris) ?? '';

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

  static Future<void> setAccentColor(Color color, {bool syncCloud = true}) async {
    accentColorNotifier.value = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyAccentColor, color.toARGB32());
    if (syncCloud) {
      await _saveToSupabase();
    }
  }

  static Future<void> setEnabledLanguages(List<String> langs) async {
    if (langs.isEmpty) langs = ['id'];
    enabledLanguagesNotifier.value = langs;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyEnabledLanguages, langs);
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
    String? schoolName,
    String? city,
    String? academicYear,
    String? kepsekName,
    String? kepsekNip,
    String? pembinaName,
    String? pembinaNip,
    String? ketosName,
    String? ketosNis,
    String? sekretarisName,
    String? sekretarisNis,
    String? ttdKepsek,
    String? ttdPembina,
    String? ttdKetos,
    String? ttdSekretaris,
    int? sp1,
    int? sp2,
    int? sp3,
    int? skorsing,
    int? arsipMaxMb,
    List<String>? arsipFolders,
    List<String>? sekbidList,
    List<String>? laporanCategories,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (schoolName != null) {
      schoolNameNotifier.value = schoolName;
      await prefs.setString(_keySchoolName, schoolName);
    }
    if (city != null) {
      cityNotifier.value = city;
      await prefs.setString(_keyCity, city);
    }
    if (academicYear != null) {
      academicYearNotifier.value = academicYear;
      await prefs.setString(_keyAcademicYear, academicYear);
    }

    if (kepsekName != null) {
      kepsekNameNotifier.value = kepsekName;
      await prefs.setString(_keyKepsekName, kepsekName);
    }
    if (kepsekNip != null) {
      kepsekNipNotifier.value = kepsekNip;
      await prefs.setString(_keyKepsekNip, kepsekNip);
    }
    if (pembinaName != null) {
      pembinaNameNotifier.value = pembinaName;
      await prefs.setString(_keyPembinaName, pembinaName);
    }
    if (pembinaNip != null) {
      pembinaNipNotifier.value = pembinaNip;
      await prefs.setString(_keyPembinaNip, pembinaNip);
    }
    if (ketosName != null) {
      ketosNameNotifier.value = ketosName;
      await prefs.setString(_keyKetosName, ketosName);
    }
    if (ketosNis != null) {
      ketosNisNotifier.value = ketosNis;
      await prefs.setString(_keyKetosNis, ketosNis);
    }
    if (sekretarisName != null) {
      sekretarisNameNotifier.value = sekretarisName;
      await prefs.setString(_keySekretarisName, sekretarisName);
    }
    if (sekretarisNis != null) {
      sekretarisNisNotifier.value = sekretarisNis;
      await prefs.setString(_keySekretarisNis, sekretarisNis);
    }

    if (ttdKepsek != null) {
      ttdKepsekNotifier.value = ttdKepsek;
      await prefs.setString(_keyTtdKepsek, ttdKepsek);
    }
    if (ttdPembina != null) {
      ttdPembinaNotifier.value = ttdPembina;
      await prefs.setString(_keyTtdPembina, ttdPembina);
    }
    if (ttdKetos != null) {
      ttdKetosNotifier.value = ttdKetos;
      await prefs.setString(_keyTtdKetos, ttdKetos);
    }
    if (ttdSekretaris != null) {
      ttdSekretarisNotifier.value = ttdSekretaris;
      await prefs.setString(_keyTtdSekretaris, ttdSekretaris);
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
    if (sekbidList != null) {
      sekbidListNotifier.value = sekbidList;
      await prefs.setStringList(_keySekbidList, sekbidList);
    }
    if (laporanCategories != null) {
      laporanCategoriesNotifier.value = laporanCategories;
      await prefs.setStringList(_keyLaporanCategories, laporanCategories);
    }

    await _saveToSupabase();
  }

  static Future<void> _saveToSupabase() async {
    final colorHex = '0x${accentColorNotifier.value.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
    final dbData = {
      'id': 'global_config',
      'app_name': appNameNotifier.value,
      'app_subtitle': appSubtitleNotifier.value,
      'logo_url': logoUrlNotifier.value,
      'primary_color': colorHex,
      'school_name': schoolNameNotifier.value,
      'city': cityNotifier.value,
      'academic_year': academicYearNotifier.value,
      'kepsek_name': kepsekNameNotifier.value,
      'kepsek_nip': kepsekNipNotifier.value,
      'pembina_name': pembinaNameNotifier.value,
      'pembina_nip': pembinaNipNotifier.value,
      'ketos_name': ketosNameNotifier.value,
      'ketos_nis': ketosNisNotifier.value,
      'sekretaris_name': sekretarisNameNotifier.value,
      'sekretaris_nis': sekretarisNisNotifier.value,
      'ttd_kepsek': ttdKepsekNotifier.value,
      'ttd_pembina': ttdPembinaNotifier.value,
      'ttd_ketos': ttdKetosNotifier.value,
      'ttd_sekretaris': ttdSekretarisNotifier.value,
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

    if (SyncService.isOnline) {
      try {
        final client = _supabase;
        if (client != null) {
          await client.from('app_settings').upsert(dbData, onConflict: 'id');
          await DataService.broadcastDataChange('app_settings');
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
          try {
            final parsedInt = int.parse(colorStr.replaceFirst('#', '').replaceFirst('0x', ''), radix: 16);
            final fullColor = (parsedInt <= 0xFFFFFF) ? 0xFF000000 | parsedInt : parsedInt;
            accentColorNotifier.value = Color(fullColor);
            await prefs.setInt(_keyAccentColor, fullColor);
          } catch (_) {}
        }

        if (data['school_name'] != null) {
          schoolNameNotifier.value = data['school_name'].toString();
          await prefs.setString(_keySchoolName, schoolNameNotifier.value);
        }
        if (data['city'] != null) {
          cityNotifier.value = data['city'].toString();
          await prefs.setString(_keyCity, cityNotifier.value);
        }
        if (data['academic_year'] != null) {
          academicYearNotifier.value = data['academic_year'].toString();
          await prefs.setString(_keyAcademicYear, academicYearNotifier.value);
        }

        if (data['kepsek_name'] != null) {
          kepsekNameNotifier.value = data['kepsek_name'].toString();
          await prefs.setString(_keyKepsekName, kepsekNameNotifier.value);
        }
        if (data['kepsek_nip'] != null) {
          kepsekNipNotifier.value = data['kepsek_nip'].toString();
          await prefs.setString(_keyKepsekNip, kepsekNipNotifier.value);
        }
        if (data['pembina_name'] != null) {
          pembinaNameNotifier.value = data['pembina_name'].toString();
          await prefs.setString(_keyPembinaName, pembinaNameNotifier.value);
        }
        if (data['pembina_nip'] != null) {
          pembinaNipNotifier.value = data['pembina_nip'].toString();
          await prefs.setString(_keyPembinaNip, pembinaNipNotifier.value);
        }
        if (data['ketos_name'] != null) {
          ketosNameNotifier.value = data['ketos_name'].toString();
          await prefs.setString(_keyKetosName, ketosNameNotifier.value);
        }
        if (data['ketos_nis'] != null) {
          ketosNisNotifier.value = data['ketos_nis'].toString();
          await prefs.setString(_keyKetosNis, ketosNisNotifier.value);
        }
        if (data['sekretaris_name'] != null) {
          sekretarisNameNotifier.value = data['sekretaris_name'].toString();
          await prefs.setString(_keySekretarisName, sekretarisNameNotifier.value);
        }
        if (data['sekretaris_nis'] != null) {
          sekretarisNisNotifier.value = data['sekretaris_nis'].toString();
          await prefs.setString(_keySekretarisNis, sekretarisNisNotifier.value);
        }

        if (data['ttd_kepsek'] != null) {
          ttdKepsekNotifier.value = data['ttd_kepsek'].toString();
          await prefs.setString(_keyTtdKepsek, ttdKepsekNotifier.value);
        }
        if (data['ttd_pembina'] != null) {
          ttdPembinaNotifier.value = data['ttd_pembina'].toString();
          await prefs.setString(_keyTtdPembina, ttdPembinaNotifier.value);
        }
        if (data['ttd_ketos'] != null) {
          ttdKetosNotifier.value = data['ttd_ketos'].toString();
          await prefs.setString(_keyTtdKetos, ttdKetosNotifier.value);
        }
        if (data['ttd_sekretaris'] != null) {
          ttdSekretarisNotifier.value = data['ttd_sekretaris'].toString();
          await prefs.setString(_keyTtdSekretaris, ttdSekretarisNotifier.value);
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
      }
    } catch (e) {
      debugPrint('AppSettingsService syncFromSupabase warning: $e');
    }
  }
}
