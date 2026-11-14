import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppPopupTitle extends StatelessWidget {
  const AppPopupTitle({
    required this.title,
    required this.onClose,
    this.closeKey,
    super.key,
  });

  final String title;
  final VoidCallback onClose;
  final Key? closeKey;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                maxLines: 2,
                textAlign: TextAlign.center,
                style:
                    Theme.of(context).dialogTheme.titleTextStyle ??
                    AppTypography.headingMediumSemibold.copyWith(
                      color: AppTheme.pink6,
                    ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              key: closeKey,
              onPressed: onClose,
              tooltip: 'Tutup',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              icon: const Icon(Icons.close, color: AppTheme.pink6),
            ),
          ),
        ],
      ),
    );
  }
}

class AppPopupActions extends StatelessWidget {
  const AppPopupActions({required this.buttons, super.key});

  final List<Widget> buttons;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < buttons.length; index++) ...[
          if (index > 0) const SizedBox(height: 10),
          buttons[index],
        ],
      ],
    );
  }
}

class AppPopupButton extends StatelessWidget {
  const AppPopupButton({
    required this.label,
    required this.onPressed,
    this.type = AppButtonType.primary,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonType type;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: FilledButton(
        onPressed: onPressed,
        style: AppButtonStyles.forType(type),
        child: Text(label),
      ),
    );
  }
}
