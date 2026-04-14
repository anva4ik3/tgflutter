import 'package:flutter/material.dart';

class AppColors {
  // Backgrounds — глубокий тёмный как у Telegram
  static const bg1 = Color(0xFF0E1621);   // самый тёмный фон
  static const bg2 = Color(0xFF17212B);   // панели / appbar
  static const bg3 = Color(0xFF1F2E3D);   // карточки
  static const bg4 = Color(0xFF2B3F55);   // input / hover

  // Акцент — Telegram-blue но чуть ярче и современнее
  static const primary = Color(0xFF2CA5E0);
  static const primaryDark = Color(0xFF1A85BF);
  static const primaryLight = Color(0xFF54C3F1);
  static const primaryGlow = Color(0x302CA5E0);

  // Дополнительные цвета
  static const green = Color(0xFF4CD964);
  static const red = Color(0xFFFF3B30);
  static const yellow = Color(0xFFFFCC00);
  static const purple = Color(0xFFAF52DE);
  static const orange = Color(0xFFFF9500);

  // Текст
  static const textPrimary = Color(0xFFE8F1F8);
  static const textSecondary = Color(0xFF8B9CB6);
  static const textMuted = Color(0xFF4A5568);

  // Пузыри сообщений
  static const myBubble = Color(0xFF2CA5E0);
  static const myBubbleDark = Color(0xFF1E8DC4);
  static const otherBubble = Color(0xFF1F2E3D);
  static const aiBubble = Color(0xFF0D2137);
  static const aiAccent = Color(0xFF4CD964);

  // Онлайн статус
  static const online = Color(0xFF4CD964);
  static const offline = Color(0xFF4A5568);
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
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
      iconTheme: IconThemeData(color: AppColors.textSecondary),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.bg2,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontSize: 11),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.bg4,
      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        minimumSize: const Size(double.infinity, 52),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.3),
        elevation: 0,
      ),
    ),
    dividerColor: AppColors.bg3,
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: AppColors.textPrimary, fontSize: 15),
      bodyMedium: TextStyle(color: AppColors.textPrimary, fontSize: 14),
      bodySmall: TextStyle(color: AppColors.textSecondary, fontSize: 12),
    ),
  );
}

// Утилиты для UI
class AppGradients {
  static const primary = LinearGradient(
    colors: [AppColors.primary, AppColors.primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const dark = LinearGradient(
    colors: [AppColors.bg1, AppColors.bg2],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
