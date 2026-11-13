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
  const AppBrandHeader({required this.scale, super.key});

  final double Function(double) scale;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: scale(56),
      child: Center(child: AppBrandMark(fontSize: scale(24))),
    );
  }
}
