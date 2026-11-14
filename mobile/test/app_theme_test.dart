import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';

void main() {
  test('theme applies the Dampingi color tokens to shared components', () {
    final theme = AppTheme.light;

    expect(AppTheme.pink6, const Color(0xFFF97066));
    expect(AppTheme.white3, const Color(0xFFF5F5F5));
    expect(theme.colorScheme.primary, AppTheme.pink6);
    expect(theme.scaffoldBackgroundColor, AppTheme.white1);
    expect(theme.textTheme.bodyLarge?.color, AppTheme.white10);
    expect(theme.textTheme.bodyMedium?.color, AppTheme.white7);
    expect(
      theme.inputDecorationTheme.enabledBorder?.borderSide.color,
      AppTheme.white3,
    );
    expect(
      theme.filledButtonTheme.style?.backgroundColor?.resolve({}),
      AppTheme.pink6,
    );
  });
}
