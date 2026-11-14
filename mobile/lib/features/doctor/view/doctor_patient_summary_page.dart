import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_brand_header.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty.dart';
import '../../../core/widgets/app_error.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/app_section_header.dart';
import '../../../core/widgets/mother_story_list_tile.dart';
import '../../connections/repositories/connection_repository.dart';
import '../../doctor/repositories/doctor_patient_summary_repository.dart';
import '../../mother/repositories/daily_entry_repository.dart';
import '../../mother/models/mother_story.dart';
import '../../auth/controller/auth_controller.dart';
import '../../mother/repositories/mother_story_repository.dart';
import 'doctor_patient_picker.dart';
import 'doctor_patient_story_page.dart';

class DoctorPatientSummaryPage extends ConsumerStatefulWidget {
  const DoctorPatientSummaryPage({required this.bottomNavigation, super.key});

  final Widget bottomNavigation;

  @override
  ConsumerState<DoctorPatientSummaryPage> createState() =>
      _DoctorPatientSummaryPageState();
}

class _DoctorPatientSummaryPageState
    extends ConsumerState<DoctorPatientSummaryPage> {
  static final _sampleWeek = DateTime(2026, 8, 1);
  int _weekOffset = 0;
  String? _selectedConnectionId;

  @override
  Widget build(BuildContext context) {
    final backendSession = ref.watch(backendTokenProvider) != null;
    final connections = ref.watch(activeConnectionsProvider);
    final patients = (connections.asData?.value ?? const <ConnectionPerson>[])
        .where((connection) => connection.role == 'mother')
        .toList();
    final selectedPatient =
        patients
            .where((patient) => patient.id == _selectedConnectionId)
            .firstOrNull ??
        patients.firstOrNull;
    final currentMonday = DateTime.now().subtract(
      Duration(days: DateTime.now().weekday - 1),
    );
    final weekStart = (backendSession ? currentMonday : _sampleWeek).add(
      Duration(days: 7 * _weekOffset),
    );
    final summaryAsync = backendSession && selectedPatient != null
        ? ref.watch(
            doctorPatientSummaryProvider((
              connectionId: selectedPatient.id,
              periodStart: isoDate(weekStart),
            )),
          )
        : null;

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

            return Center(
              child: SizedBox(
                width: width,
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        key: const Key('doctor-patient-summary-scroll'),
                        padding: EdgeInsets.fromLTRB(
                          24 * scale,
                          20 * scale,
                          24 * scale,
                          24 * scale,
                        ),
                        children: [
                          const AppBrandHeader(),
                          SizedBox(height: 36 * scale),
                          Text(
                            'Ringkasan pasien',
                            key: const Key('doctor-patient-summary-title'),
                            style: TextStyle(
                              color: AppTheme.ink,
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 24 * scale,
                              fontWeight: FontWeight.w600,
                              height: 32 / 24,
                            ),
                          ),
                          SizedBox(height: 36 * scale),
                          _buildPatientPicker(
                            backendSession: backendSession,
                            connections: connections,
                            patients: patients,
                            selectedPatient: selectedPatient,
                          ),
                          SizedBox(height: 36 * scale),
                          _WeekSelector(
                            label: _weekLabel(weekStart),
                            onPrevious: () => _changeWeek(-1),
                            onNext: () => _changeWeek(1),
                          ),
                          SizedBox(height: 36 * scale),
                          ..._buildSummarySections(
                            backendSession: backendSession,
                            connections: connections,
                            selectedPatient: selectedPatient,
                            summary: summaryAsync,
                            weekStart: weekStart,
                            weekLabel: _weekLabel(weekStart),
                          ),
                        ],
                      ),
                    ),
                    widget.bottomNavigation,
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPatientPicker({
    required bool backendSession,
    required AsyncValue<List<ConnectionPerson>?> connections,
    required List<ConnectionPerson> patients,
    required ConnectionPerson? selectedPatient,
  }) {
    if (!backendSession) {
      return DoctorPatientPicker(
        keyPrefix: 'doctor-patient-summary',
        value: 'Ny. Shopia Mudj.',
        onChanged: (_) {},
      );
    }

    return connections.when(
      data: (_) => patients.isEmpty
          ? const AppEmpty(
              key: Key('doctor-patient-summary-no-patients'),
              title: 'Belum ada pasien terhubung',
              message: 'Ibu yang terhubung akan muncul di sini.',
            )
          : DoctorPatientPicker(
              keyPrefix: 'doctor-patient-summary',
              value: selectedPatient?.id ?? patients.first.id,
              patients: patients,
              onChanged: (value) =>
                  setState(() => _selectedConnectionId = value),
            ),
      loading: () => const SizedBox(
        key: Key('doctor-patient-summary-patients-loading'),
        height: 100,
        child: AppLoading(message: 'Memuat pasien...'),
      ),
      error: (error, stackTrace) => AppError(
        key: const Key('doctor-patient-summary-patients-error'),
        message: connectionFailureMessage(error),
        onRetry: () => ref.invalidate(activeConnectionsProvider),
      ),
    );
  }

  List<Widget> _buildSummarySections({
    required bool backendSession,
    required AsyncValue<List<ConnectionPerson>?> connections,
    required ConnectionPerson? selectedPatient,
    required AsyncValue<DoctorPatientSummary>? summary,
    required DateTime weekStart,
    required String weekLabel,
  }) {
    if (!backendSession) {
      return [
        const _MoodWeek(),
        const SizedBox(height: 36),
        _EpdsSummaryCard(label: weekLabel, isPreview: true),
        const SizedBox(height: 36),
        _StoriesCard(stories: _sampleStories, onStoryTap: _openStory),
      ];
    }

    if (connections.isLoading) {
      return const [
        SizedBox(
          key: Key('doctor-patient-summary-data-loading'),
          height: 180,
          child: AppLoading(message: 'Memuat ringkasan pasien...'),
        ),
      ];
    }
    if (connections.hasError) {
      return [
        SizedBox(
          key: const Key('doctor-patient-summary-data-error'),
          height: 160,
          child: AppError(
            message: connectionFailureMessage(connections.error!),
            onRetry: () => ref.invalidate(activeConnectionsProvider),
          ),
        ),
      ];
    }
    if (selectedPatient == null || summary == null) return const [];

    return summary.when(
      data: (data) => [
        if (data.permissions.weeklySummary)
          _MoodWeek(weekStart: weekStart, moods: data.moods)
        else
          const _SharingNotice(
            key: Key('doctor-patient-summary-mood-private'),
            message: 'Ibu belum membagikan ringkasan mingguan.',
          ),
        const SizedBox(height: 36),
        _EpdsSummaryCard(
          label: weekLabel,
          assessments: data.epds,
          isShared: data.permissions.epds,
        ),
        const SizedBox(height: 36),
        _StoriesCard(
          stories: data.permissions.journal
              ? storiesFromEntries(
                  journals: data.journals,
                  moods: [
                    for (final mood in data.moods)
                      MoodEntry(
                        id: mood.date,
                        date: mood.date,
                        mood: mood.mood,
                      ),
                  ],
                )
              : const [],
          isShared: data.permissions.journal,
          onStoryTap: _openStory,
        ),
      ],
      loading: () => const [
        SizedBox(
          key: Key('doctor-patient-summary-data-loading'),
          height: 180,
          child: AppLoading(message: 'Memuat ringkasan pasien...'),
        ),
      ],
      error: (error, stackTrace) => [
        SizedBox(
          key: const Key('doctor-patient-summary-data-error'),
          height: 160,
          child: AppError(
            message: connectionFailureMessage(error),
            onRetry: () {
              ref.invalidate(
                doctorPatientSummaryProvider((
                  connectionId: selectedPatient.id,
                  periodStart: isoDate(weekStart),
                )),
              );
            },
          ),
        ),
      ],
    );
  }

  void _changeWeek(int amount) {
    setState(() => _weekOffset += amount);
  }

  void _openStory(MotherStory story) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => DoctorPatientStoryPage(story: story),
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
    final scale = _scaleFor(context);
    return Row(
      children: [
        _WeekButton(
          key: const Key('doctor-patient-summary-previous-week'),
          asset: 'week-arrow-left.svg',
          label: 'Minggu sebelumnya',
          onPressed: onPrevious,
          scale: scale,
        ),
        SizedBox(width: 10 * scale),
        Expanded(
          child: Container(
            key: const Key('doctor-patient-summary-week-background'),
            height: 48 * scale,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(12 * scale),
            ),
            child: Text(
              label,
              key: const Key('doctor-patient-summary-week-label'),
              style: TextStyle(
                color: AppTheme.ink,
                fontFamily: AppTheme.fontFamily,
                fontSize: 16 * scale,
                fontWeight: FontWeight.w600,
                height: 24 / 16,
              ),
            ),
          ),
        ),
        SizedBox(width: 10 * scale),
        _WeekButton(
          key: const Key('doctor-patient-summary-next-week'),
          asset: 'week-arrow-right.svg',
          label: 'Minggu berikutnya',
          onPressed: onNext,
          scale: scale,
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
    required this.scale,
    super.key,
  });

  final String asset;
  final String label;
  final VoidCallback onPressed;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        width: 48 * scale,
        height: 48 * scale,
        child: Material(
          color: AppTheme.pink2,
          borderRadius: BorderRadius.circular(8 * scale),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(8 * scale),
            child: Center(
              child: SvgPicture.asset(
                'assets/images/mother_calendar/$asset',
                width: 20 * scale,
                height: 20 * scale,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MoodWeek extends StatelessWidget {
  const _MoodWeek({this.weekStart, this.moods});

  final DateTime? weekStart;
  final List<PatientMoodEntry>? moods;

  @override
  Widget build(BuildContext context) {
    final scale = _scaleFor(context);
    final moodsByDate = {
      for (final mood in moods ?? const <PatientMoodEntry>[])
        mood.date: mood.mood,
    };
    return SizedBox(
      height: 144 * scale,
      child: Row(
        children: [
          for (var index = 0; index < 7; index++) ...[
            if (index > 0) SizedBox(width: 4 * scale),
            Expanded(
              child: _MoodDay(
                day: weekStart == null
                    ? _weekDays[index]
                    : _weekDays[weekStart!.add(Duration(days: index)).weekday -
                          1],
                mood: weekStart == null
                    ? _weekMoods[index]
                    : _MoodPreview.fromValue(
                        moodsByDate[isoDate(
                          weekStart!.add(Duration(days: index)),
                        )],
                      ),
                scale: scale,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MoodDay extends StatelessWidget {
  const _MoodDay({required this.day, required this.mood, required this.scale});

  final String day;
  final _MoodPreview? mood;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('doctor-patient-summary-day-$day'),
      height: 144 * scale,
      decoration: BoxDecoration(
        color: mood?.color ?? const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12 * scale),
      ),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: 14 * scale,
            child: mood?.neutralEyes == true
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/mother_calendar/neutral-eye-left.png',
                        width: 14.302 * scale,
                        height: 9.128 * scale,
                        fit: BoxFit.fill,
                      ),
                      SizedBox(width: 3.36 * scale),
                      Image.asset(
                        'assets/images/mother_calendar/neutral-eye-right.png',
                        width: 14.302 * scale,
                        height: 9.128 * scale,
                        fit: BoxFit.fill,
                      ),
                    ],
                  )
                : mood?.asset != null
                ? SvgPicture.asset(
                    'assets/images/mother_calendar/${mood!.asset}',
                  )
                : const SizedBox.shrink(),
          ),
          Positioned(
            bottom: 10 * scale,
            child: Text(
              day,
              style: TextStyle(
                color: const Color(0xFF252B37),
                fontFamily: AppTheme.fontFamily,
                fontSize: 14 * scale,
                fontWeight: FontWeight.w700,
                height: 20 / 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EpdsSummaryCard extends StatelessWidget {
  const _EpdsSummaryCard({
    required this.label,
    this.assessments = const [],
    this.isShared = true,
    this.isPreview = false,
  });

  final String label;
  final List<PatientEPDSAssessment> assessments;
  final bool isShared;
  final bool isPreview;

  @override
  Widget build(BuildContext context) {
    final scale = _scaleFor(context);
    return Container(
      key: const Key('doctor-patient-summary-epds'),
      width: double.infinity,
      padding: EdgeInsets.all(20 * scale),
      decoration: BoxDecoration(
        color: AppTheme.selectedSurface,
        border: Border.all(color: AppTheme.coral),
        borderRadius: BorderRadius.circular(32 * scale),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ringkasan EPDS $label',
            style: TextStyle(
              color: AppTheme.coralText,
              fontFamily: AppTheme.fontFamily,
              fontSize: 14 * scale,
              fontWeight: FontWeight.w600,
              height: 20 / 14,
            ),
          ),
          SizedBox(height: 10 * scale),
          Text(
            !isShared
                ? 'Ibu belum membagikan hasil EPDS.'
                : isPreview
                ? 'Senang karena ada suami yang bantu aku untuk ke belakang, kok bisa suami bantu aku ke belakang padahal suami lagi di luar kota.'
                : assessments.isEmpty
                ? 'Belum ada hasil EPDS pada periode ini.'
                : 'Skor EPDS: ${assessments.first.totalScore}\n'
                      '${assessments.first.disclaimer}',
            key: const Key('doctor-patient-summary-epds-content'),
            style: TextStyle(
              color: AppTheme.coralText,
              fontFamily: AppTheme.fontFamily,
              fontSize: 14 * scale,
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
    required this.onStoryTap,
    this.isShared = true,
  });

  final List<MotherStory> stories;
  final bool isShared;
  final ValueChanged<MotherStory> onStoryTap;

  @override
  Widget build(BuildContext context) {
    final scale = _scaleFor(context);
    return AppCard(
      key: const Key('doctor-patient-summary-stories'),
      padding: EdgeInsets.all(20 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(title: 'Cerita terakhir pasien', scale: scale),
          SizedBox(height: 24 * scale),
          if (!isShared)
            Text(
              'Ibu belum membagikan jurnal pribadi.',
              key: const Key('doctor-patient-summary-journal-private'),
              style: TextStyle(
                color: AppTheme.muted,
                fontFamily: AppTheme.fontFamily,
                fontSize: 14 * scale,
                height: 20 / 14,
              ),
            )
          else if (stories.isEmpty)
            Text(
              'Belum ada cerita pada periode ini.',
              key: const Key('doctor-patient-summary-no-stories'),
              style: TextStyle(
                color: AppTheme.muted,
                fontFamily: AppTheme.fontFamily,
                fontSize: 14 * scale,
                height: 20 / 14,
              ),
            ),
          for (var index = 0; isShared && index < stories.length; index++) ...[
            MotherStoryListTile(
              story: stories[index],
              scale: scale,
              keyPrefix: 'doctor-patient-summary-story-$index',
              arrowAsset: 'assets/images/mother_calendar/story-arrow-right.svg',
              snippetFontSize: 16,
              centerFace: true,
              onTap: () => onStoryTap(stories[index]),
            ),
            if (index < stories.length - 1)
              SizedBox(
                height: 20 * scale,
                child: Center(
                  child: SvgPicture.asset(
                    'assets/images/mother_calendar/story-divider.svg',
                    width: double.infinity,
                    height: scale,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _MoodPreview {
  const _MoodPreview({
    required this.color,
    this.asset,
    this.neutralEyes = false,
  });

  final Color color;
  final String? asset;
  final bool neutralEyes;

  factory _MoodPreview.fromValue(int? value) {
    if (value == null) return const _MoodPreview(color: Color(0xFFF5F5F5));
    final mood = MotherMood.values[value - 1];
    return _MoodPreview(color: mood.color, asset: mood.asset);
  }
}

class _SharingNotice extends StatelessWidget {
  const _SharingNotice({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scale = _scaleFor(context);
    return AppCard(
      key: key,
      padding: EdgeInsets.all(20 * scale),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppTheme.muted,
          fontFamily: AppTheme.fontFamily,
          fontSize: 14 * scale,
          height: 20 / 14,
        ),
      ),
    );
  }
}

double _scaleFor(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  return (width / 390).clamp(0.7, 1.15).toDouble();
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

const _sampleStories = <MotherStory>[
  MotherStory(
    id: 'doctor-story-1',
    weekdayIndex: 0,
    date: 'Senin, 12 Agustus 2026',
    mood: MotherMood.verySad,
    moodLabel: 'Sangat sedih',
    title: 'Hal Kecil yang berarti',
    note: 'Senang karena ada suami yang bantu aku untuk ke belakang, kok bisa suami bantu aku ke belakang padahal suami lagi di luar kota.',
    summary: 'Senang karena ada suami yang bantu aku untuk ke belakang, kok bisa suami bantu aku ke belakang padahal suami lagi di luar kota.',
  ),
  MotherStory(
    id: 'doctor-story-2',
    weekdayIndex: 1,
    date: 'Selasa, 2 Agu 2026',
    mood: MotherMood.veryHappy,
    moodLabel: 'Sangat senang',
    title: 'Hal Kecil yang berarti',
    note: 'Senang karena ada...',
    summary: 'Hari ini aku merasa lebih ringan dan bersyukur atas bantuan orang-orang di sekitarku.',
  ),
  MotherStory(
    id: 'doctor-story-3',
    weekdayIndex: 2,
    date: 'Rabu, 3 Agu 2026',
    mood: MotherMood.happy,
    moodLabel: 'Senang',
    title: 'Hal Kecil yang berarti',
    note: 'Senang karena ada...',
    summary:
        'Aku merasa senang karena ada waktu untuk beristirahat dan bercerita.',
  ),
  MotherStory(
    id: 'doctor-story-4',
    weekdayIndex: 3,
    date: 'Kamis, 4 Agu 2026',
    mood: MotherMood.verySad,
    moodLabel: 'Sangat sedih',
    title: 'Hal Kecil yang berarti',
    note: 'Senang karena ada...',
    summary: 'Ada banyak hal yang kupikirkan hari ini, tetapi aku mencoba menjalaninya satu per satu.',
  ),
  MotherStory(
    id: 'doctor-story-5',
    weekdayIndex: 4,
    date: 'Jumat, 5 Agu 2026',
    mood: MotherMood.veryHappy,
    moodLabel: 'Sangat senang',
    title: 'Hal Kecil yang berarti',
    note: 'Senang karena ada...',
    summary: 'Aku menikmati waktu bersama keluarga dan merasa didengarkan.',
  ),
  MotherStory(
    id: 'doctor-story-6',
    weekdayIndex: 5,
    date: 'Sabtu, 6 Agu 2026',
    mood: MotherMood.happy,
    moodLabel: 'Senang',
    title: 'Hal Kecil yang berarti',
    note: 'Senang karena ada...',
    summary: 'Hari ini berjalan cukup baik dan aku menemukan hal kecil yang membuatku tersenyum.',
  ),
];
