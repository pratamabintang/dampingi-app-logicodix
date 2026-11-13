import 'package:flutter/material.dart';

class AppProfileAvatar extends StatelessWidget {
  const AppProfileAvatar({
    required this.assetPath,
    required this.size,
    required this.semanticLabel,
    super.key,
  });

  final String assetPath;
  final double size;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: Image.asset(
          assetPath,
          width: size,
          height: size,
          fit: BoxFit.cover,
          semanticLabel: semanticLabel,
        ),
      ),
    );
  }
}
