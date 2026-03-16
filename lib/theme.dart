import 'package:flutter/material.dart';

class AppColors {
  static const navyBlue = Color(0xFF0D3B6E);
  static const brightBlue = Color(0xFF1565C0);
  static const greenAccent = Color(0xFF2E7D32);
  static const lightBg = Color(0xFFF4F7FB);
  static const heroBg = Color(0xFFE8F0FA);
  static const cardBorder = Color(0xFFDCE8F5);
  static const inputBorder = Color(0xFFD0DEF0);
  static const grayText = Color(0xFF5A7A9E);
  static const mediumGray = Color(0xFF8BA8C8);
  static const greenBg = Color(0xFFE8F5E9);
  static const tagBg = Color(0xFFE8EEF6);
  static const navBorder = Color(0xFFE2ECF7);
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.lightBg,
    colorScheme: const ColorScheme.light(
      primary: AppColors.navyBlue,
      secondary: AppColors.brightBlue,
      surface: Colors.white,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.navyBlue,
    ),
    fontFamily: 'DMSans',
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontFamily: 'InstrumentSerif',
        fontSize: 28,
        fontWeight: FontWeight.w400,
        color: AppColors.navyBlue,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'InstrumentSerif',
        fontSize: 24,
        fontWeight: FontWeight.w400,
        color: AppColors.navyBlue,
      ),
      headlineSmall: TextStyle(
        fontFamily: 'InstrumentSerif',
        fontSize: 20,
        fontWeight: FontWeight.w400,
        color: AppColors.navyBlue,
      ),
      titleLarge: TextStyle(
        fontFamily: 'DMSans',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.navyBlue,
      ),
      titleMedium: TextStyle(
        fontFamily: 'DMSans',
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.navyBlue,
      ),
      titleSmall: TextStyle(
        fontFamily: 'DMSans',
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.navyBlue,
      ),
      bodyLarge: TextStyle(
        fontFamily: 'DMSans',
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.navyBlue,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'DMSans',
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.navyBlue,
      ),
      bodySmall: TextStyle(
        fontFamily: 'DMSans',
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.grayText,
      ),
      labelLarge: TextStyle(
        fontFamily: 'DMSans',
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.navyBlue,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'DMSans',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.brightBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(
          fontFamily: 'DMSans',
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.brightBlue,
        side: const BorderSide(color: AppColors.cardBorder),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(
          fontFamily: 'DMSans',
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.inputBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.inputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.brightBlue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red),
      ),
      hintStyle: const TextStyle(
        fontFamily: 'DMSans',
        color: AppColors.mediumGray,
        fontSize: 14,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.tagBg,
      labelStyle: const TextStyle(
        fontFamily: 'DMSans',
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.navyBlue,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.cardBorder,
      thickness: 1,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: AppColors.brightBlue,
      unselectedItemColor: AppColors.mediumGray,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: TextStyle(
        fontFamily: 'DMSans',
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: TextStyle(
        fontFamily: 'DMSans',
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),
    ),
  );
}
