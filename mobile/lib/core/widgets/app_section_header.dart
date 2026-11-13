import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
    this.scale = 1,
    super.key,
  }) : assert((actionLabel == null) == (onAction == null));

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xFF252B37),
              fontSize: 16 * scale,
              fontWeight: FontWeight.w600,
              height: 24 / 16,
            ),
          ),
        ),
        if (actionLabel != null) ...[
          SizedBox(width: 8 * scale),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.coralText,
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              actionLabel!,
              style: TextStyle(
                fontSize: 16 * scale,
                fontWeight: FontWeight.w600,
                height: 24 / 16,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
