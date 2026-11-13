import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppBrandMark extends StatelessWidget {
  const AppBrandMark({super.key, this.fontSize = 24});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Dampingi',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: AppTheme.fontFamily,
        color: AppTheme.coral,
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        height: 32 / 24,
        letterSpacing: 0,
      ),
    );
  }
}

class AppBrandHeader extends StatelessWidget {
  const AppBrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: const Center(child: AppBrandMark()),
    );
  }
}
