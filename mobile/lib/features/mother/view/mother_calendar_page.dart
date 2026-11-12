import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/controller/auth_controller.dart';
import 'mother_navigation.dart';

class MotherCalendarPage extends ConsumerStatefulWidget {
  const MotherCalendarPage({super.key});

  @override
  ConsumerState<MotherCalendarPage> createState() => _MotherCalendarPageState();
}

class _MotherCalendarPageState extends ConsumerState<MotherCalendarPage> {
  static final _sampleWeek = DateTime(2026, 8, 1);
  int _weekOffset = 0;
  int? _selectedDay;

  DateTime get _weekStart => _sampleWeek.add(Duration(days: 7 * _weekOffset));

  bool get _isSampleWeek => _weekOffset == 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scale = (constraints.maxWidth / 390)
                .clamp(0.7, 1.15)
                .toDouble();
            final width = constraints.maxWidth < 390 * scale
                ? constraints.maxWidth
                : 390 * scale;

            return _CalendarScale(
              factor: scale,
              child: DefaultTextStyle(
                style: const TextStyle(fontFamily: 'Mona Sans'),
                child: Center(
                  child: SizedBox(
                    width: width,
                    child: Column(
                      children: [
                        Expanded(
                          child: ListView(
                            key: const Key('mother-calendar-scroll'),
                            padding: EdgeInsets.fromLTRB(
                              context.calendarScale(24),
                              context.calendarScale(20),
                              context.calendarScale(24),
                              context.calendarScale(24),
                            ),
                            children: [
                              const _CalendarHeader(),
                              SizedBox(height: context.calendarScale(36)),
                              _WeekSelector(
                                label: _weekLabel(_weekStart),
                                onPrevious: () => _changeWeek(-1),
                                onNext: () => _changeWeek(1),
                              ),
                              SizedBox(height: context.calendarScale(36)),
                              _MoodWeek(
                                selectedDay: _selectedDay,
                                showSampleMoods: _isSampleWeek,
                                onSelectDay: (day) {
                                  setState(() {
                                    _selectedDay = _selectedDay == day
                                        ? null
                                        : day;
                                  });
                                },
                              ),
                              SizedBox(height: context.calendarScale(36)),
                              if (_selectedDay == null && _isSampleWeek) ...[
                                const _EpdsSummaryCard(),
                                SizedBox(height: context.calendarScale(36)),
                              ],
                              _StoriesCard(
                                stories: _storiesForSelection(),
                                showEmptyMessage:
                                    !_isSampleWeek || _selectedDay != null,
                              ),
                            ],
                          ),
                        ),
                        MotherNavigationBar(
                          selectedTab: MotherNavigationTab.calendar,
                          onHomeTap: () => context.go('/mother'),
                          onCalendarTap: () => context.go('/mother/calendar'),
                          onChatTap: () => context.go('/mother/chat'),
                          onMeditationTap: () =>
                              context.go('/mother/meditation'),
                          onLogout: () {
                            ref.read(authControllerProvider.notifier).logout();
                            context.go('/roles');
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _changeWeek(int amount) {
    setState(() {
      _weekOffset += amount;
      _selectedDay = null;
    });
  }

  List<_StoryPreview> _storiesForSelection() {
    if (!_isSampleWeek) return const [];
    if (_selectedDay == null) return _weeklyStories;
    return _selectedDay == 5 ? [_weeklyStories.first] : const [];
  }
}

class _CalendarScale extends InheritedWidget {
  const _CalendarScale({required this.factor, required super.child});

  final double factor;

  @override
  bool updateShouldNotify(_CalendarScale oldWidget) =>
      factor != oldWidget.factor;
}

extension on BuildContext {
  double calendarScale(double value) =>
      (dependOnInheritedWidgetOfExactType<_CalendarScale>()?.factor ?? 1) *
      value;
}

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader();

  @override
  Widget build(BuildContext context) {
    final scale = context.calendarScale;
    return SizedBox(
      height: scale(56),
      child: Center(
        child: Text(
          'Dampingi',
          style: TextStyle(
            color: AppTheme.coral,
            fontSize: scale(24),
            fontWeight: FontWeight.w600,
            height: 32 / 24,
          ),
        ),
      ),
    );
  }
}

class _WeekSelector extends StatelessWidget {
  const _WeekSelector({
    required this.label,
    required this.onPrevious,
    required this.onNext,
  });

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final scale = context.calendarScale;
    return Row(
      children: [
        _WeekButton(
          key: const Key('mother-calendar-previous-week'),
          asset: 'week-arrow-left.svg',
          label: 'Minggu sebelumnya',
          onPressed: onPrevious,
        ),
        Expanded(
          child: Center(
            child: Text(
              label,
              key: const Key('mother-calendar-week-label'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.ink,
                fontSize: scale(20),
                fontWeight: FontWeight.w600,
                height: 30 / 20,
              ),
            ),
          ),
        ),
        _WeekButton(
          key: const Key('mother-calendar-next-week'),
          asset: 'week-arrow-right.svg',
          label: 'Minggu berikutnya',
          onPressed: onNext,
        ),
      ],
    );
  }
}

class _WeekButton extends StatelessWidget {
  const _WeekButton({
    required this.asset,
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String asset;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scale = context.calendarScale;
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        width: scale(48),
        height: scale(48),
        child: Material(
          color: AppTheme.pink2,
          borderRadius: BorderRadius.circular(scale(8)),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(scale(8)),
            child: Center(
              child: SvgPicture.asset(
                'assets/images/mother_calendar/$asset',
                width: scale(20),
                height: scale(20),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MoodWeek extends StatelessWidget {
  const _MoodWeek({
    required this.selectedDay,
    required this.showSampleMoods,
    required this.onSelectDay,
  });

  final int? selectedDay;
  final bool showSampleMoods;
  final ValueChanged<int> onSelectDay;

  @override
  Widget build(BuildContext context) {
    final scale = context.calendarScale;
    return SizedBox(
      height: scale(144),
      child: Row(
        children: [
          for (var index = 0; index < _weekDays.length; index++) ...[
            if (index > 0) SizedBox(width: scale(4)),
            Expanded(
              child: _MoodDay(
                day: _weekDays[index],
                selected: selectedDay == index,
                mood: showSampleMoods ? _weekMoods[index] : null,
                onTap: () => onSelectDay(index),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MoodDay extends StatelessWidget {
  const _MoodDay({
    required this.day,
    required this.mood,
    required this.selected,
    required this.onTap,
  });

  final String day;
  final _MoodPreview? mood;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scale = context.calendarScale;
    final background = mood?.color ?? AppTheme.unselectedSurface;

    return Semantics(
      button: true,
      selected: selected,
      label: '$day, pilih tanggal',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(scale(12)),
          child: Container(
            key: Key('mother-calendar-day-$day'),
            height: scale(144),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(scale(12)),
              border: selected
                  ? Border.all(color: AppTheme.coralText, width: scale(3))
                  : null,
            ),
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                if (mood != null)
                  Positioned(
                    top: scale(13.5),
                    child: _MoodIcon(
                      key: Key('mother-calendar-expression-$day'),
                      mood: mood!,
                    ),
                  ),
                Positioned(
                  bottom: scale(10),
                  child: Text(
                    day,
                    style: TextStyle(
                      color: const Color(0xFF252B37),
                      fontSize: scale(14),
                      fontWeight: FontWeight.w700,
                      height: 20 / 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MoodIcon extends StatelessWidget {
  const _MoodIcon({required this.mood, super.key});

  final _MoodPreview mood;

  @override
  Widget build(BuildContext context) {
    final scale = context.calendarScale;
    if (mood.neutralEyes) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/mother_calendar/neutral-eye-left.png',
            width: scale(14.302),
            height: scale(9.128),
            fit: BoxFit.fill,
          ),
          SizedBox(width: scale(3.36)),
          Image.asset(
            'assets/images/mother_calendar/neutral-eye-right.png',
            width: scale(14.302),
            height: scale(9.128),
            fit: BoxFit.fill,
          ),
        ],
      );
    }

    return Transform.scale(
      scale: scale(1),
      child: SvgPicture.asset('assets/images/mother_calendar/${mood.asset}'),
    );
  }
}

class _EpdsSummaryCard extends StatelessWidget {
  const _EpdsSummaryCard();

  @override
  Widget build(BuildContext context) {
    final scale = context.calendarScale;
    return Container(
      key: const Key('mother-calendar-epds-summary'),
      width: double.infinity,
      padding: EdgeInsets.all(scale(20)),
      decoration: BoxDecoration(
        color: AppTheme.selectedSurface,
        border: Border.all(color: AppTheme.coral),
        borderRadius: BorderRadius.circular(scale(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ringkasan EPDS 1-7 Agu 2026',
            style: TextStyle(
              color: AppTheme.coralText,
              fontSize: scale(14),
              fontWeight: FontWeight.w600,
              height: 20 / 14,
            ),
          ),
          SizedBox(height: scale(10)),
          Text(
            'Senang karena ada suami yang bantu aku untuk ke belakang, kok bisa suami bantu aku ke belakang padahal suami lagi di luar kota.',
            style: TextStyle(
              color: AppTheme.coralText,
              fontSize: scale(14),
              height: 20 / 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _StoriesCard extends StatelessWidget {
  const _StoriesCard({required this.stories, required this.showEmptyMessage});

  final List<_StoryPreview> stories;
  final bool showEmptyMessage;

  @override
  Widget build(BuildContext context) {
    final scale = context.calendarScale;
    return Container(
      key: const Key('mother-calendar-stories'),
      width: double.infinity,
      padding: EdgeInsets.all(scale(20)),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFFAFAFA)),
        borderRadius: BorderRadius.circular(scale(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cerita terakhirmu',
            style: TextStyle(
              color: const Color(0xFF252B37),
              fontSize: scale(16),
              fontWeight: FontWeight.w600,
              height: 24 / 16,
            ),
          ),
          SizedBox(height: scale(24)),
          if (stories.isEmpty && showEmptyMessage)
            Text(
              'Belum ada cerita pada tanggal ini.',
              key: const Key('mother-calendar-empty-stories'),
              style: TextStyle(
                color: AppTheme.muted,
                fontSize: scale(14),
                height: 20 / 14,
              ),
            )
          else
            for (var index = 0; index < stories.length; index++) ...[
              _StoryRow(story: stories[index], index: index),
              if (index < stories.length - 1)
                _StorySeparator(
                  key: Key('mother-calendar-story-separator-$index'),
                  largeGap: index != 2,
                ),
            ],
        ],
      ),
    );
  }
}

class _StoryRow extends StatelessWidget {
  const _StoryRow({required this.story, required this.index});

  final _StoryPreview story;
  final int index;

  @override
  Widget build(BuildContext context) {
    final scale = context.calendarScale;
    final faceHeight = scale(story.faceHeight);
    return Row(
      children: [
        SizedBox(
          key: Key('mother-calendar-story-face-$index'),
          width: scale(83),
          height: scale(83),
          child: Stack(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppTheme.pink2,
                  borderRadius: BorderRadius.circular(scale(32)),
                ),
                child: const SizedBox.expand(),
              ),
              Positioned(
                left: scale(15),
                top: scale(15),
                child: Container(
                  width: scale(54),
                  height: scale(53),
                  decoration: BoxDecoration(
                    color: story.color,
                    borderRadius: BorderRadius.circular(scale(12)),
                  ),
                  alignment: Alignment.center,
                  child: SvgPicture.asset(
                    'assets/images/mother_home/${story.faceAsset}',
                    width: scale(38),
                    height: faceHeight,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: scale(16)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Hal Kecil yang berarti',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFF252B37),
                  fontSize: scale(14),
                  fontWeight: FontWeight.w600,
                  height: 20 / 14,
                ),
              ),
              SizedBox(height: scale(10)),
              Text(
                'Senang karena ada suami yang',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppTheme.muted,
                  fontSize: scale(16),
                  height: 24 / 16,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: scale(16)),
        SvgPicture.asset(
          'assets/images/mother_calendar/story-arrow-right.svg',
          width: scale(24),
          height: scale(24),
        ),
      ],
    );
  }
}

class _StorySeparator extends StatelessWidget {
  const _StorySeparator({required this.largeGap, super.key});

  final bool largeGap;

  @override
  Widget build(BuildContext context) {
    final scale = context.calendarScale;
    return SizedBox(
      height: scale(largeGap ? 20 : 10),
      child: largeGap
          ? Center(
              child: SvgPicture.asset(
                'assets/images/mother_calendar/story-divider.svg',
                width: double.infinity,
                height: scale(1),
              ),
            )
          : null,
    );
  }
}

String _weekLabel(DateTime start) {
  final end = start.add(const Duration(days: 6));
  final startMonth = _indonesianMonth(start.month);
  final endMonth = _indonesianMonth(end.month);
  if (start.month == end.month) {
    return '${start.day}-${end.day} $startMonth ${start.year}';
  }
  if (start.year == end.year) {
    return '${start.day} $startMonth-${end.day} $endMonth ${end.year}';
  }
  return '${start.day} $startMonth ${start.year}-${end.day} $endMonth ${end.year}';
}

String _indonesianMonth(int month) => switch (month) {
  1 => 'Jan',
  2 => 'Feb',
  3 => 'Mar',
  4 => 'Apr',
  5 => 'Mei',
  6 => 'Jun',
  7 => 'Jul',
  8 => 'Agu',
  9 => 'Sep',
  10 => 'Okt',
  11 => 'Nov',
  12 => 'Des',
  _ => throw ArgumentError.value(month, 'month', 'must be between 1 and 12'),
};

const _weekDays = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

const _weekMoods = <_MoodPreview>[
  _MoodPreview(color: Color(0xFFB093C4), asset: 'sen.svg'),
  _MoodPreview(color: Color(0xFFA2B1EA), asset: 'sel.svg'),
  _MoodPreview(color: Color(0xFFF5F5F5), neutralEyes: true),
  _MoodPreview(color: Color(0xFFDDD6CA), asset: 'kam.svg'),
  _MoodPreview(color: Color(0xFFAFEAAB), asset: 'jum.svg'),
  _MoodPreview(color: Color(0xFFAFEAAB), asset: 'sab.svg'),
  _MoodPreview(color: Color(0xFFFBE567), asset: 'min.svg'),
];

const _weeklyStories = <_StoryPreview>[
  _StoryPreview(
    color: Color(0xFFB093C4),
    faceAsset: 'mood-very-sad.svg',
    faceHeight: 19.85,
  ),
  _StoryPreview(
    color: Color(0xFFFBE567),
    faceAsset: 'mood-happy.svg',
    faceHeight: 23,
  ),
  _StoryPreview(
    color: Color(0xFFAFEAAB),
    faceAsset: 'mood-very-happy.svg',
    faceHeight: 17.85,
  ),
  _StoryPreview(
    color: Color(0xFFB093C4),
    faceAsset: 'mood-very-sad.svg',
    faceHeight: 19.85,
  ),
  _StoryPreview(
    color: Color(0xFFFBE567),
    faceAsset: 'mood-happy.svg',
    faceHeight: 23,
  ),
  _StoryPreview(
    color: Color(0xFFAFEAAB),
    faceAsset: 'mood-very-happy.svg',
    faceHeight: 17.85,
  ),
];

class _MoodPreview {
  const _MoodPreview({
    required this.color,
    this.asset,
    this.neutralEyes = false,
  });

  final Color color;
  final String? asset;
  final bool neutralEyes;
}

class _StoryPreview {
  const _StoryPreview({
    required this.color,
    required this.faceAsset,
    required this.faceHeight,
  });

  final Color color;
  final String faceAsset;
  final double faceHeight;
}
