import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_theme.dart';

class AppNavigationItem {
  const AppNavigationItem({
    required this.id,
    required this.label,
    required this.inactiveAsset,
    required this.activeAsset,
    this.onTap,
    this.tapKey,
    this.tileKey,
  });

  final String id;
  final String label;
  final String inactiveAsset;
  final String activeAsset;
  final VoidCallback? onTap;
  final Key? tapKey;
  final Key? tileKey;
}

class AppBottomNavigationBar extends StatelessWidget {
  const AppBottomNavigationBar({
    required this.items,
    required this.selectedId,
    required this.navigationKey,
    super.key,
  });

  final List<AppNavigationItem> items;
  final String selectedId;
  final Key navigationKey;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = (constraints.maxWidth / 390).clamp(0.7, 1.15).toDouble();
        double scaled(double value) => value * scale;
        final bottomPadding =
            (scaled(25) - MediaQuery.viewPaddingOf(context).bottom)
                .clamp(0.0, scaled(25))
                .toDouble();

        return Container(
          key: navigationKey,
          decoration: const BoxDecoration(
            color: Color(0xFFFDFDFD),
            border: Border(top: BorderSide(color: Color(0xFFFAFAFA))),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                scaled(32),
                scaled(25),
                scaled(32),
                bottomPadding,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final item in items)
                    _AppNavigationItem(
                      item: item,
                      selected: item.id == selectedId,
                      scale: scale,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AppNavigationItem extends StatelessWidget {
  const _AppNavigationItem({
    required this.item,
    required this.selected,
    required this.scale,
  });

  final AppNavigationItem item;
  final bool selected;
  final double scale;

  @override
  Widget build(BuildContext context) {
    double scaled(double value) => value * scale;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: item.tapKey,
          onTap: item.onTap,
          borderRadius: BorderRadius.circular(scaled(24)),
          child: Container(
            key: item.tileKey,
            width: scaled(56),
            height: scaled(56),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppTheme.coral : const Color(0xFFFDFDFD),
              borderRadius: BorderRadius.circular(scaled(24)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0D101828),
                  offset: Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
            ),
            child: SvgPicture.asset(
              'assets/images/navigation/${selected ? item.activeAsset : item.inactiveAsset}',
              width: scaled(24),
              height: scaled(24),
            ),
          ),
        ),
      ),
    );
  }
}
