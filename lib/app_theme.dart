import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const kPrimary     = Color(0xFFA2EBFB);
const kAccent      = Color(0xFF00B4D8);
const kDark        = Color(0xFF03045E);
const kPrimaryDark = Color(0xFF0077B6);
const kBg        = Color(0xFFF4FEFF);
const kSurface   = Colors.white;
const kTextDark  = Color(0xFF03045E);
const kTextMid   = Color(0xFF0077B6);
const kTextLight = Color(0xFF90E0EF);
const kDivider   = Color(0xFFCAF0F8);

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    colorScheme: ColorScheme(
      brightness: Brightness.light,
      primary: kAccent,
      onPrimary: Colors.white,
      secondary: kPrimary,
      onSecondary: kTextDark,
      primaryContainer: const Color(0xFFD0F4FF),
      onPrimaryContainer: kTextDark,
      secondaryContainer: const Color(0xFFE8FAFF),
      onSecondaryContainer: kTextDark,
      surface: kSurface,
      onSurface: kTextDark,
      error: const Color(0xFFD62828),
      onError: Colors.white,
    ),
    scaffoldBackgroundColor: kBg,
    appBarTheme: AppBarTheme(
      backgroundColor: kDark,
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
      color: kSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: kDivider),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kAccent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kDivider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kDivider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kAccent, width: 1.5),
      ),
      labelStyle: const TextStyle(color: kTextMid, fontSize: 14),
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14, fontWeight: FontWeight.normal),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: kAccent,
      foregroundColor: Colors.white,
      elevation: 2,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: kSurface,
      indicatorColor: const Color(0xFFD0F4FF),
      surfaceTintColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return const IconThemeData(color: kAccent, size: 22);
        return const IconThemeData(color: Color(0xFFCFD8DC), size: 22);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kAccent, letterSpacing: 0.2);
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
    dividerTheme: const DividerThemeData(color: kDivider, thickness: 1, space: 1),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFFE8FAFF),
      labelStyle: const TextStyle(color: kTextMid, fontSize: 12, fontWeight: FontWeight.w500),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    ),
  );
}
