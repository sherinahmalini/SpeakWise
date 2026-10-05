import 'package:flutter/material.dart';

class AppTheme {
  static const Color darkPrimary = Color(0xFF01411C);
  static const Color lightPrimary = Color(0xFF9AF0BF);

  static const Color darkBackground = Color(0xFF050A07);
  static const Color darkSurface = Color(0xFF0B1510);

  static const Color lightBackground = Color(0xFFF7FBF8);
  static const Color lightSurface = Colors.white;

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,

    scaffoldBackgroundColor: darkBackground,

    primaryColor: darkPrimary,

    colorScheme: const ColorScheme.dark(
      primary: darkPrimary,
      secondary: lightPrimary,
      surface: darkSurface,
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: Colors.white,
    ),

    cardTheme: CardThemeData(
      color: darkSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
    ),

    inputDecorationTheme: const InputDecorationTheme(
      filled: true,

      fillColor: Color(0xFF101B15),

      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide.none,
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide.none,
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: lightPrimary, width: 1.5),
      ),

      labelStyle: TextStyle(color: Colors.white70),

      hintStyle: TextStyle(color: Colors.white54),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: darkPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: lightPrimary),
    ),

    dividerTheme: const DividerThemeData(color: Colors.white12),
  );

  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,

    scaffoldBackgroundColor: lightBackground,

    primaryColor: lightPrimary,

    colorScheme: const ColorScheme.light(
      primary: lightPrimary,
      secondary: darkPrimary,
      surface: lightSurface,
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: Color(0xFF17201A),
    ),

    cardTheme: CardThemeData(
      color: lightSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
    ),

    inputDecorationTheme: const InputDecorationTheme(
      filled: true,

      fillColor: Color(0xFFF0F5F2),

      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide.none,
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide.none,
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: darkPrimary, width: 1.5),
      ),

      labelStyle: TextStyle(color: Colors.black54),

      hintStyle: TextStyle(color: Colors.black45),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: lightPrimary,
        foregroundColor: darkPrimary,
        elevation: 0,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: darkPrimary),
    ),

    dividerTheme: const DividerThemeData(color: Colors.black12),
  );
}
