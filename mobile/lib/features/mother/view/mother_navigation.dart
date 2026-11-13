import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_theme.dart';

enum MotherNavigationTab {
  home,
  calendar,
  recommendations,
  meditation,
  profile,
}

class MotherNavigationBar extends StatelessWidget {
  const MotherNavigationBar({
    required this.selectedTab,
    required this.onHomeTap,
    required this.onCalendarTap,
    required this.onChatTap,
    required this.onMeditationTap,
    required this.onProfileTap,
    this.calendarLabel = 'Kalender',
    this.chatLabel = 'Rekomendasi',
    this.meditationLabel = 'Meditasi',
    this.calendarInactiveAsset = 'calendar.svg',
    this.calendarActiveAsset = 'calendar-active.svg',
    this.meditationInactiveAsset = 'meditation.svg',
    this.meditationActiveAsset = 'meditation-active.svg',
    super.key,
  });

  final MotherNavigationTab selectedTab;
  final VoidCallback onHomeTap;
  final VoidCallback onCalendarTap;
  final VoidCallback onChatTap;
  final VoidCallback onMeditationTap;
  final VoidCallback onProfileTap;
  final String calendarLabel;
  final String chatLabel;
  final String meditationLabel;
  final String calendarInactiveAsset;
  final String calendarActiveAsset;
  final String meditationInactiveAsset;
  final String meditationActiveAsset;

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
                scaled(25),
                scaled(32),
                bottomPadding,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _NavigationItem(
                    tab: MotherNavigationTab.home,
                    label: 'Beranda',
                    inactiveAsset: 'home.svg',
                    activeAsset: 'home-active.svg',
                    selectedTab: selectedTab,
                    onTap: onHomeTap,
                    scale: scale,
                  ),
                  _NavigationItem(
                    tab: MotherNavigationTab.calendar,
                    label: calendarLabel,
                    inactiveAsset: calendarInactiveAsset,
                    activeAsset: calendarActiveAsset,
                    selectedTab: selectedTab,
                    onTap: onCalendarTap,
                    scale: scale,
                  ),
                  _NavigationItem(
                    itemKey: const Key('mother-nav-chat'),
                    tab: MotherNavigationTab.recommendations,
                    label: chatLabel,
                    inactiveAsset: 'recommendations.svg',
                    activeAsset: 'recommendations-active.svg',
                    selectedTab: selectedTab,
                    onTap: onChatTap,
                    scale: scale,
                  ),
                  _NavigationItem(
                    itemKey: const Key('mother-nav-meditation'),
                    tab: MotherNavigationTab.meditation,
                    label: meditationLabel,
                    inactiveAsset: meditationInactiveAsset,
                    activeAsset: meditationActiveAsset,
                    selectedTab: selectedTab,
                    onTap: onMeditationTap,
                    scale: scale,
                  ),
                  _NavigationItem(
                    itemKey: const Key('mother-nav-profile'),
                    tab: MotherNavigationTab.profile,
                    label: 'Profil',
                    inactiveAsset: 'profile.svg',
                    activeAsset: 'profile-active.svg',
                    selectedTab: selectedTab,
                    onTap: onProfileTap,
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

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.tab,
    required this.label,
    required this.inactiveAsset,
    required this.activeAsset,
    required this.selectedTab,
    required this.scale,
    this.itemKey,
    this.onTap,
  });

  final MotherNavigationTab tab;
  final String label;
  final String inactiveAsset;
  final String activeAsset;
  final MotherNavigationTab selectedTab;
  final double scale;
  final Key? itemKey;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    double scaled(double value) => value * scale;
    final selected = selectedTab == tab;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: itemKey,
          onTap: onTap,
          borderRadius: BorderRadius.circular(scaled(24)),
          child: Container(
            key: Key('mother-nav-item-${tab.name}'),
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
              'assets/images/navigation/${selected ? activeAsset : inactiveAsset}',
              width: scaled(24),
              height: scaled(24),
            ),
          ),
        ),
      ),
    );
  }
}
