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
    this.enabled = true,
    this.autofillHints,
    this.focusNode,
    this.autocorrect = true,
    this.textCapitalization = TextCapitalization.none,
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
  final bool enabled;
  final Iterable<String>? autofillHints;
  final FocusNode? focusNode;
  final bool autocorrect;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style:
              labelStyle ??
              Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppTheme.body),
        ),
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
              style: textStyle,
              focusNode: focusNode,
              validator: validator,
              keyboardType: keyboardType,
              textInputAction: textInputAction,
              onFieldSubmitted: onFieldSubmitted,
              onChanged: onChanged,
              enabled: enabled,
              autofillHints: autofillHints,
              autocorrect: autocorrect,
              textCapitalization: textCapitalization,
              decoration: InputDecoration(hintText: hintText),
            ),
          ),
        ),
      ],
    );
  }
}
