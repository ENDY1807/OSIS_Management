import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'localization_service.dart';
import 'data_service.dart';

class ThemePreset {
  final String name;
  final Color color;
  final Color darkColor;
  const ThemePreset({required this.name, required this.color, required this.darkColor});
}

class AppSettingsService {
  static const _keyThemeMode = 'app_theme_mode';
  static const _keyAccentColor = 'app_accent_color';
  static const _keyAppName = 'app_custom_name';
  static const _keyAppSubtitle = 'app_custom_subtitle';
  static const _keyLogoUrl = 'app_logo_url';

  static const List<ThemePreset> presets = [
    ThemePreset(name: 'Cyan Sky (Bawaan)', color: Color(0xFF00B4D8), darkColor: Color(0xFF03045E)),
    ThemePreset(name: 'Royal Indigo', color: Color(0xFF4F46E5), darkColor: Color(0xFF1E1B4B)),
    ThemePreset(name: 'Emerald Green', color: Color(0xFF10B981), darkColor: Color(0xFF064E3B)),
    ThemePreset(name: 'Deep Purple', color: Color(0xFF8B5CF6), darkColor: Color(0xFF4C1D95)),
    ThemePreset(name: 'Sunset Orange', color: Color(0xFFF97316), darkColor: Color(0xFF7C2D12)),
    ThemePreset(name: 'Crimson Rose', color: Color(0xFFE11D48), darkColor: Color(0xFF881337)),
    ThemePreset(name: 'Teal Ocean', color: Color(0xFF0D9488), darkColor: Color(0xFF134E4A)),
  ];

  static final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.system);
  static final ValueNotifier<Color> accentColorNotifier = ValueNotifier(const Color(0xFF00B4D8));
  static final ValueNotifier<String> appNameNotifier = ValueNotifier('OSIS Management');
  static final ValueNotifier<String> appSubtitleNotifier = ValueNotifier('Sistem Manajemen OSIS Digital');
  static final ValueNotifier<String> logoUrlNotifier = ValueNotifier('');

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

    // 4. Initialize Localization
    await LocalizationService.init();

    // 5. Sync from Cloud
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

  static Future<void> setAccentColor(Color color) async {
    accentColorNotifier.value = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyAccentColor, color.toARGB32());
  }

  static Future<void> setAppBranding({
    String? name,
    String? subtitle,
    String? logoUrl,
    Color? globalColor,
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

    // Save to Supabase Cloud if online
    try {
      final client = _supabase;
      if (client != null) {
        final colorHex = '0x${(globalColor ?? accentColorNotifier.value).toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
        await client.from('app_settings').upsert({
          'id': 'global_config',
          'app_name': appNameNotifier.value,
          'app_subtitle': appSubtitleNotifier.value,
          'logo_url': logoUrlNotifier.value,
          'primary_color': colorHex,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'id');
        await DataService.broadcastDataChange('app_settings');
      }
    } catch (e) {
      debugPrint('AppSettingsService saveToSupabase warning: $e');
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

        if (name != null && name.isNotEmpty) appNameNotifier.value = name;
        if (sub != null && sub.isNotEmpty) appSubtitleNotifier.value = sub;
        if (logo != null) logoUrlNotifier.value = logo;

        if (colorStr != null && colorStr.isNotEmpty) {
          try {
            final parsedInt = int.parse(colorStr.replaceFirst('#', '').replaceFirst('0x', ''), radix: 16);
            final fullColor = (parsedInt <= 0xFFFFFF) ? 0xFF000000 | parsedInt : parsedInt;
            accentColorNotifier.value = Color(fullColor);
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('AppSettingsService syncFromSupabase warning: $e');
    }
  }
}
