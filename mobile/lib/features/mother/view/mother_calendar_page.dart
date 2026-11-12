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
    final storiesAsync = ref.watch(motherStoriesProvider);
    final loadedStories = storiesAsync.asData?.value;
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
                                stories: loadedStories == null
                                    ? const []
                                    : _storiesForSelection(loadedStories),
                                showEmptyMessage:
                                    !_isSampleWeek || _selectedDay != null,
                                isLoading: storiesAsync.isLoading,
                                hasError: storiesAsync.hasError,
                                onStoryTap: (story) => context.push(
                                  '/mother/calendar/story',
                                  extra: story,
                                ),
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

  List<MotherStory> _storiesForSelection(List<MotherStory> stories) {
    if (!_isSampleWeek) return const [];
    if (_selectedDay == null) return stories;
    return stories
        .where((story) => story.weekdayIndex == _selectedDay)
        .toList(growable: false);
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
                    top: scale(mood!.top),
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
  const _StoriesCard({
    required this.stories,
    required this.showEmptyMessage,
    required this.isLoading,
    required this.hasError,
    required this.onStoryTap,
  });

  final List<MotherStory> stories;
  final bool showEmptyMessage;
  final bool isLoading;
  final bool hasError;
  final ValueChanged<MotherStory> onStoryTap;

  @override
  Widget build(BuildContext context) {
    final scale = context.calendarScale;
    return AppCard(
      key: const Key('mother-calendar-stories'),
      padding: EdgeInsets.all(scale(20)),
      borderRadius: scale(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(title: 'Cerita terakhirmu', scale: scale(1)),
          SizedBox(height: scale(24)),
          if (isLoading)
            SizedBox(
              height: scale(100),
              child: const AppLoading(message: 'Memuat cerita...'),
            )
          else if (hasError)
            const AppError(message: 'Cerita belum dapat dimuat.')
          else if (stories.isEmpty && showEmptyMessage)
            Text(
              'Belum ada cerita pada tanggal ini.',
              key: const Key('mother-calendar-empty-stories'),
              style: TextStyle(
                color: AppTheme.muted,
                fontSize: scale(14),
                height: 20 / 14,
              ),
            )
          else if (stories.isEmpty)
            const AppEmpty(message: 'Belum ada cerita yang tercatat.')
          else
            for (var index = 0; index < stories.length; index++) ...[
              MotherStoryListTile(
                story: stories[index],
                scale: scale(1),
                keyPrefix: 'mother-calendar-story-$index',
                arrowAsset:
                    'assets/images/mother_calendar/story-arrow-right.svg',
                snippetFontSize: 16,
                centerFace: true,
                onTap: () => onStoryTap(stories[index]),
              ),
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
  _MoodPreview(color: Color(0xFFB093C4), asset: 'sen.svg', top: 15.14),
  _MoodPreview(color: Color(0xFFA2B1EA), asset: 'sel.svg', top: 15.14),
  _MoodPreview(color: Color(0xFFF5F5F5), neutralEyes: true, top: 13.46),
  _MoodPreview(color: Color(0xFFDDD6CA), asset: 'kam.svg', top: 15.14),
  _MoodPreview(color: Color(0xFFAFEAAB), asset: 'jum.svg', top: 15.14),
  _MoodPreview(color: Color(0xFFAFEAAB), asset: 'sab.svg', top: 15.14),
  _MoodPreview(color: Color(0xFFFBE567), asset: 'min.svg', top: 15.14),
];

class _MoodPreview {
  const _MoodPreview({
    required this.color,
    this.asset,
    this.neutralEyes = false,
    this.top = 15.14,
  });

  final Color color;
  final String? asset;
  final bool neutralEyes;
  final double top;
}
