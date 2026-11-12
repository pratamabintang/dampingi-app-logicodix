import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_theme.dart';

enum MotherNavigationTab { home, meditation }

class MotherNavigationBar extends StatelessWidget {
  const MotherNavigationBar({
    required this.selectedTab,
    required this.onHomeTap,
    required this.onMeditationTap,
    required this.onLogout,
    super.key,
  });

  final MotherNavigationTab selectedTab;
  final VoidCallback onHomeTap;
  final VoidCallback onMeditationTap;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = (constraints.maxWidth / 390).clamp(0.7, 1.15).toDouble();
        double scaled(double value) => value * scale;

        return Container(
          key: const Key('mother-bottom-navigation'),
          decoration: const BoxDecoration(
            color: Color(0xFFFDFDFD),
            border: Border(top: BorderSide(color: Color(0xFFFAFAFA))),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                scaled(32),
                scaled(selectedTab == MotherNavigationTab.meditation ? 25 : 16),
                scaled(32),
                scaled(selectedTab == MotherNavigationTab.meditation ? 25 : 12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _NavigationItem(
                    label: 'Beranda',
                    asset: 'nav-home.svg',
                    selected: selectedTab == MotherNavigationTab.home,
                    useMeditationAssets:
                        selectedTab == MotherNavigationTab.meditation,
                    onTap: onHomeTap,
                    scale: scale,
                  ),
                  _NavigationItem(
                    label: 'Kalender',
                    asset: 'nav-calendar.svg',
                    useMeditationAssets:
                        selectedTab == MotherNavigationTab.meditation,
                    onTap: () => _showFeatureNotice(context, 'Kalender'),
                    scale: scale,
                  ),
                  _NavigationItem(
                    label: 'Rekomendasi',
                    asset: 'nav-recommendations.svg',
                    useMeditationAssets:
                        selectedTab == MotherNavigationTab.meditation,
                    onTap: () => _showFeatureNotice(context, 'Rekomendasi'),
                    scale: scale,
                  ),
                  _NavigationItem(
                    itemKey: const Key('mother-nav-meditation'),
                    label: 'Meditasi',
                    asset: 'nav-meditation.svg',
                    selected: selectedTab == MotherNavigationTab.meditation,
                    useMeditationAssets:
                        selectedTab == MotherNavigationTab.meditation,
                    onTap: onMeditationTap,
                    scale: scale,
                  ),
                  _NavigationItem(
                    itemKey: const Key('logout'),
                    label: 'Profil',
                    asset: 'nav-profile.svg',
                    useMeditationAssets:
                        selectedTab == MotherNavigationTab.meditation,
                    onTap: onLogout,
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

void _showFeatureNotice(BuildContext context, String feature) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('$feature akan segera tersedia.')));
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.label,
    required this.asset,
    required this.scale,
    required this.useMeditationAssets,
    this.itemKey,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final String asset;
  final double scale;
  final bool useMeditationAssets;
  final Key? itemKey;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    double scaled(double value) => value * scale;
    final assetPath = useMeditationAssets
        ? 'assets/images/meditation/$asset'
        : 'assets/images/mother_home/$asset';

    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: itemKey,
          onTap: onTap,
          borderRadius: BorderRadius.circular(scaled(24)),
          child: Container(
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
            child: useMeditationAssets
                ? SvgPicture.asset(assetPath)
                : SvgPicture.asset(
                    assetPath,
                    width: scaled(24),
                    height: scaled(24),
                  ),
          ),
        ),
      ),
    );
  }
}
