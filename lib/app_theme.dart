import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const kDefaultPrimary     = Color(0xFFA2EBFB);
const kDefaultAccent      = Color(0xFF00B4D8);
const kDefaultDark        = Color(0xFF03045E);
const kDefaultPrimaryDark = Color(0xFF0077B6);

ThemeData buildAppTheme({
  bool isDark = false,
  Color? primaryColor,
  Color? darkAccentColor,
}) {
  final accent = primaryColor ?? kDefaultAccent;
  final darkBg = const Color(0xFF0F172A);
  final darkSurface = const Color(0xFF1E293B);
  final darkCard = const Color(0xFF1E293B);
  final darkBorder = const Color(0xFF334155);

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
        secondary: accent.withAlpha(200),
        onSecondary: Colors.white,
        primaryContainer: accent.withAlpha(50),
        onPrimaryContainer: Colors.white,
        secondaryContainer: darkSurface,
        onSecondaryContainer: Colors.white,
        surface: darkSurface,
        onSurface: const Color(0xFFF1F5F9),
        error: const Color(0xFFEF4444),
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: darkBg,
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF111827),
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
      cardTheme: CardTheme(
        color: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: darkBorder),
        ),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: darkBorder),
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
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF0F172A),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        labelStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.normal),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.black,
        elevation: 2,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF111827),
        indicatorColor: accent.withAlpha(40),
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
      dividerTheme: DividerThemeData(color: darkBorder, thickness: 1, space: 1),
      chipTheme: ChipThemeData(
        backgroundColor: darkSurface,
        labelStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: BorderSide(color: darkBorder),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
      onSecondary: const Color(0xFF03045E),
      primaryContainer: accent.withAlpha(35),
      onPrimaryContainer: const Color(0xFF03045E),
      secondaryContainer: const Color(0xFFF1F5F9),
      onSecondaryContainer: const Color(0xFF03045E),
      surface: lightSurface,
      onSurface: const Color(0xFF0F172A),
      error: const Color(0xFFD62828),
      onError: Colors.white,
    ),
    scaffoldBackgroundColor: lightBg,
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF03045E),
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleTextStyle: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        letterSpacing: 0.3,
      ),
    ),
    cardTheme: CardTheme(
      color: lightSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: lightBorder),
      ),
    ),
    dialogTheme: DialogTheme(
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
      labelStyle: const TextStyle(color: Color(0xFF0077B6), fontSize: 14),
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
        return const IconThemeData(color: Color(0xFFCFD8DC), size: 22);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: accent, letterSpacing: 0.2);
        }
        return const TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: Color(0xFFB0BEC5), letterSpacing: 0.2);
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
      backgroundColor: const Color(0xFFE8FAFF),
      labelStyle: const TextStyle(color: Color(0xFF0077B6), fontSize: 12, fontWeight: FontWeight.w500),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    ),
  );
}

// Backward compatibility constants
const kPrimary     = Color(0xFFA2EBFB);
const kAccent      = Color(0xFF00B4D8);
const kDark        = Color(0xFF03045E);
const kPrimaryDark = Color(0xFF0077B6);
const kBg          = Color(0xFFF4FEFF);
const kSurface     = Colors.white;
const kTextDark    = Color(0xFF03045E);
const kTextMid     = Color(0xFF0077B6);
const kTextLight   = Color(0xFF90E0EF);
const kDivider     = Color(0xFFCAF0F8);
