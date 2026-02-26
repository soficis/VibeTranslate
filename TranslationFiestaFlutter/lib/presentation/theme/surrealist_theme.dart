import 'package:flutter/material.dart';

/// Unified TranslationFiesta theme — dark-first, clean, professional.
class SurrealistTheme {
  // Unified color constants
  static const _background = Color(0xFF0F1419);
  static const _surface = Color(0xFF1A1F2E);
  static const _surfaceElevated = Color(0xFF242A38);
  static const _border = Color(0xFF2E3648);
  static const _textPrimary = Color(0xFFE8ECF1);
  static const _textSecondary = Color(0xFF8B95A5);
  static const _accent = Color(0xFF3B82F6);
  static const _accentHover = Color(0xFF2563EB);
  static const statusAmber = Color(0xFFF59E0B);
  static const statusGreen = Color(0xFF10B981);
  static const statusRed = Color(0xFFEF4444);

  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF0F2F5),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFFFFFFF),
      elevation: 0,
      titleTextStyle: TextStyle(
        color: Color(0xFF1A1F2E),
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: IconThemeData(color: Color(0xFF1A1F2E)),
    ),
    colorScheme: const ColorScheme.light(
      primary: _accent,
      secondary: _accentHover,
      surface: Color(0xFFFFFFFF),
      onPrimary: Color(0xFFFFFFFF),
      onSecondary: Color(0xFFFFFFFF),
      onSurface: Color(0xFF1A1F2E),
    ),
    cardTheme: const CardThemeData(
      color: Color(0xFFFFFFFF),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      fillColor: const Color(0xFFF5F6F8),
      filled: true,
      border: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFFDDE1E6)),
        borderRadius: BorderRadius.circular(8),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFFDDE1E6)),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: _accent, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      labelStyle: const TextStyle(color: Color(0xFF6B7280)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: _background,
    appBarTheme: const AppBarTheme(
      backgroundColor: _surface,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: _textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: IconThemeData(color: _textPrimary),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(fontSize: 14, color: _textPrimary),
      bodyMedium: TextStyle(fontSize: 13, color: _textSecondary),
      displayLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: _textPrimary,
      ),
      displayMedium: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: _textPrimary,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: _textPrimary,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: _textSecondary,
      ),
    ),
    colorScheme: const ColorScheme.dark(
      primary: _accent,
      secondary: _accentHover,
      surface: _surface,
      onPrimary: Color(0xFFFFFFFF),
      onSecondary: Color(0xFFFFFFFF),
      onSurface: _textPrimary,
    ),
    cardTheme: const CardThemeData(
      color: _surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: _border),
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      fillColor: _surfaceElevated,
      filled: true,
      border: OutlineInputBorder(
        borderSide: const BorderSide(color: _border),
        borderRadius: BorderRadius.circular(8),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: _border),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: _accent, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      labelStyle: const TextStyle(color: _textSecondary),
      hintStyle: const TextStyle(color: _textSecondary),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    ),
    dividerColor: _border,
  );

  // Legacy alias
  static final ThemeData themeData = darkTheme;
}
