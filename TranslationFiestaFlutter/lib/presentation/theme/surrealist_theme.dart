import 'package:flutter/material.dart';

class SurrealistTheme {
  // Light Theme
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFEAEAEA),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFD5D5D5),
      elevation: 0,
      titleTextStyle: TextStyle(
        color: Color(0xFF333333),
        fontSize: 20,
        fontWeight: FontWeight.bold,
        fontFamily: 'Playfair Display',
      ),
      iconTheme: IconThemeData(
        color: Color(0xFF333333),
      ),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(
        fontFamily: 'Lato',
        fontSize: 16,
        color: Color(0xFF333333),
      ),
      bodyMedium: TextStyle(
        fontFamily: 'Lato',
        fontSize: 14,
        color: Color(0xFF555555),
      ),
      displayLarge: TextStyle(
        fontFamily: 'Playfair Display',
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: Color(0xFF333333),
      ),
      displayMedium: TextStyle(
        fontFamily: 'Playfair Display',
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Color(0xFF333333),
      ),
      displaySmall: TextStyle(
        fontFamily: 'Playfair Display',
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF333333),
      ),
      headlineMedium: TextStyle(
        fontFamily: 'Playfair Display',
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Color(0xFF333333),
      ),
      headlineSmall: TextStyle(
        fontFamily: 'Playfair Display',
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Color(0xFF333333),
      ),
      titleLarge: TextStyle(
        fontFamily: 'Playfair Display',
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Color(0xFF333333),
      ),
    ),
    buttonTheme: const ButtonThemeData(
      buttonColor: Color(0xFFD9534F),
      textTheme: ButtonTextTheme.primary,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFFD9534F),
    ),
    colorScheme: ColorScheme.fromSwatch().copyWith(
      secondary: const Color(0xFF5BC0DE),
      primary: const Color(0xFFD9534F),
    ),
  );

  // Dark Theme
  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF1E1E1E),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF2D2D2D),
      elevation: 0,
      titleTextStyle: TextStyle(
        color: Color(0xFFE0E0E0),
        fontSize: 20,
        fontWeight: FontWeight.bold,
        fontFamily: 'Playfair Display',
      ),
      iconTheme: IconThemeData(
        color: Color(0xFFE0E0E0),
      ),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(
        fontFamily: 'Lato',
        fontSize: 16,
        color: Color(0xFFE0E0E0),
      ),
      bodyMedium: TextStyle(
        fontFamily: 'Lato',
        fontSize: 14,
        color: Color(0xFFB0B0B0),
      ),
      displayLarge: TextStyle(
        fontFamily: 'Playfair Display',
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: Color(0xFFE0E0E0),
      ),
      displayMedium: TextStyle(
        fontFamily: 'Playfair Display',
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Color(0xFFE0E0E0),
      ),
      displaySmall: TextStyle(
        fontFamily: 'Playfair Display',
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFFE0E0E0),
      ),
      headlineMedium: TextStyle(
        fontFamily: 'Playfair Display',
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Color(0xFFE0E0E0),
      ),
      headlineSmall: TextStyle(
        fontFamily: 'Playfair Display',
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Color(0xFFE0E0E0),
      ),
      titleLarge: TextStyle(
        fontFamily: 'Playfair Display',
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Color(0xFFE0E0E0),
      ),
    ),
    buttonTheme: const ButtonThemeData(
      buttonColor: Color(0xFFBB86FC),
      textTheme: ButtonTextTheme.primary,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFFBB86FC),
    ),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFFBB86FC),
      secondary: Color(0xFF03DAC6),
      surface: Color(0xFF1E1E1E),
      onPrimary: Color(0xFF000000),
      onSecondary: Color(0xFF000000),
      onSurface: Color(0xFFE0E0E0),
    ),
    cardTheme: const CardThemeData(
      color: Color(0xFF2D2D2D),
      elevation: 2,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      fillColor: Color(0xFF2D2D2D),
      filled: true,
      border: OutlineInputBorder(
        borderSide: BorderSide(color: Color(0xFFBB86FC)),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Color(0xFFBB86FC)),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Color(0xFF03DAC6), width: 2),
      ),
      labelStyle: TextStyle(color: Color(0xFFE0E0E0)),
    ),
  );

  // Legacy themeData (for backward compatibility)
  static final ThemeData themeData = lightTheme;
}
