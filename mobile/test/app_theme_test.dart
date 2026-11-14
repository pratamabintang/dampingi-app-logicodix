import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';

void main() {
  test('theme applies the Dampingi color tokens to shared components', () {
    final theme = AppTheme.light;

    expect(AppTheme.pink6, const Color(0xFFF97066));
    expect(AppTheme.pink4, const Color(0xFFFECDCA));
    expect(AppTheme.pink5, const Color(0xFFFDA29B));
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
    expect(
      AppButtonStyles.primary.backgroundColor?.resolve({}),
      AppButtonStyles.tombolPrimerNormal.background,
    );
    expect(
      AppButtonStyles.primary.foregroundColor?.resolve({}),
      AppButtonStyles.tombolPrimerNormal.foreground,
    );
    expect(
      AppButtonStyles.primary.backgroundColor?.resolve({WidgetState.disabled}),
      AppButtonStyles.tombolPrimerDisable.background,
    );
    expect(
      AppButtonStyles.primary.foregroundColor?.resolve({WidgetState.disabled}),
      AppButtonStyles.tombolPrimerDisable.foreground,
    );
    expect(
      AppButtonStyles.secondary.backgroundColor?.resolve({}),
      AppButtonStyles.tombolSekunderNormal.background,
    );
    expect(
      AppButtonStyles.secondary.foregroundColor?.resolve({}),
      AppButtonStyles.tombolSekunderNormal.foreground,
    );
    expect(
      AppButtonStyles.secondary.backgroundColor?.resolve({
        WidgetState.disabled,
      }),
      AppButtonStyles.tombolSekunderDisable.background,
    );
    expect(
      AppButtonStyles.secondary.foregroundColor?.resolve({
        WidgetState.disabled,
      }),
      AppButtonStyles.tombolSekunderDisable.foreground,
    );
  });
}
