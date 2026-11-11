import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/controller/auth_controller.dart';

class MotherPage extends ConsumerWidget {
  const MotherPage({this.showWeeklyEpds = false, super.key});

  final bool showWeeklyEpds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userName = ref
        .watch(authControllerProvider)
        .asData
        ?.value
        .session
        ?.user
        .name
        ?.trim();
    final greetingName = userName == null || userName.isEmpty
        ? 'Jane Doe'
        : userName;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scale = (constraints.maxWidth / 390)
                .clamp(0.7, 1.15)
                .toDouble();
            final contentWidth = constraints.maxWidth < 390 * scale
                ? constraints.maxWidth
                : 390 * scale;

            return _HomeScale(
              factor: scale,
              child: Center(
                child: SizedBox(
                  width: contentWidth,
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView(
                          key: PageStorageKey<String>(
                            showWeeklyEpds
                                ? 'mother-home-weekly-scroll'
                                : 'mother-home-daily-scroll',
                          ),
                          padding: EdgeInsets.fromLTRB(
                            context.scaled(24),
                            context.scaled(20),
                            context.scaled(24),
                            context.scaled(24),
                          ),
                          children: [
                            const _HomeHeader(),
                            SizedBox(height: context.scaled(36)),
                            Text(
                              'Selamat Pagi, $greetingName 👋',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppTheme.ink,
                                fontSize: context.scaled(24),
                                fontWeight: FontWeight.w600,
                                height: 32 / 24,
                              ),
                            ),
                            SizedBox(height: context.scaled(36)),
                            if (showWeeklyEpds) ...[
                              const _WeeklyEpdsCard(),
                              SizedBox(height: context.scaled(24)),
                            ],
                            const _MoodCard(),
                            SizedBox(height: context.scaled(24)),
                            const _StoriesCard(),
                            SizedBox(height: context.scaled(24)),
                            _ActivitiesCard(showWeeklyEpds: showWeeklyEpds),
                          ],
                        ),
                      ),
                      _HomeNavigation(
                        onLogout: () {
                          ref.read(authControllerProvider.notifier).logout();
                          context.go('/roles');
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HomeScale extends InheritedWidget {
  const _HomeScale({required this.factor, required super.child});

  final double factor;

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_HomeScale>()?.factor ?? 1;

  @override
  bool updateShouldNotify(_HomeScale oldWidget) => factor != oldWidget.factor;
}

extension on BuildContext {
  double scaled(double value) => value * _HomeScale.of(this);
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        ClipOval(
          child: Image.asset(
            'assets/images/mother_home/avatar-a.png',
            width: context.scaled(56),
            height: context.scaled(56),
            fit: BoxFit.cover,
            semanticLabel: 'Ilustrasi profil',
          ),
        ),
        IconButton(
          key: const Key('mother-notifications'),
          tooltip: 'Notifikasi',
          onPressed: () => _showFeatureNotice(context, 'Notifikasi'),
          padding: EdgeInsets.all(context.scaled(8)),
          constraints: BoxConstraints(
            minWidth: context.scaled(48),
            minHeight: context.scaled(48),
          ),
          icon: SvgPicture.asset(
            'assets/images/mother_home/notification.svg',
            width: context.scaled(24),
            height: context.scaled(24),
          ),
        ),
      ],
    );
  }
}

class _WeeklyEpdsCard extends StatelessWidget {
  const _WeeklyEpdsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('mother-epds-card'),
      padding: EdgeInsets.all(context.scaled(20)),
      decoration: BoxDecoration(
        color: AppTheme.pink2,
        border: Border.all(color: AppTheme.coral),
        borderRadius: BorderRadius.circular(context.scaled(32)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'EPDS mingguan',
                  style: TextStyle(
                    color: AppTheme.coralText,
                    fontSize: context.scaled(14),
                    height: 20 / 14,
                  ),
                ),
                SizedBox(height: context.scaled(8)),
                Text(
                  'Belum diisi',
                  style: TextStyle(
                    color: AppTheme.coralText,
                    fontSize: context.scaled(20),
                    fontWeight: FontWeight.w600,
                    height: 30 / 20,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: context.scaled(24)),
          Expanded(
            child: SizedBox(
              height: context.scaled(48),
              child: FilledButton(
                key: const Key('mother-epds-start'),
                onPressed: () => _showFeatureNotice(context, 'Kuesioner EPDS'),
                style: FilledButton.styleFrom(
                  minimumSize: Size.fromHeight(context.scaled(48)),
                  padding: EdgeInsets.symmetric(horizontal: context.scaled(20)),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(context.scaled(8)),
                  ),
                ),
                child: Text(
                  'Isi Sekarang',
                  maxLines: 1,
                  style: TextStyle(fontSize: context.scaled(14)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoodCard extends StatelessWidget {
  const _MoodCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('mother-mood-card'),
      padding: EdgeInsets.all(context.scaled(20)),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFFAFAFA)),
        borderRadius: BorderRadius.circular(context.scaled(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mood hari ini',
            style: TextStyle(
              color: AppTheme.muted,
              fontSize: context.scaled(16),
              height: 24 / 16,
            ),
          ),
          SizedBox(height: context.scaled(10)),
          Text(
            'Belum dicatat',
            style: TextStyle(
              color: AppTheme.coralText,
              fontSize: context.scaled(20),
              fontWeight: FontWeight.w600,
              height: 30 / 20,
            ),
          ),
          SizedBox(height: context.scaled(16)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _MoodItem(
                faceKey: const Key('mother-mood-face-sen'),
                label: 'Sen',
                color: Color(0xFFB093C4),
                asset: 'mood-very-sad.svg',
                faceHeight: 19.85,
              ),
              _MoodItem(
                faceKey: const Key('mother-mood-face-sel'),
                label: 'Sel',
                color: Color(0xFFA2B1EA),
                asset: 'mood-sad.svg',
                faceHeight: 17.85,
              ),
              _MoodItem(
                faceKey: const Key('mother-mood-face-rab'),
                label: 'Rab',
                color: Color(0xFFDDD6CA),
                asset: 'mood-neutral.svg',
                faceHeight: 10.85,
              ),
              _MoodItem(
                faceKey: const Key('mother-mood-face-kam'),
                label: 'Kam',
                color: Color(0xFFAFEAAB),
                asset: 'mood-very-happy.svg',
                faceHeight: 17.85,
              ),
              _MoodItem(
                faceKey: const Key('mother-mood-face-jum'),
                label: 'Jum',
                color: Color(0xFFFBE567),
                asset: 'mood-happy.svg',
                faceHeight: 23,
              ),
            ],
          ),
          SizedBox(height: context.scaled(16)),
          SizedBox(
            width: double.infinity,
            height: context.scaled(48),
            child: FilledButton(
              key: const Key('mother-record-mood'),
              onPressed: () => _showFeatureNotice(context, 'Pencatatan mood'),
              style: FilledButton.styleFrom(
                minimumSize: Size.fromHeight(context.scaled(48)),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Catat mood hari ini!'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoodItem extends StatelessWidget {
  const _MoodItem({
    required this.faceKey,
    required this.label,
    required this.color,
    required this.asset,
    required this.faceHeight,
  });

  final Key faceKey;
  final String label;
  final Color color;
  final String asset;
  final double faceHeight;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: context.scaled(54),
      child: Column(
        children: [
          _MoodExpression(
            faceKey: faceKey,
            background: color,
            asset: asset,
            faceHeight: faceHeight,
          ),
          Text(
            label,
            style: TextStyle(
              color: AppTheme.muted,
              fontSize: context.scaled(14),
              height: 24 / 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _MoodExpression extends StatelessWidget {
  const _MoodExpression({
    required this.faceKey,
    required this.background,
    required this.asset,
    required this.faceHeight,
  });

  final Key faceKey;
  final Color background;
  final String asset;
  final double faceHeight;

  @override
  Widget build(BuildContext context) {
    final scale = context.scaled(1);
    return SizedBox(
      width: context.scaled(54),
      height: context.scaled(53),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(context.scaled(12)),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            left: context.scaled(8),
            top: context.scaled(18),
          ),
          child: Align(
            alignment: Alignment.topLeft,
            child: SvgPicture.asset(
              key: faceKey,
              'assets/images/mother_home/$asset',
              width: context.scaled(38),
              height: faceHeight * scale,
            ),
          ),
        ),
      ),
    );
  }
}

class _StoriesCard extends StatelessWidget {
  const _StoriesCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('mother-stories-card'),
      padding: EdgeInsets.all(context.scaled(20)),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFFAFAFA)),
        borderRadius: BorderRadius.circular(context.scaled(32)),
      ),
      child: Column(
        children: [
          _SectionHeading(
            title: 'Cerita terakhirmu',
            action: 'Lihat Semua',
            onTap: () => _showFeatureNotice(context, 'Semua cerita'),
          ),
          SizedBox(height: context.scaled(24)),
          _StoryRow(
            tileKey: const Key('mother-story-very-sad'),
            arrowKey: const Key('mother-story-arrow-very-sad'),
            faceKey: const Key('mother-story-face-very-sad'),
            background: Color(0xFFB093C4),
            faceAsset: 'mood-very-sad.svg',
            faceHeight: 19.85,
          ),
          const _SectionDivider(key: Key('mother-story-divider-1')),
          _StoryRow(
            tileKey: const Key('mother-story-very-happy'),
            arrowKey: const Key('mother-story-arrow-very-happy'),
            faceKey: const Key('mother-story-face-very-happy'),
            background: Color(0xFFFBE567),
            faceAsset: 'mood-happy.svg',
            faceHeight: 23,
          ),
          const _SectionDivider(key: Key('mother-story-divider-2')),
          _StoryRow(
            tileKey: const Key('mother-story-happy'),
            arrowKey: const Key('mother-story-arrow-happy'),
            faceKey: const Key('mother-story-face-happy'),
            background: Color(0xFFAFEAAB),
            faceAsset: 'mood-very-happy.svg',
            faceHeight: 17.85,
          ),
        ],
      ),
    );
  }
}

class _StoryRow extends StatelessWidget {
  const _StoryRow({
    required this.tileKey,
    required this.arrowKey,
    required this.faceKey,
    required this.background,
    required this.faceAsset,
    required this.faceHeight,
  });

  final Key tileKey;
  final Key arrowKey;
  final Key faceKey;
  final Color background;
  final String faceAsset;
  final double faceHeight;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          key: tileKey,
          width: context.scaled(83),
          height: context.scaled(83),
          child: Stack(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppTheme.pink2,
                  borderRadius: BorderRadius.circular(context.scaled(32)),
                ),
                child: const SizedBox.expand(),
              ),
              Positioned(
                left: context.scaled(15),
                top: context.scaled(15),
                child: _MoodExpression(
                  faceKey: faceKey,
                  background: background,
                  asset: faceAsset,
                  faceHeight: faceHeight,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: context.scaled(16)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hal Kecil yang berarti',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Color(0xFF252B37),
                  fontSize: context.scaled(14),
                  fontWeight: FontWeight.w600,
                  height: 20 / 14,
                ),
              ),
              SizedBox(height: context.scaled(10)),
              Text(
                'Senang karena ada suami yang',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppTheme.muted,
                  fontSize: context.scaled(14),
                  height: 24 / 14,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: context.scaled(8)),
        SizedBox(
          key: arrowKey,
          width: context.scaled(24).clamp(16, 24).toDouble(),
          height: context.scaled(24).clamp(16, 24).toDouble(),
          child: SvgPicture.asset(
            'assets/images/mother_home/arrow-right.svg',
            width: context.scaled(24).clamp(16, 24).toDouble(),
            height: context.scaled(24).clamp(16, 24).toDouble(),
          ),
        ),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.action,
    required this.onTap,
  });

  final String title;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Color(0xFF252B37),
              fontSize: context.scaled(16),
              fontWeight: FontWeight.w600,
              height: 24 / 16,
            ),
          ),
        ),
        SizedBox(width: context.scaled(8)),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.coralText,
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            action,
            style: TextStyle(
              fontSize: context.scaled(14),
              fontWeight: FontWeight.w600,
              height: 24 / 14,
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          height: context.scaled(11),
          child: Align(
            alignment: Alignment.center,
            child: SizedBox(
              width: constraints.maxWidth,
              height: context.scaled(1),
              child: SvgPicture.asset(
                'assets/images/mother_home/divider.svg',
                width: constraints.maxWidth,
                height: context.scaled(1),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ActivitiesCard extends StatelessWidget {
  const _ActivitiesCard({required this.showWeeklyEpds});

  final bool showWeeklyEpds;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('mother-activities-card'),
      padding: EdgeInsets.all(context.scaled(20)),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFFAFAFA)),
        borderRadius: BorderRadius.circular(context.scaled(32)),
      ),
      child: Column(
        children: [
          _SectionHeading(
            title: 'Saran Aktifitas',
            action: 'Lihat Semua',
            onTap: () => _showFeatureNotice(context, 'Semua aktivitas'),
          ),
          SizedBox(height: context.scaled(24)),
          _ActivityRow(showArrow: showWeeklyEpds),
          const _SectionDivider(),
          _ActivityRow(showArrow: showWeeklyEpds),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.showArrow});

  final bool showArrow;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Meditasi Singkat',
                style: TextStyle(
                  color: Color(0xFF252B37),
                  fontSize: context.scaled(16),
                  fontWeight: FontWeight.w600,
                  height: 24 / 16,
                ),
              ),
              SizedBox(height: context.scaled(10)),
              Text(
                'Jeda tenang - 3 menit',
                style: TextStyle(
                  color: AppTheme.muted,
                  fontSize: context.scaled(16),
                  height: 24 / 16,
                ),
              ),
            ],
          ),
        ),
        if (showArrow)
          SvgPicture.asset(
            'assets/images/mother_home/arrow-right.svg',
            width: context.scaled(24),
            height: context.scaled(24),
          )
        else
          TextButton(
            onPressed: () => _showFeatureNotice(context, 'Meditasi singkat'),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.coralText,
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Lakukan',
              style: TextStyle(
                fontSize: context.scaled(16),
                fontWeight: FontWeight.w600,
                height: 24 / 16,
              ),
            ),
          ),
      ],
    );
  }
}

class _HomeNavigation extends StatelessWidget {
  const _HomeNavigation({required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
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
            context.scaled(32),
            context.scaled(16),
            context.scaled(32),
            context.scaled(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _NavigationItem(
                label: 'Beranda',
                asset: 'nav-home.svg',
                selected: true,
              ),
              _NavigationItem(
                label: 'Kalender',
                asset: 'nav-calendar.svg',
                onTap: () => _showFeatureNotice(context, 'Kalender'),
              ),
              _NavigationItem(
                label: 'Rekomendasi',
                asset: 'nav-recommendations.svg',
                onTap: () => _showFeatureNotice(context, 'Rekomendasi'),
              ),
              _NavigationItem(
                label: 'Meditasi',
                asset: 'nav-meditation.svg',
                onTap: () => _showFeatureNotice(context, 'Meditasi'),
              ),
              _NavigationItem(
                itemKey: const Key('logout'),
                label: 'Profil',
                asset: 'nav-profile.svg',
                onTap: onLogout,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.label,
    required this.asset,
    this.itemKey,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final String asset;
  final Key? itemKey;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: itemKey,
          onTap: onTap,
          borderRadius: BorderRadius.circular(context.scaled(24)),
          child: Container(
            width: context.scaled(56),
            height: context.scaled(56),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppTheme.coral : const Color(0xFFFDFDFD),
              borderRadius: BorderRadius.circular(context.scaled(24)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0D101828),
                  offset: Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
            ),
            child: SvgPicture.asset(
              'assets/images/mother_home/$asset',
              width: context.scaled(24),
              height: context.scaled(24),
            ),
          ),
        ),
      ),
    );
  }
}

void _showFeatureNotice(BuildContext context, String feature) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('$feature akan segera tersedia.')));
}
