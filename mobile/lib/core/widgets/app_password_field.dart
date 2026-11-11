import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppPasswordField extends StatefulWidget {
  const AppPasswordField({
    required this.controller,
    required this.label,
    required this.hintText,
    this.validator,
    this.textInputAction,
    this.onFieldSubmitted,
    this.onChanged,
    this.inputHeight,
    this.labelStyle,
    this.textStyle,
    this.showVisibilityToggle = true,
    this.enabled = true,
    this.autofillHints,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;
  final double? inputHeight;
  final TextStyle? labelStyle;
  final TextStyle? textStyle;
  final bool showVisibilityToggle;
  final bool enabled;
  final Iterable<String>? autofillHints;

  @override
  State<AppPasswordField> createState() => _AppPasswordFieldState();
}

class _AppPasswordFieldState extends State<AppPasswordField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style:
              widget.labelStyle ??
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
            height: widget.inputHeight,
            child: TextFormField(
              controller: widget.controller,
              style: widget.textStyle,
              validator: widget.validator,
              obscureText: _obscureText,
              textInputAction: widget.textInputAction,
              onFieldSubmitted: widget.onFieldSubmitted,
              onChanged: widget.onChanged,
              enabled: widget.enabled,
              autofillHints: widget.autofillHints,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                hintText: widget.hintText,
                suffixIcon: widget.showVisibilityToggle
                    ? IconButton(
                        tooltip: _obscureText
                            ? 'Tampilkan kata sandi'
                            : 'Sembunyikan kata sandi',
                        onPressed: widget.enabled
                            ? () => setState(() => _obscureText = !_obscureText)
                            : null,
                        icon: Icon(
                          _obscureText
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
