import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/app_settings_service.dart';

// Dynamic color helpers
Color get appPrimary => AppSettingsService.accentColorNotifier.value;
Color get appPrimaryDark {
  final hsv = HSVColor.fromColor(appPrimary);
  return hsv.withValue((hsv.value * 0.75).clamp(0.0, 1.0)).toColor();
}
Color get appPrimaryLight {
  final hsv = HSVColor.fromColor(appPrimary);
  return hsv.withSaturation((hsv.saturation * 0.35).clamp(0.0, 1.0)).toColor();
}

ThemeData buildAppTheme({
  bool isDark = false,
  Color? primaryColor,
  Color? darkAccentColor,
}) {
  final accent = primaryColor ?? AppSettingsService.accentColorNotifier.value;

  // Modern Discord / Linear / Spotify style dark mode palette
  final darkBg = const Color(0xFF0B0F17);
  final darkSurface = const Color(0xFF131A26);
  final darkElevated = const Color(0xFF1B2433);
  final darkInput = const Color(0xFF0F1521);
  final darkBorder = const Color(0xFF263348);
  final darkTextPrimary = const Color(0xFFF8FAFC);
  final darkTextSecondary = const Color(0xFF94A3B8);

  final lightBg = const Color(0xFFF8FAFC);
  final lightSurface = Colors.white;
  final lightBorder = const Color(0xFFE2E8F0);

  if (isDark) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Roboto',
      colorScheme: ColorScheme(
        brightness: Brightness.dark,
        primary: accent,
        onPrimary: Colors.black,
        secondary: accent,
        onSecondary: Colors.white,
        primaryContainer: accent.withAlpha(45),
        onPrimaryContainer: const Color(0xFFE0F7FA),
        secondaryContainer: darkElevated,
        onSecondaryContainer: darkTextPrimary,
        surface: darkSurface,
        onSurface: darkTextPrimary,
        surfaceContainerLowest: darkBg,
        surfaceContainerLow: darkInput,
        surfaceContainer: darkSurface,
        surfaceContainerHigh: darkElevated,
        surfaceContainerHighest: const Color(0xFF222E40),
        outline: darkBorder,
        outlineVariant: const Color(0xFF1A2436),
        error: const Color(0xFFEF4444),
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: darkBg,
      appBarTheme: AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: darkTextPrimary,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: darkTextPrimary,
          letterSpacing: 0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: darkBorder, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: darkBorder, width: 1),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: darkSurface,
        modalBackgroundColor: darkSurface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 0.3),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkInput,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: darkBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: darkBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent, width: 1.8),
        ),
        labelStyle: TextStyle(color: darkTextSecondary, fontSize: 14),
        hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14, fontWeight: FontWeight.normal),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkBg,
        indicatorColor: accent.withAlpha(45),
        surfaceTintColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return IconThemeData(color: accent, size: 22);
          return const IconThemeData(color: Color(0xFF64748B), size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: accent, letterSpacing: 0.2);
          }
          return const TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: Color(0xFF64748B), letterSpacing: 0.2);
        }),
        height: 64,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: accent,
        unselectedLabelColor: const Color(0xFF64748B),
        indicatorColor: accent,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        indicatorSize: TabBarIndicatorSize.tab,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: darkBorder, width: 1),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: darkSurface,
        contentTextStyle: TextStyle(color: darkTextPrimary, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: DividerThemeData(color: darkBorder, thickness: 1, space: 1),
      chipTheme: ChipThemeData(
        backgroundColor: darkElevated,
        labelStyle: TextStyle(color: darkTextPrimary, fontSize: 12, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(color: darkBorder, width: 1),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
    );
  }

  // Light Theme
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: 'Roboto',
    colorScheme: ColorScheme(
      brightness: Brightness.light,
      primary: accent,
      onPrimary: Colors.white,
      secondary: accent.withAlpha(200),
      onSecondary: Colors.white,
      primaryContainer: accent.withAlpha(35),
      onPrimaryContainer: const Color(0xFF0F172A),
      secondaryContainer: const Color(0xFFF1F5F9),
      onSecondaryContainer: const Color(0xFF0F172A),
      surface: lightSurface,
      onSurface: const Color(0xFF0F172A),
      error: const Color(0xFFD62828),
      onError: Colors.white,
    ),
    scaffoldBackgroundColor: lightBg,
    appBarTheme: AppBarTheme(
      backgroundColor: accent,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleTextStyle: const TextStyle(
        fontFamily: 'Roboto',
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        letterSpacing: 0.3,
      ),
    ),
    cardTheme: CardThemeData(
      color: lightSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: lightBorder),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      modalBackgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: lightSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: lightBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: lightBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: accent, width: 1.5),
      ),
      labelStyle: TextStyle(color: accent, fontSize: 14),
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14, fontWeight: FontWeight.normal),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: accent,
      foregroundColor: Colors.white,
      elevation: 2,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: lightSurface,
      indicatorColor: accent.withAlpha(35),
      surfaceTintColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return IconThemeData(color: accent, size: 22);
        return const IconThemeData(color: Color(0xFF94A3B8), size: 22);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: accent, letterSpacing: 0.2);
        }
        return const TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: Color(0xFF94A3B8), letterSpacing: 0.2);
      }),
      height: 64,
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: Colors.white,
      unselectedLabelColor: Color(0x99FFFFFF),
      indicatorColor: Colors.white,
      labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w400, fontSize: 13),
      indicatorSize: TabBarIndicatorSize.label,
    ),
    dividerTheme: DividerThemeData(color: lightBorder, thickness: 1, space: 1),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFFF1F5F9),
      labelStyle: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w500),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    ),
  );
}

// Backward compatibility constants (compile-time constant for const widgets)
const kDefaultPrimary     = Color(0xFFA2EBFB);
const kDefaultAccent      = Color(0xFF00B4D8);
const kDefaultDark        = Color(0xFF0F172A);
const kDefaultPrimaryDark = Color(0xFF0077B6);

const kPrimary     = Color(0xFFA2EBFB);
const kAccent      = Color(0xFF00B4D8);
const kDark        = Color(0xFF0F172A);
const kPrimaryDark = Color(0xFF0077B6);
const kBg          = Color(0xFFF8FAFC);
const kSurface     = Colors.white;
const kTextDark    = Color(0xFF0F172A);
const kTextMid     = Color(0xFF0077B6);
const kTextLight   = Color(0xFF90E0EF);
const kDivider     = Color(0xFFE2E8F0);
