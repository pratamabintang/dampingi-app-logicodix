import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const fontFamily = 'Mona Sans';
  static const coral = Color(0xFFFDA29B);
  static const coralText = Color(0xFFF97066);
  static const coralLight = Color(0xFFFEE4E2);
  static const cream = Color(0xFFFAF4E7);
  static const ink = Color(0xFF0A0D12);
  static const body = Color(0xFF344054);
  static const secondary = Color(0xFF667085);
  static const gray500 = Color(0xFF717680);
  static const gray200 = Color(0xFFE9EAEB);
  static const muted = Color(0xFFA4A7AE);
  static const border = Color(0xFFD0D5DD);
  static const pink2 = Color(0xFFFEF3F2);
  static const selectedSurface = Color(0xFFFFFBFA);
  static const unselectedSurface = Color(0xFFF5F5F5);
  static const inputShadow = [
    BoxShadow(color: Color(0x0D101828), offset: Offset(0, 1), blurRadius: 2),
  ];

  static final light = ThemeData(
    fontFamily: fontFamily,
    colorScheme: ColorScheme.fromSeed(
      seedColor: coral,
      primary: coral,
      onPrimary: Colors.white,
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.white,
    textTheme: TextTheme(
      titleLarge: TextStyle(
        color: ink,
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 32 / 24,
      ),
      titleMedium: TextStyle(
        color: body,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 24 / 16,
      ),
      bodyLarge: TextStyle(color: body, fontSize: 16, height: 24 / 16),
      bodyMedium: TextStyle(color: secondary, fontSize: 14, height: 20 / 14),
      labelLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 24 / 16,
      ),
    ).apply(fontFamily: fontFamily),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      hintStyle: TextStyle(
        fontFamily: fontFamily,
        color: secondary,
        fontSize: 16,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: coral, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFD92D20)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFD92D20), width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: coral,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        elevation: 1,
        shadowColor: const Color(0x0D101828),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: coral,
        textStyle: const TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}
