import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty.dart';
import '../../../core/widgets/app_error.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/app_section_header.dart';
import '../../../core/widgets/mother_story_list_tile.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/controller/auth_controller.dart';
import '../models/mother_story.dart';
import '../repositories/mother_story_repository.dart';
import 'mother_navigation.dart';

class MotherPage extends ConsumerWidget {
  const MotherPage({this.showWeeklyEpds = false, super.key});

  final bool showWeeklyEpds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storiesAsync = ref.watch(motherStoriesProvider);
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
                            storiesAsync.when(
                              data: (stories) => _StoriesCard(
                                stories: stories.take(3).toList(),
                              ),
                              loading: () =>
                                  const AppLoading(message: 'Memuat cerita...'),
                              error: (error, stackTrace) => const AppError(
                                message: 'Cerita belum dapat dimuat.',
                              ),
                            ),
                            SizedBox(height: context.scaled(24)),
                            _ActivitiesCard(showWeeklyEpds: showWeeklyEpds),
                          ],
                        ),
                      ),
                      MotherNavigationBar(
                        selectedTab: MotherNavigationTab.home,
                        onHomeTap: () => context.go('/mother'),
                        onCalendarTap: () => context.go('/mother/calendar'),
                        onChatTap: () => context.go('/mother/chat'),
                        onMeditationTap: () => context.go('/mother/meditation'),
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
              onPressed: () => showMotherMoodEntry(context),
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
  const _StoriesCard({required this.stories});

  final List<MotherStory> stories;

  @override
  Widget build(BuildContext context) {
    final scale = context.scaled;
    return AppCard(
      key: const Key('mother-stories-card'),
      padding: EdgeInsets.all(scale(20)),
      borderRadius: scale(32),
      child: Column(
        children: [
          AppSectionHeader(
            title: 'Cerita terakhirmu',
            actionLabel: 'Lihat Semua',
            onAction: () => _showFeatureNotice(context, 'Semua cerita'),
            scale: scale(1),
          ),
          SizedBox(height: scale(24)),
          if (stories.isEmpty)
            const AppEmpty(message: 'Belum ada cerita yang tercatat.')
          else
            for (var index = 0; index < stories.length; index++) ...[
              MotherStoryListTile(
                key: Key('mother-story-${stories[index].id}'),
                story: stories[index],
                scale: _HomeScale.of(context),
                keyPrefix: 'mother-story-${stories[index].id}',
                onTap: () => context.push(
                  '/mother/calendar/story',
                  extra: stories[index],
                ),
              ),
              if (index < stories.length - 1)
                _SectionDivider(key: Key('mother-story-divider-${index + 1}')),
            ],
        ],
      ),
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
    return AppSectionHeader(
      title: title,
      actionLabel: action,
      onAction: onTap,
      scale: context.scaled(1),
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
            onTap: () => context.go('/mother/meditation'),
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
            key: const Key('mother-start-meditation'),
            onPressed: () => context.go('/mother/meditation/breathing'),
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

void _showFeatureNotice(BuildContext context, String feature) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('$feature akan segera tersedia.')));
}

Future<void> showMotherMoodEntry(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Catat mood',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (context, animation, secondaryAnimation) =>
        _MoodEntryDialog(onClose: () => Navigator.of(context).pop()),
    transitionBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

class _MoodEntryDialog extends StatefulWidget {
  const _MoodEntryDialog({required this.onClose});

  final VoidCallback onClose;

  @override
  State<_MoodEntryDialog> createState() => _MoodEntryDialogState();
}

class _MoodEntryDialogState extends State<_MoodEntryDialog> {
  final _titleController = TextEditingController();
  final _storyController = TextEditingController();
  final _selectedFeelings = <String>{};
  final _additionalFeelings = <String>[];
  var _selectedLevel = 2;
  var _step = 0;

  @override
  void dispose() {
    _titleController.dispose();
    _storyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final scale = (width / 390).clamp(0.8, 1.05).toDouble();
    final dialogWidth = (width - 48).clamp(0.0, 342 * scale).toDouble();

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
              child: const ColoredBox(color: Color(0x1A000000)),
            ),
          ),
          if (_step != 3)
            Center(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  16,
                  24,
                  16 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: dialogWidth,
                    maxHeight: MediaQuery.sizeOf(context).height - 32,
                  ),
                  child: SingleChildScrollView(
                    child: Container(
                      key: const Key('mother-mood-entry-dialog'),
                      width: dialogWidth,
                      padding: EdgeInsets.all(21 * scale),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32 * scale),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x26000000),
                            blurRadius: 2,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: switch (_step) {
                        0 => _buildLevelPicker(scale),
                        1 => _buildFeelingPicker(scale),
                        2 => _buildNoteForm(scale),
                        _ => const SizedBox.shrink(),
                      },
                    ),
                  ),
                ),
              ),
            ),
          if (_step == 3)
            Positioned.fill(
              child: GestureDetector(
                key: const Key('mother-mood-summary'),
                behavior: HitTestBehavior.opaque,
                onTap: widget.onClose,
                child: Center(
                  child: Transform.translate(
                    offset: Offset(0, -10 * scale),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _moodLevels[_selectedLevel].title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.ink,
                            fontSize: 29.45 * scale,
                            fontWeight: FontWeight.w600,
                            height: 44.18 / 29.45,
                          ),
                        ),
                        SizedBox(height: 15 * scale),
                        _selectedMoodFace(scale, large: true),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLevelPicker(double scale) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dialogCloseButton(scale),
        SizedBox(height: 24 * scale),
        Text(
          'Apa yang anda rasakan sekarang?',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.coralText,
            fontSize: 16 * scale,
            height: 24 / 16,
          ),
        ),
        SizedBox(height: 24 * scale),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var index = 0; index < _moodLevels.length; index++)
              _MoodLevelOption(
                level: _moodLevels[index],
                index: index,
                scale: scale,
                selected: _selectedLevel == index,
                onTap: () => setState(() => _selectedLevel = index),
              ),
          ],
        ),
        SizedBox(height: 24 * scale),
        _MoodLevelSlider(
          value: _selectedLevel,
          scale: scale,
          onChanged: (value) => setState(() => _selectedLevel = value),
        ),
        SizedBox(height: 24 * scale),
        Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Sangat sedih',
                    style: TextStyle(
                      color: AppTheme.muted,
                      fontSize: 14 * scale,
                      height: 24 / 14,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Sangat bahagia',
                    style: TextStyle(
                      color: AppTheme.muted,
                      fontSize: 14 * scale,
                      height: 24 / 14,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 24 * scale),
        _dialogActions(
          scale,
          onContinue: () {
            setState(() {
              _step = 1;
              _selectedFeelings
                ..clear()
                ..add(_moodLevels[_selectedLevel].feelings.first);
              _additionalFeelings.clear();
            });
          },
          showBack: false,
        ),
      ],
    );
  }

  Widget _buildFeelingPicker(double scale) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dialogCloseButton(scale),
        SizedBox(height: 24 * scale),
        Text(
          _moodLevels[_selectedLevel].title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.coralText,
            fontSize: 16 * scale,
            height: 24 / 16,
          ),
        ),
        SizedBox(height: 24 * scale),
        _selectedMoodFace(scale),
        SizedBox(height: 24 * scale),
        SizedBox(
          width: double.infinity,
          child: Text(
            'Apa yang paling menggambarkan perasaanmu?',
            style: TextStyle(
              color: const Color(0xFF252B37),
              fontSize: 14 * scale,
              fontWeight: FontWeight.w600,
              height: 20 / 14,
            ),
          ),
        ),
        SizedBox(height: 24 * scale),
        SizedBox(
          width: double.infinity,
          child: Wrap(
            spacing: 8 * scale,
            runSpacing: 8 * scale,
            children: [
              for (final feeling in [
                ..._moodLevels[_selectedLevel].feelings,
                ..._additionalFeelings,
              ])
                _FeelingChip(
                  label: feeling,
                  selected: _selectedFeelings.contains(feeling),
                  scale: scale,
                  onTap: () {
                    setState(() {
                      if (!_selectedFeelings.add(feeling)) {
                        _selectedFeelings.remove(feeling);
                      }
                    });
                  },
                ),
              SizedBox(
                height: 30 * scale,
                child: TextButton(
                  key: const Key('mother-add-feeling'),
                  onPressed: () {
                    setState(() {
                      if (!_additionalFeelings.contains('Bersyukur')) {
                        _additionalFeelings.add('Bersyukur');
                        _selectedFeelings.add('Bersyukur');
                      }
                    });
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.coralText,
                    padding: EdgeInsets.symmetric(horizontal: 8 * scale),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Tambahkan +',
                    style: TextStyle(fontSize: 14 * scale),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 24 * scale),
        _dialogActions(
          scale,
          onContinue: () => setState(() => _step = 2),
          onBack: () => setState(() => _step = 0),
        ),
      ],
    );
  }

  Widget _buildNoteForm(double scale) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dialogCloseButton(scale),
        SizedBox(height: 24 * scale),
        _selectedMoodFace(scale),
        SizedBox(height: 24 * scale),
        Text(
          'Tulis catatan harian anda',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.coralText,
            fontSize: 16 * scale,
            height: 24 / 16,
          ),
        ),
        SizedBox(height: 24 * scale),
        SizedBox(
          height: 44 * scale,
          child: TextField(
            key: const Key('mother-journal-title'),
            controller: _titleController,
            style: TextStyle(fontSize: 16 * scale),
            decoration: InputDecoration(
              hintText: 'Masukan judul',
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14 * scale,
                vertical: 10 * scale,
              ),
            ),
          ),
        ),
        SizedBox(height: 24 * scale),
        SizedBox(
          height: 183 * scale,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 157 * scale,
                child: TextField(
                  key: const Key('mother-journal-story'),
                  controller: _storyController,
                  expands: true,
                  maxLines: null,
                  minLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  style: TextStyle(fontSize: 16 * scale),
                  decoration: InputDecoration(
                    hintText: 'Ceritakan perasaanmu hari ini',
                    contentPadding: EdgeInsets.all(14 * scale),
                  ),
                ),
              ),
              SizedBox(height: 6 * scale),
              Text(
                '*Opsional',
                style: TextStyle(
                  color: AppTheme.secondary,
                  fontSize: 14 * scale,
                  height: 20 / 14,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 24 * scale),
        _dialogActions(
          scale,
          onContinue: () => setState(() => _step = 3),
          onBack: () => setState(() => _step = 1),
        ),
      ],
    );
  }

  Widget _dialogCloseButton(double scale) {
    return SizedBox(
      height: 24 * scale,
      child: Align(
        alignment: Alignment.centerRight,
        child: IconButton(
          key: const Key('mother-mood-dialog-close'),
          onPressed: widget.onClose,
          padding: EdgeInsets.zero,
          constraints: BoxConstraints.tightFor(
            width: 24 * scale,
            height: 24 * scale,
          ),
          icon: SvgPicture.asset(
            'assets/images/mother_home/close.svg',
            width: 24 * scale,
            height: 24 * scale,
          ),
        ),
      ),
    );
  }

  Widget _selectedMoodFace(double scale, {bool large = false}) {
    final mood = _moodLevels[_selectedLevel];
    final dimension = large ? 100.0 : 54.0;
    final expression = SvgPicture.asset(
      'assets/images/mother_home/${mood.asset}',
      key: large ? const Key('mother-mood-summary-expression') : null,
      width: (large ? 70.3 : 38) * scale,
      height: (large ? 42.5 : mood.faceHeight) * scale,
    );
    return SizedBox(
      key: Key(
        large ? 'mother-mood-summary-face' : 'mother-mood-selected-face',
      ),
      width: dimension * scale,
      height: (large ? 98.0 : 53.0) * scale,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: mood.color,
          borderRadius: BorderRadius.circular((large ? 22.2 : 12) * scale),
        ),
        child: large
            ? Center(child: expression)
            : Padding(
                padding: EdgeInsets.only(left: 8 * scale, top: 18 * scale),
                child: Align(alignment: Alignment.topLeft, child: expression),
              ),
      ),
    );
  }

  Widget _dialogActions(
    double scale, {
    required VoidCallback onContinue,
    VoidCallback? onBack,
    bool showBack = true,
  }) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48 * scale,
          child: FilledButton(
            key: const Key('mother-mood-dialog-continue'),
            onPressed: onContinue,
            style: FilledButton.styleFrom(
              minimumSize: Size.fromHeight(48 * scale),
              backgroundColor: AppTheme.coral,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8 * scale),
              ),
            ),
            child: Text('Lanjut', style: TextStyle(fontSize: 16 * scale)),
          ),
        ),
        if (showBack) ...[
          SizedBox(height: 10 * scale),
          SizedBox(
            width: double.infinity,
            height: 48 * scale,
            child: FilledButton(
              key: const Key('mother-mood-dialog-back'),
              onPressed: onBack ?? widget.onClose,
              style: FilledButton.styleFrom(
                minimumSize: Size.fromHeight(48 * scale),
                backgroundColor: AppTheme.coralLight,
                foregroundColor: AppTheme.coralText,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8 * scale),
                ),
              ),
              child: Text('Kembali', style: TextStyle(fontSize: 16 * scale)),
            ),
          ),
        ],
      ],
    );
  }
}

const _moodLevels = <_MoodLevel>[
  _MoodLevel(
    title: 'Sangat Sedih',
    asset: 'mood-very-sad.svg',
    color: Color(0xFFB093C4),
    faceHeight: 19.85,
    feelings: ['Kesepian', 'Kecewa', 'Lelah', 'Cemas'],
  ),
  _MoodLevel(
    title: 'Sedih',
    asset: 'mood-sad.svg',
    color: Color(0xFFA2B1EA),
    faceHeight: 17.85,
    feelings: ['Sedih', 'Cemas', 'Lelah', 'Bingung'],
  ),
  _MoodLevel(
    title: 'Biasa Saja',
    asset: 'mood-neutral.svg',
    color: Color(0xFFDDD6CA),
    faceHeight: 10.85,
    feelings: ['Tenang', 'Biasa saja', 'Lega', 'Bersyukur'],
  ),
  _MoodLevel(
    title: 'Senang',
    asset: 'mood-very-happy.svg',
    color: Color(0xFFAFEAAB),
    faceHeight: 17.85,
    feelings: ['Senang', 'Bersyukur', 'Tenang', 'Bersemangat'],
  ),
  _MoodLevel(
    title: 'Sangat Bahagia',
    asset: 'mood-happy.svg',
    color: Color(0xFFFBE567),
    faceHeight: 23,
    feelings: ['Bersemangat', 'Terkejoed', 'Lega', 'Bangga'],
  ),
];

class _MoodLevel {
  const _MoodLevel({
    required this.title,
    required this.asset,
    required this.color,
    required this.faceHeight,
    required this.feelings,
  });

  final String title;
  final String asset;
  final Color color;
  final double faceHeight;
  final List<String> feelings;
}

class _MoodLevelOption extends StatelessWidget {
  const _MoodLevelOption({
    required this.level,
    required this.index,
    required this.scale,
    required this.selected,
    required this.onTap,
  });

  final _MoodLevel level;
  final int index;
  final double scale;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: level.title,
      child: GestureDetector(
        key: Key('mother-mood-level-$index'),
        onTap: onTap,
        child: SizedBox(
          width: 54 * scale,
          height: 53 * scale,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: level.color,
              borderRadius: BorderRadius.circular(12 * scale),
            ),
            child: Padding(
              padding: EdgeInsets.only(left: 8 * scale, top: 18 * scale),
              child: Align(
                alignment: Alignment.topLeft,
                child: SvgPicture.asset(
                  'assets/images/mother_home/${level.asset}',
                  width: 38 * scale,
                  height: level.faceHeight * scale,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MoodLevelSlider extends StatelessWidget {
  const _MoodLevelSlider({
    required this.value,
    required this.scale,
    required this.onChanged,
  });

  final int value;
  final double scale;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 17 * scale,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final thumbDiameter = 17 * scale;
          final maxOffset = constraints.maxWidth - thumbDiameter;
          final thumbOffset = maxOffset * value / 4;
          return GestureDetector(
            key: const Key('mother-mood-level-slider'),
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) =>
                _updateValue(details.localPosition.dx, constraints.maxWidth),
            onHorizontalDragUpdate: (details) =>
                _updateValue(details.localPosition.dx, constraints.maxWidth),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: 15 * scale,
                  decoration: BoxDecoration(
                    color: AppTheme.gray200,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                Positioned(
                  left: 0,
                  child: Container(
                    width: thumbOffset + thumbDiameter / 2,
                    height: 15 * scale,
                    decoration: BoxDecoration(
                      color: AppTheme.coralLight,
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),
                Positioned(
                  left: thumbOffset,
                  child: Container(
                    width: thumbDiameter,
                    height: thumbDiameter,
                    decoration: const BoxDecoration(
                      color: AppTheme.coralText,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _updateValue(double x, double width) {
    if (width <= 0) return;
    final ratio = (x / width).clamp(0.0, 1.0);
    onChanged((ratio * 4).round());
  }
}

class _FeelingChip extends StatelessWidget {
  const _FeelingChip({
    required this.label,
    required this.selected,
    required this.scale,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppTheme.coralText : AppTheme.muted;
    return SizedBox(
      height: 30 * scale,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color),
          padding: EdgeInsets.symmetric(horizontal: 9 * scale),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: const StadiumBorder(),
        ),
        child: Text(label, style: TextStyle(fontSize: 14 * scale)),
      ),
    );
  }
}
