import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const fontFamily = 'Mona Sans';
  static const pink1 = Color(0xFFFFFAFA);
  static const pink2 = Color(0xFFFEF3F2);
  static const pink3 = Color(0xFFFEE4E2);
  static const pink4 = Color(0xFFFECDCA);
  static const pink5 = Color(0xFFFDA29B);
  static const pink6 = Color(0xFFF97066);
  static const white1 = Color(0xFFFDFDFD);
  static const white2 = Color(0xFFFAFAFA);
  static const white3 = Color(0xFFF5F5F5);
  static const white6 = Color(0xFFA4A7AE);
  static const white7 = Color(0xFF717680);
  static const white10 = Color(0xFF252B37);
  static const white12 = Color(0xFF0A0D12);

  static const coral = pink6;
  static const coralText = pink6;
  static const coralLight = pink3;
  static const cream = Color(0xFFFAF4E7);
  static const ink = white12;
  static const body = white10;
  static const secondary = white7;
  static const gray500 = white7;
  static const gray200 = white3;
  static const muted = white6;
  static const border = white3;
  static const selectedSurface = pink1;
  static const unselectedSurface = white3;
  static const inputShadow = [
    BoxShadow(color: Color(0x0D101828), offset: Offset(0, 1), blurRadius: 2),
  ];

  static final light = ThemeData(
    fontFamily: fontFamily,
    colorScheme: ColorScheme.fromSeed(
      seedColor: pink6,
      primary: pink6,
      onPrimary: white1,
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: white1,
    textTheme: TextTheme(
      titleLarge: AppTypography.headingLargeSemibold.copyWith(color: ink),
      titleMedium: AppTypography.headingMediumSemibold.copyWith(color: ink),
      titleSmall: AppTypography.headingSmallSemibold.copyWith(color: ink),
      bodyLarge: AppTypography.bodyDefaultRegular.copyWith(color: body),
      bodyMedium: AppTypography.bodyDefaultRegular.copyWith(color: body),
      bodySmall: AppTypography.bodySmallRegular.copyWith(color: secondary),
      labelLarge: AppTypography.labelStrongSemibold.copyWith(color: ink),
      labelMedium: AppTypography.labelSmallMedium.copyWith(color: body),
      labelSmall: AppTypography.captionRegular.copyWith(color: secondary),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: white1,
      hintStyle: AppTypography.bodyDefaultRegular.copyWith(color: secondary),
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
        borderSide: const BorderSide(color: pink6, width: 1.5),
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
    dialogTheme: DialogThemeData(
      backgroundColor: white1,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      titleTextStyle: AppTypography.headingMediumSemibold.copyWith(
        color: pink6,
      ),
      contentTextStyle: AppTypography.bodyDefaultRegular.copyWith(
        color: white10,
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
    ),
    filledButtonTheme: FilledButtonThemeData(style: AppButtonStyles.primary),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: pink6,
        disabledForegroundColor: white6,
        textStyle: AppTypography.labelStrongSemibold,
      ),
    ),
  );
}

abstract final class AppTypography {
  static const headingLargeSemibold = TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 32 / 24,
  );
  static const headingMediumSemibold = TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 30 / 20,
  );
  static const headingSmallSemibold = TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 28 / 18,
  );
  static const bodyDefaultRegular = TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 24 / 16,
  );
  static const labelStrongSemibold = TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 24 / 16,
  );
  static const bodySmallRegular = TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 20 / 14,
  );
  static const labelSmallMedium = TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 20 / 14,
  );
  static const captionRegular = TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 18 / 12,
  );
  static const captionMedium = TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 18 / 12,
  );
  static const labelStrongBold = TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 24 / 16,
  );
}

enum AppButtonType { primary, secondary }

class AppButtonColors {
  const AppButtonColors({required this.background, required this.foreground});

  final Color background;
  final Color foreground;
}

abstract final class AppButtonStyles {
  static const tombolPrimerNormal = AppButtonColors(
    background: AppTheme.pink6,
    foreground: Colors.white,
  );
  static const tombolPrimerDisable = AppButtonColors(
    background: AppTheme.pink4,
    foreground: AppTheme.pink3,
  );
  static const tombolSekunderNormal = AppButtonColors(
    background: AppTheme.pink3,
    foreground: AppTheme.pink6,
  );
  static const tombolSekunderDisable = AppButtonColors(
    background: AppTheme.pink3,
    foreground: AppTheme.pink5,
  );

  static final primary = _style(tombolPrimerNormal, tombolPrimerDisable);
  static final secondary = _style(tombolSekunderNormal, tombolSekunderDisable);
  static final secondaryText = TextButton.styleFrom(
    backgroundColor: tombolSekunderNormal.background,
    foregroundColor: tombolSekunderNormal.foreground,
    disabledBackgroundColor: tombolSekunderDisable.background,
    disabledForegroundColor: tombolSekunderDisable.foreground,
  );
  static final secondaryIcon = IconButton.styleFrom(
    backgroundColor: tombolSekunderNormal.background,
    foregroundColor: tombolSekunderNormal.foreground,
    disabledBackgroundColor: tombolSekunderDisable.background,
    disabledForegroundColor: tombolSekunderDisable.foreground,
  );

  static ButtonStyle forType(AppButtonType type) => switch (type) {
    AppButtonType.primary => primary,
    AppButtonType.secondary => secondary,
  };

  static Color disabledForeground(AppButtonType type) => switch (type) {
    AppButtonType.primary => tombolPrimerDisable.foreground,
    AppButtonType.secondary => tombolSekunderDisable.foreground,
  };

  static ButtonStyle _style(AppButtonColors normal, AppButtonColors disabled) {
    return FilledButton.styleFrom(
      backgroundColor: normal.background,
      foregroundColor: normal.foreground,
      disabledBackgroundColor: disabled.background,
      disabledForegroundColor: disabled.foreground,
      minimumSize: const Size.fromHeight(48),
      elevation: 1,
      shadowColor: const Color(0x0D101828),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      textStyle: AppTypography.labelStrongSemibold,
    );
  }
}
