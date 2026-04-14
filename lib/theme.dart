import 'package:flutter/material.dart';

class AppColors {
  // Backgrounds
  static const bg1 = Color(0xFF1A1B1E); // самый тёмный
  static const bg2 = Color(0xFF232428); // панели
  static const bg3 = Color(0xFF2B2D31); // карточки
  static const bg4 = Color(0xFF383A40); // hover/input

  // Accents
  static const primary = Color(0xFF5865F2);   // Discord purple-blue
  static const primaryLight = Color(0xFF7289DA);
  static const green = Color(0xFF23A559);
  static const red = Color(0xFFED4245);
  static const yellow = Color(0xFFFAA61A);

  // Text
  static const textPrimary = Color(0xFFDBDEE1);
  static const textSecondary = Color(0xFF949BA4);
  static const textMuted = Color(0xFF5C5F66);

  // Message bubble
  static const myBubble = Color(0xFF5865F2);
  static const otherBubble = Color(0xFF2B2D31);
  static const aiBubble = Color(0xFF1E3A2F);
  static const aiAccent = Color(0xFF23A559);
}

ThemeData buildTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bg1,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.primaryLight,
      surface: AppColors.bg2,
      error: AppColors.red,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg2,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: IconThemeData(color: AppColors.textSecondary),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.bg2,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.bg4,
      hintStyle: const TextStyle(color: AppColors.textMuted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        minimumSize: const Size(double.infinity, 48),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    dividerColor: AppColors.bg4,
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: AppColors.textPrimary),
      bodyMedium: TextStyle(color: AppColors.textPrimary),
      bodySmall: TextStyle(color: AppColors.textSecondary),
    ),
  );
}
