import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppSubmitButton extends StatelessWidget {
  const AppSubmitButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.textStyle,
    this.buttonStyle,
    this.type = AppButtonType.primary,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final TextStyle? textStyle;
  final ButtonStyle? buttonStyle;
  final AppButtonType type;

  @override
  Widget build(BuildContext context) {
    final style = AppButtonStyles.forType(type);
    final resolvedStyle = style
        .merge(
          textStyle == null
              ? buttonStyle
              : FilledButton.styleFrom(
                  textStyle: textStyle!.copyWith(color: null),
                ).merge(buttonStyle),
        )
        .copyWith(
          backgroundColor: style.backgroundColor,
          foregroundColor: style.foregroundColor,
        );

    return FilledButton(
      onPressed: isLoading ? null : onPressed,
      style: resolvedStyle,
      child: isLoading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppButtonStyles.disabledForeground(type),
              ),
            )
          : Text(label),
    );
  }
}
