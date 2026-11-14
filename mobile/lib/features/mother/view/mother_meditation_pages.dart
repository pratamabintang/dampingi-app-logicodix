import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_brand_header.dart';
import 'mother_navigation.dart';

class MotherMeditationListPage extends ConsumerWidget {
  const MotherMeditationListPage({super.key});

  static const _activities = [
    'Meditasi Singkat',
    'Meditasi Sedang',
    'Meditasi Lama',
    'Meditasi Selamanya',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scale = (constraints.maxWidth / 390)
                .clamp(0.7, 1.15)
                .toDouble();
            double scaled(double value) => value * scale;
            final contentWidth = constraints.maxWidth < 390 * scale
                ? constraints.maxWidth
                : 390 * scale;

            return Center(
              child: SizedBox(
                width: contentWidth,
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        key: const Key('mother-meditation-list-scroll'),
                        padding: EdgeInsets.fromLTRB(
                          scaled(24),
                          scaled(20),
                          scaled(24),
                          scaled(24),
                        ),
                        children: [
                          const AppBrandHeader(),
                          SizedBox(height: scaled(36)),
                          _SuggestionCard(
                            scale: scale,
                            onTap: () =>
                                context.go('/mother/meditation/breathing'),
                          ),
                          SizedBox(height: scaled(36)),
                          Text(
                            'Saran aktivitas untuk anda',
                            style: TextStyle(
                              color: AppTheme.ink,
                              fontSize: scaled(24),
                              fontWeight: FontWeight.w600,
                              height: 32 / 24,
                            ),
                          ),
                          SizedBox(height: scaled(36)),
                          _MeditationActivitiesCard(
                            scale: scale,
                            onSelect: () =>
                                context.go('/mother/meditation/breathing'),
                          ),
                        ],
                      ),
                    ),
                    MotherNavigationBar(
                      selectedTab: MotherNavigationTab.meditation,
                      onHomeTap: () => context.go('/mother'),
                      onCalendarTap: () => context.go('/mother/calendar'),
                      onChatTap: () => context.go('/mother/chat'),
                      onMeditationTap: () => context.go('/mother/meditation'),
                      onProfileTap: () => context.go('/mother/profile'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.scale, required this.onTap});

  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    double scaled(double value) => value * scale;

    return Container(
      key: const Key('mother-meditation-suggestion'),
      constraints: BoxConstraints(minHeight: scaled(200)),
      padding: EdgeInsets.all(scaled(20)),
      decoration: BoxDecoration(
        color: const Color(0x1AFFFFFF),
        border: Border.all(color: AppTheme.white3),
        borderRadius: BorderRadius.circular(scaled(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Saran hari ini',
            style: TextStyle(
              color: AppTheme.muted,
              fontSize: scaled(16),
              fontWeight: FontWeight.w400,
              height: 24 / 16,
            ),
          ),
          SizedBox(height: scaled(10)),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'Tenangkan pikiran, pelan-\npelan.',
                softWrap: false,
                style: TextStyle(
                  color: AppTheme.coralText,
                  fontSize: scaled(20),
                  fontWeight: FontWeight.w600,
                  height: 30 / 20,
                ),
              ),
            ),
          ),
          SizedBox(height: scaled(16)),
          SizedBox(
            width: double.infinity,
            height: scaled(48),
            child: FilledButton(
              key: const Key('mother-meditation-suggestion-start'),
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.coral,
                foregroundColor: Colors.white,
                fixedSize: Size.fromHeight(scaled(48)),
                minimumSize: Size(0, scaled(48)),
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(scaled(8)),
                ),
                elevation: 1,
                shadowColor: const Color(0x0D101828),
              ),
              child: Text(
                'Meditasi singkat · 3 menit',
                style: TextStyle(
                  fontSize: scaled(16),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MeditationActivitiesCard extends StatelessWidget {
  const _MeditationActivitiesCard({
    required this.scale,
    required this.onSelect,
  });

  final double scale;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    double scaled(double value) => value * scale;

    return Container(
      key: const Key('mother-meditation-activities'),
      padding: EdgeInsets.all(scaled(20)),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppTheme.white3),
        borderRadius: BorderRadius.circular(scaled(32)),
      ),
      child: Column(
        children: [
          for (
            var index = 0;
            index < MotherMeditationListPage._activities.length;
            index++
          )
            _MeditationActivityRow(
              index: index,
              title: MotherMeditationListPage._activities[index],
              scale: scale,
              showArrow:
                  index == MotherMeditationListPage._activities.length - 1,
              onTap: onSelect,
              showDivider:
                  index < MotherMeditationListPage._activities.length - 1,
            ),
        ],
      ),
    );
  }
}

class _MeditationActivityRow extends StatelessWidget {
  const _MeditationActivityRow({
    required this.index,
    required this.title,
    required this.scale,
    required this.showArrow,
    required this.onTap,
    required this.showDivider,
  });

  final int index;
  final String title;
  final double scale;
  final bool showArrow;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    double scaled(double value) => value * scale;

    return Column(
      children: [
        SizedBox(
          height: scaled(58),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: Key('mother-meditation-activity-$index'),
              onTap: onTap,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppTheme.white10,
                            fontSize: scaled(16),
                            fontWeight: FontWeight.w600,
                            height: 24 / 16,
                          ),
                        ),
                        SizedBox(height: scaled(4)),
                        Text(
                          'Jeda tenang - 3 menit',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppTheme.muted,
                            fontSize: scaled(16),
                            height: 24 / 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: scaled(16)),
                  if (showArrow)
                    SizedBox(
                      width: scaled(24),
                      height: scaled(24),
                      child: Center(
                        child: SvgPicture.asset(
                          'assets/images/meditation/arrow-right.svg',
                          key: const Key('mother-meditation-activity-arrow'),
                        ),
                      ),
                    )
                  else
                    Text(
                      'Lakukan',
                      style: TextStyle(
                        color: AppTheme.coralText,
                        fontSize: scaled(16),
                        fontWeight: FontWeight.w600,
                        height: 24 / 16,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: EdgeInsets.fromLTRB(0, scaled(10), 0, scaled(9)),
            child: SvgPicture.asset('assets/images/mother_home/divider.svg'),
          ),
      ],
    );
  }
}

class MotherBreathingSessionPage extends StatefulWidget {
  const MotherBreathingSessionPage({super.key});

  @override
  State<MotherBreathingSessionPage> createState() =>
      _MotherBreathingSessionPageState();
}

class _MotherBreathingSessionPageState
    extends State<MotherBreathingSessionPage> {
  static const _durationStepSeconds = 30;
  static const _maxDurationSeconds = 60 * 60;

  Timer? _timer;
  int _durationSeconds = 3 * 60;
  int _remainingSeconds = 180;
  bool _isRunning = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startOrPause() {
    if (_isRunning) {
      _timer?.cancel();
      setState(() => _isRunning = false);
      return;
    }
    if (_remainingSeconds == 0) {
      setState(() => _remainingSeconds = _durationSeconds);
    }
    setState(() => _isRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds <= 1) {
        timer.cancel();
        setState(() {
          _remainingSeconds = 0;
          _isRunning = false;
        });
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _remainingSeconds = _durationSeconds;
    });
  }

  void _setDuration(int seconds) {
    _timer?.cancel();
    setState(() {
      _durationSeconds = seconds;
      _remainingSeconds = seconds;
      _isRunning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scale = (constraints.maxWidth / 382)
                .clamp(0.7, 1.15)
                .toDouble();
            double scaled(double value) => value * scale;
            final contentWidth = constraints.maxWidth < 390 * scale
                ? constraints.maxWidth
                : 390 * scale;

            return Center(
              child: SizedBox(
                width: contentWidth,
                child: ListView(
                  key: const Key('mother-breathing-session-scroll'),
                  padding: EdgeInsets.fromLTRB(
                    scaled(24),
                    scaled(20),
                    scaled(24),
                    scaled(32),
                  ),
                  children: [
                    SizedBox(
                      height: scaled(24),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Semantics(
                          button: true,
                          label: 'Kembali',
                          child: InkWell(
                            key: const Key('mother-breathing-back'),
                            onTap: () => context.go('/mother/meditation'),
                            child: SizedBox(
                              width: scaled(24),
                              height: scaled(24),
                              child: SvgPicture.asset(
                                'assets/images/meditation/arrow-left.svg',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: scaled(36)),
                    Column(
                      children: [
                        Text(
                          'Meditasi singkat',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.ink,
                            fontSize: scaled(24),
                            fontWeight: FontWeight.w600,
                            height: 32 / 24,
                          ),
                        ),
                        SizedBox(height: scaled(10)),
                        Text(
                          'Ambil posisi yang nyaman. Kamu boleh berhenti kapan saja',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.gray500,
                            fontSize: scaled(14),
                            height: 20 / 14,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: scaled(36)),
                    _DurationPicker(
                      scale: scale,
                      remainingSeconds: _remainingSeconds,
                      onDecrement: () {
                        if (_durationSeconds > _durationStepSeconds) {
                          _setDuration(_durationSeconds - _durationStepSeconds);
                        }
                      },
                      onIncrement: () {
                        if (_durationSeconds < _maxDurationSeconds) {
                          _setDuration(_durationSeconds + _durationStepSeconds);
                        }
                      },
                    ),
                    SizedBox(height: scaled(36)),
                    Row(
                      children: [
                        Expanded(
                          child: _SessionActionButton(
                            key: const Key('mother-breathing-start'),
                            label: _isRunning ? 'Jeda' : 'Mulai',
                            backgroundColor: AppTheme.coral,
                            foregroundColor: Colors.white,
                            scale: scale,
                            onPressed: _startOrPause,
                          ),
                        ),
                        SizedBox(width: scaled(10)),
                        Expanded(
                          child: _SessionActionButton(
                            key: const Key('mother-breathing-reset'),
                            label: 'Ulangi',
                            backgroundColor: AppTheme.coralLight,
                            foregroundColor: AppTheme.coralText,
                            scale: scale,
                            onPressed: _reset,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: scaled(36)),
                    _BreathingInstructions(scale: scale),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DurationPicker extends StatelessWidget {
  const _DurationPicker({
    required this.scale,
    required this.remainingSeconds,
    required this.onDecrement,
    required this.onIncrement,
  });

  final double scale;
  final int remainingSeconds;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    double scaled(double value) => value * scale;
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    final time =
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';

    return Column(
      children: [
        Text(
          'Saran durasi - 3 menit',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.gray500,
            fontSize: scaled(14),
            height: 20 / 14,
          ),
        ),
        SizedBox(height: scaled(16)),
        SizedBox(
          height: scaled(90),
          child: Row(
            children: [
              _DurationAction(
                key: const Key('mother-breathing-decrement'),
                iconAsset: 'timer-minus.svg',
                tooltip: 'Kurangi 30 detik',
                onPressed: onDecrement,
                scale: scale,
              ),
              Expanded(
                child: Text(
                  time,
                  key: const Key('mother-breathing-time'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.coralText,
                    fontSize: scaled(72),
                    fontWeight: FontWeight.w700,
                    height: 90 / 72,
                    letterSpacing: scaled(-1.44),
                  ),
                ),
              ),
              _DurationAction(
                key: const Key('mother-breathing-increment'),
                iconAsset: 'timer-plus.svg',
                tooltip: 'Tambah 30 detik',
                onPressed: onIncrement,
                scale: scale,
              ),
            ],
          ),
        ),
        SizedBox(height: scaled(16)),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _DurationAdjustmentButton(
              key: const Key('mother-breathing-subtract-30-seconds'),
              label: '30 Detik',
              iconAsset: 'timer-minus.svg',
              scale: scale,
              onPressed: onDecrement,
            ),
            SizedBox(width: scaled(16)),
            _DurationAdjustmentButton(
              key: const Key('mother-breathing-add-30-seconds'),
              label: '30 Detik',
              iconAsset: 'timer-plus.svg',
              scale: scale,
              onPressed: onIncrement,
            ),
          ],
        ),
      ],
    );
  }
}

class _DurationAction extends StatelessWidget {
  const _DurationAction({
    required this.iconAsset,
    required this.tooltip,
    required this.onPressed,
    required this.scale,
    super.key,
  });

  final String iconAsset;
  final String tooltip;
  final VoidCallback onPressed;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Material(
        color: AppTheme.pink2,
        borderRadius: BorderRadius.circular(8 * scale),
        elevation: 1,
        shadowColor: const Color(0x0D101828),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8 * scale),
          child: SizedBox(
            width: 48 * scale,
            height: 48 * scale,
            child: Center(
              child: SvgPicture.asset('assets/images/meditation/$iconAsset'),
            ),
          ),
        ),
      ),
    );
  }
}

class _DurationAdjustmentButton extends StatelessWidget {
  const _DurationAdjustmentButton({
    required this.label,
    required this.iconAsset,
    required this.scale,
    required this.onPressed,
    super.key,
  });

  final String label;
  final String iconAsset;
  final double scale;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.pink2,
      borderRadius: BorderRadius.circular(8 * scale),
      elevation: 1,
      shadowColor: const Color(0x0D101828),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8 * scale),
        child: SizedBox(
          width: 124 * scale,
          height: 48 * scale,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset('assets/images/meditation/$iconAsset'),
              SizedBox(width: 8 * scale),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    color: AppTheme.coralText,
                    fontSize: 16 * scale,
                    fontWeight: FontWeight.w600,
                    height: 24 / 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionActionButton extends StatelessWidget {
  const _SessionActionButton({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.scale,
    required this.onPressed,
    super.key,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final double scale;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(8 * scale),
      elevation: 1,
      shadowColor: const Color(0x0D101828),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8 * scale),
        child: SizedBox(
          height: 48 * scale,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: foregroundColor,
                fontSize: 16 * scale,
                fontWeight: FontWeight.w600,
                height: 24 / 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BreathingInstructions extends StatelessWidget {
  const _BreathingInstructions({required this.scale});

  final double scale;

  static const _steps = [
    (
      title: 'Tarik nafas perlahan',
      asset: 'breathing-in.svg',
      graphicWidth: 54.0,
      graphicHeight: 53.0,
    ),
    (
      title: 'Tahan nafas 5 detik',
      asset: 'breathing-hold.svg',
      graphicWidth: 38.0,
      graphicHeight: 10.85,
    ),
    (
      title: 'Hembuskan nafas sampai habis',
      asset: 'breathing-out.svg',
      graphicWidth: 38.0,
      graphicHeight: 23.0,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    double scaled(double value) => value * scale;

    return Column(
      children: [
        for (var index = 0; index < _steps.length; index++) ...[
          _BreathingStep(
            number: index + 1,
            title: _steps[index].title,
            asset: _steps[index].asset,
            graphicWidth: _steps[index].graphicWidth,
            graphicHeight: _steps[index].graphicHeight,
            scale: scale,
          ),
          if (index < _steps.length - 1) SizedBox(height: scaled(10)),
        ],
      ],
    );
  }
}

class _BreathingStep extends StatelessWidget {
  const _BreathingStep({
    required this.number,
    required this.title,
    required this.asset,
    required this.graphicWidth,
    required this.graphicHeight,
    required this.scale,
  });

  final int number;
  final String title;
  final String asset;
  final double graphicWidth;
  final double graphicHeight;
  final double scale;

  @override
  Widget build(BuildContext context) {
    double scaled(double value) => value * scale;
    final isFirst = number == 1;
    final isLast = number == 3;

    return SizedBox(
      key: Key('mother-breathing-step-frame-$number'),
      height: scaled(83),
      child: Row(
        children: [
          Container(
            key: Key('mother-breathing-step-card-$number'),
            width: scaled(83),
            height: scaled(83),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.pink2,
              borderRadius: BorderRadius.circular(scaled(32)),
            ),
            child: isFirst
                ? SvgPicture.asset('assets/images/meditation/$asset')
                : SizedBox(
                    width: scaled(54),
                    height: scaled(53),
                    child: Stack(
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppTheme.coral,
                            borderRadius: BorderRadius.circular(scaled(12)),
                          ),
                          child: SizedBox(
                            width: scaled(54),
                            height: scaled(53),
                          ),
                        ),
                        Positioned(
                          left: scaled(8.5),
                          top: scaled(isLast ? 18 : 20),
                          child: SvgPicture.asset(
                            'assets/images/meditation/$asset',
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          SizedBox(width: scaled(16)),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                top: scaled(isLast ? 4.5 : 14.5),
                bottom: scaled(isLast ? 4.5 : 14.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$number. $title',
                    key: Key('mother-breathing-step-$number'),
                    maxLines: isLast ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.white10,
                      fontSize: scaled(14),
                      fontWeight: FontWeight.w600,
                      height: 20 / 14,
                    ),
                  ),
                  SizedBox(height: scaled(9.5)),
                  Text(
                    'Senang karena ada suami yang',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.muted,
                      fontSize: scaled(16),
                      height: 24 / 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
