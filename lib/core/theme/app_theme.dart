import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFF0A0A0F);
  static const gold = Color(0xFFD4AF37);
  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xFF9A9AA5);
  static Color glass = Colors.white.withOpacity(0.08);
  static Color glassBorder = Colors.white.withOpacity(0.12);
}

class AppTheme {
  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.gold,
        secondary: AppColors.gold,
        surface: AppColors.background,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
            fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white),
        bodyLarge: TextStyle(fontSize: 16, color: Colors.white),
        bodyMedium: TextStyle(fontSize: 16, color: Colors.white),
        bodySmall: TextStyle(fontSize: 13, color: AppColors.textSecondary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.gold, width: 1.2),
        ),
      ),
    );
  }
}
