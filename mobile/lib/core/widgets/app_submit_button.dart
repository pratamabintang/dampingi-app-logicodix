import 'package:flutter/material.dart';

class AppSubmitButton extends StatelessWidget {
  const AppSubmitButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.textStyle,
    this.buttonStyle,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final TextStyle? textStyle;
  final ButtonStyle? buttonStyle;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: isLoading ? null : onPressed,
      style:
          (textStyle == null
                  ? null
                  : FilledButton.styleFrom(textStyle: textStyle))
              ?.merge(buttonStyle) ??
          buttonStyle,
      child: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(label),
    );
  }
}
