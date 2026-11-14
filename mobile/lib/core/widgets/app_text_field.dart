import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.controller,
    required this.label,
    required this.hintText,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.onFieldSubmitted,
    this.onChanged,
    this.inputHeight,
    this.labelStyle,
    this.textStyle,
    this.hintStyle,
    this.fitLabelToWidth = false,
    this.enabled = true,
    this.autofillHints,
    this.focusNode,
    this.autocorrect = true,
    this.textCapitalization = TextCapitalization.none,
    this.obscureText = false,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;
  final double? inputHeight;
  final TextStyle? labelStyle;
  final TextStyle? textStyle;
  final TextStyle? hintStyle;
  final bool fitLabelToWidth;
  final bool enabled;
  final Iterable<String>? autofillHints;
  final FocusNode? focusNode;
  final bool autocorrect;
  final TextCapitalization textCapitalization;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      this.label,
      maxLines: fitLabelToWidth ? 1 : null,
      softWrap: !fitLabelToWidth,
      style:
          labelStyle ??
          Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: AppTheme.body),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (fitLabelToWidth)
          SizedBox(
            height: (labelStyle?.fontSize ?? 14) * (labelStyle?.height ?? 1),
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: label,
            ),
          )
        else
          label,
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: AppTheme.inputShadow,
          ),
          child: SizedBox(
            height: inputHeight,
            child: TextFormField(
              controller: controller,
              style:
                  textStyle ??
                  AppTypography.bodyDefaultRegular.copyWith(
                    color: AppTheme.white10,
                  ),
              focusNode: focusNode,
              validator: validator,
              obscureText: obscureText,
              keyboardType: keyboardType,
              textInputAction: textInputAction,
              onFieldSubmitted: onFieldSubmitted,
              onChanged: onChanged,
              enabled: enabled,
              autofillHints: autofillHints,
              autocorrect: autocorrect,
              textCapitalization: textCapitalization,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: hintStyle,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
