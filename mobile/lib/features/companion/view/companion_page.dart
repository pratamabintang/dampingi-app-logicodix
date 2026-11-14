import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_section_header.dart';
import '../../auth/controller/auth_controller.dart';
import '../repositories/observation_repository.dart';
import '../../mother/view/mother_navigation.dart';
import 'companion_extra_pages.dart';

class CompanionPage extends ConsumerStatefulWidget {
  const CompanionPage({super.key});

  @override
  ConsumerState<CompanionPage> createState() => _CompanionPageState();
}

class _CompanionPageState extends ConsumerState<CompanionPage> {
  _CompanionScreen _screen = _CompanionScreen.home;
  final bool _hasMother = false;
  bool _observationCompleted = false;
  bool _submittingObservation = false;
  bool _doneTodayLocally = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).asData?.value.session?.user;
    final userName = user?.name?.trim();
    final greetingName = userName == null || userName.isEmpty
        ? 'Pendamping'
        : userName;

    // Login sungguhan: data dari backend. Preview: tetap contoh desain.
    final live = ref.watch(backendTokenProvider) != null;
    final mother = live
        ? ref.watch(companionMotherProvider).asData?.value
        : null;
    final hasMother = live ? mother != null : _hasMother;
    final observationDone = live
        ? _doneTodayLocally ||
              (ref.watch(todayObservationDoneProvider).asData?.value ?? false)
        : _observationCompleted;
    // Dibaca sebelum Scaffold: body Scaffold tidak membawa viewInsets bawah.
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;

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
            final isDetail = _screen == _CompanionScreen.noteDetail;
            final isChat = _screen == _CompanionScreen.chat;

            return _CompanionScale(
              factor: scale,
              child: Center(
                child: SizedBox(
                  width: contentWidth,
                  child: Column(
                    children: [
                      Expanded(
                        child: switch (_screen) {
                          _CompanionScreen.home => _buildHome(
                            context,
                            greetingName,
                            scale,
                            live: live,
                            hasMother: hasMother,
                            motherName: mother?.name,
                            observationDone: observationDone,
                          ),
                          _CompanionScreen.observations =>
                            _CompanionObservationPage(
                              onStartObservation: () =>
                                  _startObservationFlow(scale),
                              onNoteTap: () => setState(
                                () => _screen = _CompanionScreen.noteDetail,
                              ),
                            ),
                          _CompanionScreen.noteDetail =>
                            _CompanionNoteDetailPage(
                              onBack: () => setState(
                                () => _screen = _CompanionScreen.observations,
                              ),
                              onEdit: () => setState(
                                () => _screen = _CompanionScreen.observations,
                              ),
                            ),
                          _CompanionScreen.support => CompanionSupportPage(
                            scale: scale,
                            onAction: (action) => _showNotice(context, action),
                          ),
                          _CompanionScreen.profile => CompanionProfilePage(
                            scale: scale,
                            userName: greetingName,
                            email: user?.email ?? '',
                            hasMother: hasMother,
                            motherName: mother?.name ?? '',
                            onEdit: () =>
                                context.push('/companion/profile/edit'),
                            onOpenConnections: () =>
                                context.push('/companion/connections'),
                            onLogout: _logout,
                          ),
                          _CompanionScreen.chat => CompanionChatPage(
                            scale: scale,
                          ),
                        },
                      ),
                      if (!isDetail && !keyboardVisible)
                        MotherNavigationBar(
                          selectedTab: switch (_screen) {
                            _CompanionScreen.home => MotherNavigationTab.home,
                            _CompanionScreen.observations =>
                              MotherNavigationTab.calendar,
                            _CompanionScreen.support =>
                              MotherNavigationTab.meditation,
                            _CompanionScreen.profile =>
                              MotherNavigationTab.profile,
                            _CompanionScreen.chat =>
                              MotherNavigationTab.recommendations,
                            _CompanionScreen.noteDetail =>
                              MotherNavigationTab.calendar,
                          },
                          onHomeTap: () =>
                              setState(() => _screen = _CompanionScreen.home),
                          onCalendarTap: () => setState(
                            () => _screen = _CompanionScreen.observations,
                          ),
                          onChatTap: () =>
                              setState(() => _screen = _CompanionScreen.chat),
                          onMeditationTap: () => setState(
                            () => _screen = _CompanionScreen.support,
                          ),
                          onProfileTap: () => setState(
                            () => _screen = _CompanionScreen.profile,
                          ),
                          calendarLabel: isChat ? 'Kalender' : 'Observasi',
                          chatLabel: isChat ? 'Rekomendasi' : 'Chat AI',
                          meditationLabel: isChat ? 'Meditasi' : 'Dukungan',
                          calendarInactiveAsset: isChat
                              ? 'calendar.svg'
                              : 'observation.svg',
                          calendarActiveAsset: isChat
                              ? 'calendar-active.svg'
                              : 'observation-active.svg',
                          meditationInactiveAsset: isChat
                              ? 'meditation.svg'
                              : 'support.svg',
                          meditationActiveAsset: isChat
                              ? 'meditation-active.svg'
                              : 'support-active.svg',
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

  Widget _buildHome(
    BuildContext context,
    String greetingName,
    double scale, {
    required bool live,
    required bool hasMother,
    required String? motherName,
    required bool observationDone,
  }) {
    return ListView(
      key: const Key('companion-dashboard-scroll'),
      padding: EdgeInsets.fromLTRB(
        scale * 24,
        scale * 20,
        scale * 24,
        scale * 24,
      ),
      children: [
        _CompanionHeader(
          scale: scale,
          onNotificationsTap: () => context.push('/companion/notifications'),
        ),
        SizedBox(height: scale * 36),
        Text(
          'Selamat Pagi, $greetingName 👋',
          key: const Key('companion-greeting'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppTheme.ink,
            fontFamily: AppTheme.fontFamily,
            fontSize: scale * 24,
            fontWeight: FontWeight.w600,
            height: 32 / 24,
          ),
        ),
        SizedBox(height: scale * 36),
        if (hasMother)
          _MotherSummaryCard(name: motherName ?? '')
        else
          _UnassignedMotherCard(
            onTap: () => context.push('/companion/connections'),
          ),
        SizedBox(height: scale * 24),
        _ObservationCard(
          completed: observationDone,
          onTap: () => _startObservationFlow(scale),
        ),
        SizedBox(height: scale * 24),
        _CompanionStoriesCard(
          // Catatan di kartu ini masih contoh; disambungkan di UI-11.
          showNotes: hasMother && !live,
          onSeeAll: () =>
              setState(() => _screen = _CompanionScreen.observations),
          onNoteTap: () =>
              setState(() => _screen = _CompanionScreen.noteDetail),
        ),
        SizedBox(height: scale * 24),
        _SupportCard(
          onSeeAll: () => setState(() => _screen = _CompanionScreen.support),
        ),
      ],
    );
  }

  Future<void> _startObservationFlow(double scale) async {
    if (ref.read(backendTokenProvider) != null) {
      await _submitLiveObservation(scale);
      return;
    }
    var selectedAnswer = 0;
    var title = '';
    var note = '';

    while (true) {
      if (!mounted) return;
      final answer = await showDialog<int>(
        context: context,
        builder: (dialogContext) => _ObservationQuestionDialog(
          scale: scale,
          initialAnswer: selectedAnswer,
        ),
      );
      if (!mounted) return;
      if (answer == null) return;
      selectedAnswer = answer;

      final draft = await showDialog<_ObservationDraft>(
        context: context,
        builder: (dialogContext) => _ObservationNoteDialog(
          scale: scale,
          initialTitle: title,
          initialNote: note,
        ),
      );
      if (!mounted) return;
      if (draft == null) return;
      title = draft.title;
      note = draft.note;
      if (draft.backToQuestion) continue;

      setState(() => _observationCompleted = true);
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => _ObservationSuccessDialog(
          scale: scale,
          onDone: () => Navigator.of(dialogContext).pop(),
        ),
      );
      return;
    }
  }

  Future<void> _submitLiveObservation(double scale) async {
    if (_submittingObservation) return;
    if (ref.read(backendTokenProvider) == null) return;
    final mother = ref.read(companionMotherProvider).asData?.value;
    if (mother == null) {
      _showMessage('Hubungkan dengan Ibu dulu lewat kode undangan.');
      return;
    }
    final motherId = mother.userId;
    if (motherId == null) {
      _showMessage('Backend belum mengirim ID Ibu. Perbarui backend dulu.');
      return;
    }

    // Dikunci sampai alur selesai, supaya ketukan kedua tidak membuka dialog lagi.
    setState(() => _submittingObservation = true);
    try {
      final repository = ref.read(observationRepositoryProvider);

      // Tanya backend langsung; status di layar bisa belum diperbarui.
      final alreadyDone = await repository.hasCompletedFor(
        connectionId: mother.id,
        day: DateTime.now(),
      );
      if (!mounted) return;
      if (alreadyDone) {
        setState(() => _doneTodayLocally = true);
        _showMessage('Observasi untuk hari ini sudah diisi.');
        return;
      }

      final answer = await showDialog<int>(
        context: context,
        builder: (dialogContext) =>
            _ObservationQuestionDialog(scale: scale, initialAnswer: 0),
      );
      if (!mounted || answer == null) return;

      await repository.submit(
        motherId: motherId,
        selectedOption: answer,
        day: DateTime.now(),
      );
      if (!mounted) return;
      setState(() => _doneTodayLocally = true);

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => _ObservationSuccessDialog(
          scale: scale,
          onDone: () => Navigator.of(dialogContext).pop(),
        ),
      );
    } catch (error) {
      if (mounted) _showMessage(observationFailureMessage(error));
    } finally {
      if (mounted) {
        setState(() => _submittingObservation = false);
        // Baru dimuat ulang setelah semua dialog selesai.
        ref.invalidate(todayObservationDoneProvider);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _logout() async {
    await ref.read(authControllerProvider.notifier).logout();
    if (mounted) context.go('/roles');
  }
}

enum _CompanionScreen { home, observations, noteDetail, support, profile, chat }

class _CompanionScale extends InheritedWidget {
  const _CompanionScale({required this.factor, required super.child});

  final double factor;

  @override
  bool updateShouldNotify(_CompanionScale oldWidget) =>
      factor != oldWidget.factor;
}

extension on BuildContext {
  double companionScale(double value) =>
      (dependOnInheritedWidgetOfExactType<_CompanionScale>()?.factor ?? 1) *
      value;
}

class _CompanionHeader extends StatelessWidget {
  const _CompanionHeader({
    required this.scale,
    required this.onNotificationsTap,
  });

  final double scale;
  final VoidCallback onNotificationsTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        ClipOval(
          child: Image.asset(
            'assets/images/mother_profile/man-1.png',
            width: 56 * scale,
            height: 56 * scale,
            fit: BoxFit.cover,
            semanticLabel: 'Foto profil pendamping',
          ),
        ),
        IconButton(
          key: const Key('companion-notification'),
          tooltip: 'Notifikasi',
          onPressed: onNotificationsTap,
          padding: EdgeInsets.all(8 * scale),
          constraints: BoxConstraints(
            minWidth: 48 * scale,
            minHeight: 48 * scale,
          ),
          icon: SvgPicture.asset(
            'assets/images/mother_home/notification.svg',
            width: 24 * scale,
            height: 24 * scale,
          ),
        ),
      ],
    );
  }
}

class _MotherSummaryCard extends StatelessWidget {
  const _MotherSummaryCard({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final scale = context.companionScale;
    return AppCard(
      key: const Key('companion-mother-summary'),
      padding: EdgeInsets.all(scale(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ibu yang anda didampingi',
            style: TextStyle(
              color: AppTheme.ink,
              fontFamily: AppTheme.fontFamily,
              fontSize: scale(16),
              fontWeight: FontWeight.w600,
              height: 24 / 16,
            ),
          ),
          SizedBox(height: scale(16)),
          Container(
            padding: EdgeInsets.all(scale(8)),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFAF9),
              borderRadius: BorderRadius.circular(scale(32)),
            ),
            child: Row(
              children: [
                ClipOval(
                  child: Image.asset(
                    'assets/images/mother_home/avatar-a.png',
                    width: scale(56),
                    height: scale(56),
                    fit: BoxFit.cover,
                    semanticLabel: 'Foto ibu yang didampingi',
                  ),
                ),
                SizedBox(width: scale(16)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        key: const Key('companion-mother-name'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.coralText,
                          fontFamily: AppTheme.fontFamily,
                          fontSize: scale(16),
                          fontWeight: FontWeight.w600,
                          height: 24 / 16,
                        ),
                      ),
                      Text(
                        'Ringkasan mingguan belum tersedia',
                        style: TextStyle(
                          color: AppTheme.muted,
                          fontFamily: AppTheme.fontFamily,
                          fontSize: scale(14),
                          height: 20 / 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UnassignedMotherCard extends StatelessWidget {
  const _UnassignedMotherCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scale = context.companionScale;
    return AppCard(
      key: const Key('companion-unassigned-card'),
      padding: EdgeInsets.all(scale(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Belum ada Ibu yang anda didampingi',
            style: TextStyle(
              color: AppTheme.ink,
              fontFamily: AppTheme.fontFamily,
              fontSize: scale(16),
              fontWeight: FontWeight.w600,
              height: 24 / 16,
            ),
          ),
          SizedBox(height: scale(16)),
          ClipRRect(
            borderRadius: BorderRadius.circular(scale(24)),
            child: Image.asset(
              'assets/images/login_hero.png',
              width: double.infinity,
              height: scale(140),
              fit: BoxFit.cover,
              alignment: const Alignment(0, -0.15),
              semanticLabel: 'Ibu, bayi, dan tenaga kesehatan',
            ),
          ),
          SizedBox(height: scale(16)),
          SizedBox(
            width: double.infinity,
            height: scale(48),
            child: FilledButton(
              key: const Key('companion-enter-mother-code'),
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.coral,
                foregroundColor: Colors.white,
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(scale(8)),
                ),
                textStyle: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: scale(16),
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Masukkan Kode Undangan'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ObservationCard extends StatelessWidget {
  const _ObservationCard({required this.onTap, this.completed = false});

  final VoidCallback onTap;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final scale = context.companionScale;
    return Container(
      key: const Key('companion-observation-card'),
      padding: EdgeInsets.all(scale(20)),
      decoration: BoxDecoration(
        color: AppTheme.pink2,
        border: Border.all(color: AppTheme.coral),
        borderRadius: BorderRadius.circular(scale(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            completed
                ? 'Observasi hari ini - Sudah diisi'
                : 'Observasi hari ini - Belum diisi',
            style: TextStyle(
              color: AppTheme.coralText,
              fontFamily: AppTheme.fontFamily,
              fontSize: scale(14),
              height: 20 / 14,
            ),
          ),
          SizedBox(height: scale(8)),
          Text(
            'Apa yang kamu amati hari ini?',
            style: TextStyle(
              color: AppTheme.coralText,
              fontFamily: AppTheme.fontFamily,
              fontSize: scale(20),
              fontWeight: FontWeight.w600,
              height: 30 / 20,
            ),
          ),
          SizedBox(height: scale(16)),
          SizedBox(
            width: double.infinity,
            height: scale(48),
            child: FilledButton(
              key: const Key('companion-observation-start'),
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.coral,
                foregroundColor: Colors.white,
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(scale(8)),
                ),
                textStyle: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: scale(16),
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Isi pertanyaan singkat'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompanionStoriesCard extends StatelessWidget {
  const _CompanionStoriesCard({
    required this.showNotes,
    required this.onSeeAll,
    required this.onNoteTap,
  });

  final bool showNotes;
  final VoidCallback onSeeAll;
  final VoidCallback onNoteTap;

  @override
  Widget build(BuildContext context) {
    final scale = context.companionScale;
    return AppCard(
      key: const Key('companion-stories-card'),
      padding: EdgeInsets.all(scale(20)),
      child: Column(
        children: [
          AppSectionHeader(
            title: 'Catatan terakhirmu',
            actionLabel: 'Lihat Semua',
            onAction: onSeeAll,
            scale: scale(1),
          ),
          if (showNotes) ...[
            SizedBox(height: scale(24)),
            for (var index = 0; index < _recentNotes.length; index++) ...[
              _CompanionNoteRow(
                key: Key('companion-note-$index'),
                title: _recentNotes[index].$1,
                snippet: _recentNotes[index].$2,
                onTap: onNoteTap,
              ),
              if (index < _recentNotes.length - 1) ...[
                SizedBox(height: scale(16)),
                Divider(height: scale(1), color: AppTheme.unselectedSurface),
                SizedBox(height: scale(16)),
              ],
            ],
          ],
        ],
      ),
    );
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard({required this.onSeeAll});

  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final scale = context.companionScale;
    return AppCard(
      key: const Key('companion-support-card'),
      padding: EdgeInsets.all(scale(20)),
      child: Column(
        children: [
          AppSectionHeader(
            title: 'Dukungan hari ini',
            actionLabel: 'Lihat Semua',
            onAction: onSeeAll,
            scale: scale(1),
          ),
          SizedBox(height: scale(24)),
          _CompanionNoteRow(
            key: const Key('companion-support-item'),
            title: 'Tawarkan bantuan singkat',
            snippet: 'Jeda tenang - 3 menit',
            onTap: () => _showNotice(context, 'Dukungan hari ini'),
          ),
        ],
      ),
    );
  }
}

class _CompanionNoteRow extends StatelessWidget {
  const _CompanionNoteRow({
    required this.title,
    required this.snippet,
    required this.onTap,
    super.key,
  });

  final String title;
  final String snippet;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scale = context.companionScale;
    return Semantics(
      button: true,
      label: 'Buka $title',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(scale(12)),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: scale(4)),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xFF252B37),
                          fontFamily: AppTheme.fontFamily,
                          fontSize: scale(16),
                          fontWeight: FontWeight.w600,
                          height: 24 / 16,
                        ),
                      ),
                      SizedBox(height: scale(10)),
                      Text(
                        snippet,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.muted,
                          fontFamily: AppTheme.fontFamily,
                          fontSize: scale(16),
                          height: 24 / 16,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: scale(16)),
                SvgPicture.asset(
                  'assets/images/mother_home/arrow-right.svg',
                  width: scale(24),
                  height: scale(24),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const _observationOptions = observationOptions;

class _ObservationQuestionDialog extends StatefulWidget {
  const _ObservationQuestionDialog({
    required this.scale,
    required this.initialAnswer,
  });

  final double scale;
  final int initialAnswer;

  @override
  State<_ObservationQuestionDialog> createState() =>
      _ObservationQuestionDialogState();
}

class _ObservationQuestionDialogState
    extends State<_ObservationQuestionDialog> {
  late int _selectedAnswer = widget.initialAnswer;

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;
    return Dialog(
      key: const Key('companion-observation-question-dialog'),
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: scale * 24),
      child: Container(
        width: scale * 342,
        padding: EdgeInsets.fromLTRB(
          scale * 24,
          scale * 16,
          scale * 24,
          scale * 24,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(scale * 32),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A101828),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                key: const Key('companion-observation-question-close'),
                tooltip: 'Tutup',
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(
                  Icons.close,
                  color: AppTheme.coral,
                  size: scale * 24,
                ),
                constraints: BoxConstraints.tightFor(
                  width: scale * 32,
                  height: scale * 32,
                ),
                padding: EdgeInsets.zero,
              ),
            ),
            SizedBox(height: scale * 12),
            Text(
              '1. $observationPrompt',
              textAlign: TextAlign.left,
              style: TextStyle(
                color: AppTheme.ink,
                fontFamily: AppTheme.fontFamily,
                fontSize: scale * 16,
                fontWeight: FontWeight.w600,
                height: 24 / 16,
              ),
            ),
            SizedBox(height: scale * 20),
            for (
              var index = 0;
              index < _observationOptions.length;
              index++
            ) ...[
              _ObservationAnswerOption(
                key: Key('companion-observation-answer-$index'),
                label: _observationOptions[index],
                selected: index == _selectedAnswer,
                scale: scale,
                onTap: () => setState(() => _selectedAnswer = index),
              ),
              if (index < _observationOptions.length - 1)
                SizedBox(height: scale * 8),
            ],
            SizedBox(height: scale * 24),
            _CompanionDialogButton(
              key: const Key('companion-observation-question-continue'),
              label: 'Lanjut',
              scale: scale,
              onPressed: () => Navigator.of(context).pop(_selectedAnswer),
            ),
            SizedBox(height: scale * 10),
            _CompanionDialogButton(
              key: const Key('companion-observation-question-back'),
              label: 'Kembali',
              scale: scale,
              onPressed: () => Navigator.of(context).pop(),
              secondary: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _ObservationAnswerOption extends StatelessWidget {
  const _ObservationAnswerOption({
    required this.label,
    required this.selected,
    required this.scale,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : const Color(0xFFFAFAFA),
      borderRadius: BorderRadius.circular(scale * 8),
      child: InkWell(
        key: Key('companion-observation-answer-${label.toLowerCase()}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(scale * 8),
        child: Container(
          width: double.infinity,
          height: scale * 62,
          padding: EdgeInsets.symmetric(horizontal: scale * 12),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected
                  ? const Color(0xFF32D583)
                  : AppTheme.unselectedSurface,
            ),
            borderRadius: BorderRadius.circular(scale * 8),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: selected ? const Color(0xFF12B76A) : AppTheme.muted,
                size: scale * 20,
              ),
              SizedBox(width: scale * 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.ink,
                    fontFamily: AppTheme.fontFamily,
                    fontSize: scale * 16,
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

class _ObservationDraft {
  const _ObservationDraft({
    required this.title,
    required this.note,
    required this.backToQuestion,
  });

  final String title;
  final String note;
  final bool backToQuestion;
}

class _ObservationNoteDialog extends StatefulWidget {
  const _ObservationNoteDialog({
    required this.scale,
    required this.initialTitle,
    required this.initialNote,
  });

  final double scale;
  final String initialTitle;
  final String initialNote;

  @override
  State<_ObservationNoteDialog> createState() => _ObservationNoteDialogState();
}

class _ObservationNoteDialogState extends State<_ObservationNoteDialog> {
  late final _titleController = TextEditingController(
    text: widget.initialTitle,
  );
  late final _noteController = TextEditingController(text: widget.initialNote);
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _pop({required bool backToQuestion}) {
    Navigator.of(context).pop(
      _ObservationDraft(
        title: _titleController.text.trim(),
        note: _noteController.text.trim(),
        backToQuestion: backToQuestion,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;
    return Dialog(
      key: const Key('companion-observation-note-dialog'),
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: scale * 24),
      child: Container(
        width: scale * 342,
        padding: EdgeInsets.fromLTRB(
          scale * 24,
          scale * 16,
          scale * 24,
          scale * 24,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(scale * 32),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A101828),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                key: const Key('companion-observation-note-close'),
                tooltip: 'Tutup',
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(
                  Icons.close,
                  color: AppTheme.coral,
                  size: scale * 24,
                ),
                constraints: BoxConstraints.tightFor(
                  width: scale * 32,
                  height: scale * 32,
                ),
                padding: EdgeInsets.zero,
              ),
            ),
            SizedBox(height: scale * 12),
            Text(
              'Tulis catatan harian anda',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.coralText,
                fontFamily: AppTheme.fontFamily,
                fontSize: scale * 20,
                fontWeight: FontWeight.w600,
                height: 30 / 20,
              ),
            ),
            SizedBox(height: scale * 20),
            _ObservationTextField(
              key: const Key('companion-observation-title'),
              controller: _titleController,
              scale: scale,
              hintText: 'Masukan judul',
            ),
            SizedBox(height: scale * 12),
            _ObservationTextField(
              key: const Key('companion-observation-note'),
              controller: _noteController,
              scale: scale,
              hintText: 'Ceritakan perasaanmu hari ini',
              maxLines: 5,
            ),
            SizedBox(height: scale * 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '*Opsional',
                style: TextStyle(
                  color: AppTheme.muted,
                  fontFamily: AppTheme.fontFamily,
                  fontSize: scale * 12,
                  height: 18 / 12,
                ),
              ),
            ),
            if (_error != null) ...[
              SizedBox(height: scale * 8),
              Text(
                _error!,
                key: const Key('companion-observation-error'),
                style: TextStyle(
                  color: AppTheme.coralText,
                  fontFamily: AppTheme.fontFamily,
                  fontSize: scale * 12,
                ),
              ),
            ],
            SizedBox(height: scale * 24),
            _CompanionDialogButton(
              key: const Key('companion-observation-note-done'),
              label: 'Selesai',
              scale: scale,
              onPressed: () {
                if (_titleController.text.trim().isEmpty) {
                  setState(() => _error = 'Judul catatan harus diisi.');
                  return;
                }
                _pop(backToQuestion: false);
              },
            ),
            SizedBox(height: scale * 10),
            _CompanionDialogButton(
              key: const Key('companion-observation-note-back'),
              label: 'Kembali',
              scale: scale,
              onPressed: () => _pop(backToQuestion: true),
              secondary: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _ObservationTextField extends StatelessWidget {
  const _ObservationTextField({
    required this.controller,
    required this.scale,
    required this.hintText,
    this.maxLines = 1,
    super.key,
  });

  final TextEditingController controller;
  final double scale;
  final String hintText;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(
        color: AppTheme.ink,
        fontFamily: AppTheme.fontFamily,
        fontSize: scale * 14,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: AppTheme.muted,
          fontFamily: AppTheme.fontFamily,
          fontSize: scale * 14,
        ),
        contentPadding: EdgeInsets.all(scale * 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(scale * 8),
          borderSide: const BorderSide(color: AppTheme.unselectedSurface),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(scale * 8),
          borderSide: const BorderSide(color: AppTheme.unselectedSurface),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(scale * 8),
          borderSide: const BorderSide(color: AppTheme.coral),
        ),
      ),
    );
  }
}

class _ObservationSuccessDialog extends StatelessWidget {
  const _ObservationSuccessDialog({required this.scale, required this.onDone});

  final double scale;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      key: const Key('companion-observation-success-dialog'),
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: scale * 24),
      child: Container(
        width: scale * 342,
        padding: EdgeInsets.fromLTRB(
          scale * 24,
          scale * 16,
          scale * 24,
          scale * 24,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(scale * 32),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A101828),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                key: const Key('companion-observation-success-close'),
                tooltip: 'Tutup',
                onPressed: onDone,
                icon: Icon(
                  Icons.close,
                  color: AppTheme.coral,
                  size: scale * 24,
                ),
                constraints: BoxConstraints.tightFor(
                  width: scale * 32,
                  height: scale * 32,
                ),
                padding: EdgeInsets.zero,
              ),
            ),
            SizedBox(height: scale * 20),
            Text(
              'Terima kasih sudah mengisi observasi hari ini!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.coralText,
                fontFamily: AppTheme.fontFamily,
                fontSize: scale * 20,
                fontWeight: FontWeight.w600,
                height: 30 / 20,
              ),
            ),
            SizedBox(height: scale * 24),
            _CompanionDialogButton(
              key: const Key('companion-observation-success-done'),
              label: 'Selesai',
              scale: scale,
              onPressed: onDone,
            ),
          ],
        ),
      ),
    );
  }
}

class _CompanionDialogButton extends StatelessWidget {
  const _CompanionDialogButton({
    required this.label,
    required this.scale,
    required this.onPressed,
    this.secondary = false,
    super.key,
  });

  final String label;
  final double scale;
  final VoidCallback onPressed;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: scale * 48,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: secondary ? AppTheme.pink2 : AppTheme.coral,
          foregroundColor: secondary ? AppTheme.coralText : Colors.white,
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(scale * 8),
          ),
          textStyle: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: scale * 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

class _CompanionObservationPage extends StatefulWidget {
  const _CompanionObservationPage({
    required this.onStartObservation,
    required this.onNoteTap,
  });

  final VoidCallback onStartObservation;
  final VoidCallback onNoteTap;

  @override
  State<_CompanionObservationPage> createState() =>
      _CompanionObservationPageState();
}

class _CompanionObservationPageState extends State<_CompanionObservationPage> {
  DateTime _weekStart = DateTime(2026, 8, 1);

  @override
  Widget build(BuildContext context) {
    final scale = context.companionScale;
    return ListView(
      key: const Key('companion-observation-scroll'),
      padding: EdgeInsets.fromLTRB(scale(24), scale(20), scale(24), scale(24)),
      children: [
        Text(
          'Dampingi',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.coralText,
            fontFamily: AppTheme.fontFamily,
            fontSize: scale(24),
            fontWeight: FontWeight.w600,
            height: 32 / 24,
          ),
        ),
        SizedBox(height: scale(48)),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _WeekButton(
              key: const Key('companion-week-previous'),
              icon: Icons.arrow_back,
              scale: scale(1),
              onPressed: () => setState(
                () => _weekStart = _weekStart.subtract(const Duration(days: 7)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: scale(8)),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _weekRangeLabel(_weekStart),
                      key: const Key('companion-week-label'),
                      style: TextStyle(
                        color: AppTheme.ink,
                        fontFamily: AppTheme.fontFamily,
                        fontSize: scale(20),
                        fontWeight: FontWeight.w600,
                        height: 30 / 20,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _WeekButton(
              key: const Key('companion-week-next'),
              icon: Icons.arrow_forward,
              scale: scale(1),
              onPressed: () => setState(
                () => _weekStart = _weekStart.add(const Duration(days: 7)),
              ),
            ),
          ],
        ),
        SizedBox(height: scale(32)),
        _ObservationCard(onTap: widget.onStartObservation),
        SizedBox(height: scale(24)),
        AppCard(
          key: const Key('companion-observation-notes-card'),
          padding: EdgeInsets.all(scale(20)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Catatan anda',
                style: TextStyle(
                  color: AppTheme.ink,
                  fontFamily: AppTheme.fontFamily,
                  fontSize: scale(16),
                  fontWeight: FontWeight.w600,
                  height: 24 / 16,
                ),
              ),
              SizedBox(height: scale(24)),
              for (var index = 0; index < 4; index++) ...[
                _CompanionNoteRow(
                  key: Key('companion-observation-note-$index'),
                  title: 'Hal Kecil yang berarti',
                  snippet: 'Senang karena ada suami yang',
                  onTap: widget.onNoteTap,
                ),
                if (index < 3) ...[
                  SizedBox(height: scale(16)),
                  Divider(height: scale(1), color: AppTheme.unselectedSurface),
                  SizedBox(height: scale(16)),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _WeekButton extends StatelessWidget {
  const _WeekButton({
    required this.icon,
    required this.scale,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final double scale;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56 * scale,
      height: 56 * scale,
      child: IconButton(
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: AppTheme.pink2,
          foregroundColor: AppTheme.coralText,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12 * scale),
          ),
        ),
        icon: Icon(icon, size: 24 * scale),
      ),
    );
  }
}

class _CompanionNoteDetailPage extends StatefulWidget {
  const _CompanionNoteDetailPage({required this.onBack, required this.onEdit});

  final VoidCallback onBack;
  final VoidCallback onEdit;

  @override
  State<_CompanionNoteDetailPage> createState() =>
      _CompanionNoteDetailPageState();
}

class _CompanionNoteDetailPageState extends State<_CompanionNoteDetailPage> {
  bool _showFullNote = false;

  @override
  Widget build(BuildContext context) {
    final scale = context.companionScale;
    return ListView(
      key: const Key('companion-note-detail-scroll'),
      padding: EdgeInsets.fromLTRB(scale(24), scale(20), scale(24), scale(24)),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            key: const Key('companion-note-detail-back'),
            tooltip: 'Kembali',
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back, color: AppTheme.ink),
          ),
        ),
        SizedBox(height: scale(12)),
        AppCard(
          key: const Key('companion-note-detail-card'),
          padding: EdgeInsets.all(scale(20)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  'Senin, 12 Agustus 2026',
                  style: TextStyle(
                    color: AppTheme.muted,
                    fontFamily: AppTheme.fontFamily,
                    fontSize: scale(16),
                    height: 24 / 16,
                  ),
                ),
              ),
              SizedBox(height: scale(32)),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(scale(20)),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFAF9),
                  border: Border.all(color: AppTheme.coral),
                  borderRadius: BorderRadius.circular(scale(24)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ringkasan AI',
                      style: TextStyle(
                        color: AppTheme.coralText,
                        fontFamily: AppTheme.fontFamily,
                        fontSize: scale(16),
                        fontWeight: FontWeight.w600,
                        height: 24 / 16,
                      ),
                    ),
                    SizedBox(height: scale(12)),
                    Text(
                      'Senang karena ada suami yang bantu aku untuk ke belakang, kok bisa suami bantu aku ke belakang padahal suami lagi di luar kota.',
                      maxLines: _showFullNote ? null : 4,
                      overflow: _showFullNote ? null : TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.coralText,
                        fontFamily: AppTheme.fontFamily,
                        fontSize: scale(16),
                        height: 24 / 16,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: scale(32)),
              Text(
                'Hal Kecil yang berarti',
                style: TextStyle(
                  color: AppTheme.ink,
                  fontFamily: AppTheme.fontFamily,
                  fontSize: scale(16),
                  fontWeight: FontWeight.w600,
                  height: 24 / 16,
                ),
              ),
              SizedBox(height: scale(12)),
              Text(
                'Senang karena ada suami yang bantu...',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppTheme.muted,
                  fontFamily: AppTheme.fontFamily,
                  fontSize: scale(16),
                  height: 24 / 16,
                ),
              ),
              SizedBox(height: scale(16)),
              _CompanionDialogButton(
                key: const Key('companion-note-show-more'),
                label: _showFullNote
                    ? 'Lihat lebih sedikit'
                    : 'Lihat lebih banyak',
                scale: scale(1),
                onPressed: () => setState(() => _showFullNote = !_showFullNote),
                secondary: true,
              ),
            ],
          ),
        ),
        SizedBox(height: scale(32)),
        _CompanionDialogButton(
          key: const Key('companion-note-open-chat'),
          label: 'Buka di chat AI',
          scale: scale(1),
          onPressed: () => _showNotice(context, 'Chat AI'),
        ),
        SizedBox(height: scale(10)),
        _CompanionDialogButton(
          key: const Key('companion-note-edit'),
          label: 'Ubah catatan observasi',
          scale: scale(1),
          onPressed: widget.onEdit,
          secondary: true,
        ),
      ],
    );
  }
}

String _weekRangeLabel(DateTime start) {
  final end = start.add(const Duration(days: 6));
  if (start.month == end.month) {
    return '${start.day}-${end.day} ${_monthName(start.month)} ${start.year}';
  }
  return '${start.day} ${_monthName(start.month)}-${end.day} ${_monthName(end.month)} ${end.year}';
}

String _monthName(int month) => const [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
][month - 1];

void _showNotice(BuildContext context, String feature) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('$feature belum tersedia.')));
}

const _recentNotes = [
  ('Hal Kecil yang berarti', 'Senang karena ada suami yang'),
  ('Hal Kecil yang berarti', 'Senang karena ada suami yang'),
  ('Hal Kecil yang berarti', 'Senang karena ada suami yang'),
];
