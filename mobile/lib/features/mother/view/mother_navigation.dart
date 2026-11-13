import 'package:flutter/material.dart';

import '../../shared/view/app_bottom_navigation_bar.dart';

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
    return AppBottomNavigationBar(
      navigationKey: const Key('mother-bottom-navigation'),
      selectedId: selectedTab.name,
      items: [
        AppNavigationItem(
          id: MotherNavigationTab.home.name,
          label: 'Beranda',
          inactiveAsset: 'home.svg',
          activeAsset: 'home-active.svg',
          onTap: onHomeTap,
          tileKey: const Key('mother-nav-item-home'),
        ),
        AppNavigationItem(
          id: MotherNavigationTab.calendar.name,
          label: calendarLabel,
          inactiveAsset: calendarInactiveAsset,
          activeAsset: calendarActiveAsset,
          onTap: onCalendarTap,
          tileKey: const Key('mother-nav-item-calendar'),
        ),
        AppNavigationItem(
          id: MotherNavigationTab.recommendations.name,
          label: chatLabel,
          inactiveAsset: 'recommendations.svg',
          activeAsset: 'recommendations-active.svg',
          onTap: onChatTap,
          tapKey: const Key('mother-nav-chat'),
          tileKey: const Key('mother-nav-item-recommendations'),
        ),
        AppNavigationItem(
          id: MotherNavigationTab.meditation.name,
          label: meditationLabel,
          inactiveAsset: meditationInactiveAsset,
          activeAsset: meditationActiveAsset,
          onTap: onMeditationTap,
          tapKey: const Key('mother-nav-meditation'),
          tileKey: const Key('mother-nav-item-meditation'),
        ),
        AppNavigationItem(
          id: MotherNavigationTab.profile.name,
          label: 'Profil',
          inactiveAsset: 'profile.svg',
          activeAsset: 'profile-active.svg',
          onTap: onProfileTap,
          tapKey: const Key('mother-nav-profile'),
          tileKey: const Key('mother-nav-item-profile'),
        ),
      ],
    );
  }
}
