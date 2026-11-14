import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/backend_api.dart';
import '../models/epds_questions.dart';
import '../repositories/epds_repository.dart';
import '../repositories/mother_story_repository.dart';

Future<void> showMotherWeeklyEpds(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Kuesioner EPDS mingguan',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (context, animation, secondaryAnimation) =>
        const _MotherWeeklyEpdsDialog(),
    transitionBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

class _MotherWeeklyEpdsDialog extends ConsumerStatefulWidget {
  const _MotherWeeklyEpdsDialog();

  @override
  ConsumerState<_MotherWeeklyEpdsDialog> createState() =>
      _MotherWeeklyEpdsDialogState();
}

class _MotherWeeklyEpdsDialogState
    extends ConsumerState<_MotherWeeklyEpdsDialog> {
  /// 0 = pengantar, 1 = pertanyaan, 2 = hasil.
  var _step = 0;
  var _index = 0;
  final _answers = List<int?>.filled(epdsQuestions.length, null);
  var _submitting = false;
  String? _error;
  EpdsResult? _result;

  bool get _isLastQuestion => _index == epdsQuestions.length - 1;

  /// Dihitung di aplikasi juga, supaya banner darurat tetap muncul
  /// walaupun backend gagal atau sedang mode preview.
  bool get _item10Positive {
    final answer = _answers.last;
    return answer != null && answer != epdsSafeItem10Index;
  }

  Future<void> _next() async {
    if (_answers[_index] == null || _submitting) return;
    if (!_isLastQuestion) {
      setState(() => _index++);
      return;
    }

    final token = ref.read(backendTokenProvider);
    if (token == null) {
      // Mode preview: tidak dikirim ke server.
      setState(() => _step = 2);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(epdsRepositoryProvider)
          .evaluate(
            accessToken: token,
            answers: [for (final answer in _answers) answer!],
          );
      if (!mounted) return;
      setState(() {
        _result = result;
        _submitting = false;
        _step = 2;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = switch (error) {
          BackendApiException(statusCode: 401) =>
            'Sesi login telah berakhir. Silakan masuk kembali.',
          BackendApiException(:final message) => message,
          ApiNetworkException(:final message) => message,
          ApiConfigurationException(:final message) => message,
          _ => 'Hasil EPDS belum dapat dihitung. Coba lagi.',
        };
      });
    }
  }

  void _back() {
    if (_submitting) return;
    setState(() {
      _error = null;
      if (_index > 0) {
        _index--;
      } else {
        _step = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final scale = (screenSize.width / 390).clamp(0.7, 1.15).toDouble();
    final dialogWidth = math
        .min(342 * scale, screenSize.width - 48 * scale)
        .toDouble();

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
              child: const ColoredBox(color: Color(0x1A000000)),
            ),
          ),
          Center(
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 24 * scale,
                  vertical: 16 * scale,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: dialogWidth,
                    maxHeight: screenSize.height - 32 * scale,
                  ),
                  child: SingleChildScrollView(
                    child: Container(
                      key: Key('mother-weekly-epds-dialog-$_step'),
                      width: dialogWidth,
                      padding: EdgeInsets.all(20 * scale),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: AppTheme.white3),
                        borderRadius: BorderRadius.circular(32 * scale),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1A0A0D12),
                            offset: Offset(0, 1),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                      child: _buildStep(scale),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(double scale) => switch (_step) {
    0 => _introduction(scale),
    1 => _question(scale),
    _ => _completed(scale),
  };

  Widget _introduction(double scale) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _closeButton(scale),
        SizedBox(height: 24 * scale),
        Text(
          'Selamat mengisi Edinburgh Postnatal Depression Scale (EPDS)!',
          key: const Key('mother-weekly-epds-intro-title'),
          style: TextStyle(
            color: AppTheme.coralText,
            fontFamily: AppTheme.fontFamily,
            fontSize: 16 * scale,
            fontWeight: FontWeight.w600,
            height: 24 / 16,
          ),
        ),
        SizedBox(height: 16 * scale),
        Text.rich(
          TextSpan(
            style: TextStyle(
              color: AppTheme.muted,
              fontFamily: AppTheme.fontFamily,
              fontSize: 16 * scale,
              height: 24 / 16,
            ),
            children: const [
              TextSpan(
                text:
                    'Mohon memilih jawaban yang paling mendekati keadaan '
                    'perasaan anda dalam ',
              ),
              TextSpan(
                text: '7 hari',
                style: TextStyle(
                  color: AppTheme.gray500,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextSpan(text: ' terakhir, bukan hanya perasaan anda hari ini.'),
            ],
          ),
        ),
        SizedBox(height: 24 * scale),
        _primaryButton(
          key: const Key('mother-weekly-epds-continue'),
          label: 'Lanjut',
          scale: scale,
          onPressed: () => setState(() => _step = 1),
        ),
      ],
    );
  }

  Widget _question(double scale) {
    final question = epdsQuestions[_index];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _closeButton(scale),
        SizedBox(height: 16 * scale),
        Text(
          'Pertanyaan ${_index + 1} dari ${epdsQuestions.length}',
          style: TextStyle(
            color: AppTheme.muted,
            fontFamily: AppTheme.fontFamily,
            fontSize: 14 * scale,
            height: 20 / 14,
          ),
        ),
        SizedBox(height: 8 * scale),
        Text(
          '${_index + 1}. ${question.text}',
          key: const Key('mother-weekly-epds-question'),
          style: TextStyle(
            color: AppTheme.ink,
            fontFamily: AppTheme.fontFamily,
            fontSize: 16 * scale,
            fontWeight: FontWeight.w600,
            height: 24 / 16,
          ),
        ),
        SizedBox(height: 20 * scale),
        for (var option = 0; option < question.options.length; option++) ...[
          if (option > 0) SizedBox(height: 12 * scale),
          _answerOption(option, question.options[option], scale),
        ],
        if (_error case final error?) ...[
          SizedBox(height: 16 * scale),
          Text(
            error,
            key: const Key('mother-weekly-epds-error'),
            style: TextStyle(
              color: const Color(0xFFB42318),
              fontFamily: AppTheme.fontFamily,
              fontSize: 14 * scale,
              height: 20 / 14,
            ),
          ),
        ],
        SizedBox(height: 24 * scale),
        _primaryButton(
          key: const Key('mother-weekly-epds-next'),
          label: _submitting
              ? 'Mengirim...'
              : _isLastQuestion
              ? 'Kirim'
              : 'Lanjut',
          scale: scale,
          onPressed: _answers[_index] == null || _submitting ? null : _next,
        ),
        SizedBox(height: 10 * scale),
        SizedBox(
          width: double.infinity,
          height: 48 * scale,
          child: FilledButton(
            key: const Key('mother-weekly-epds-back'),
            onPressed: _back,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.coralLight,
              foregroundColor: AppTheme.coralText,
              elevation: 1,
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8 * scale),
              ),
              textStyle: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 16 * scale,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: const Text('Kembali'),
          ),
        ),
      ],
    );
  }

  Widget _answerOption(int option, String answer, double scale) {
    final isSelected = _answers[_index] == option;
    const selectedGreen = Color(0xFF12B76A);

    return Semantics(
      button: true,
      selected: isSelected,
      label: answer,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('mother-weekly-epds-option-$option'),
          onTap: _submitting
              ? null
              : () => setState(() {
                  _answers[_index] = option;
                  _error = null;
                }),
          borderRadius: BorderRadius.circular(12 * scale),
          child: Container(
            constraints: BoxConstraints(minHeight: 46 * scale),
            padding: EdgeInsets.symmetric(
              horizontal: 20 * scale,
              vertical: 10 * scale,
            ),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : const Color(0xFFFAFAFA),
              border: Border.all(
                color: isSelected ? selectedGreen : AppTheme.white3,
                width: isSelected ? 1.5 * scale : 1,
              ),
              borderRadius: BorderRadius.circular(12 * scale),
            ),
            child: Row(
              children: [
                Container(
                  width: 22 * scale,
                  height: 22 * scale,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? selectedGreen
                          : const Color(0xFFA4A7AE),
                      width: 2 * scale,
                    ),
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check,
                          color: selectedGreen,
                          size: 15 * scale,
                        )
                      : null,
                ),
                SizedBox(width: 12 * scale),
                Expanded(
                  child: Text(
                    answer,
                    style: TextStyle(
                      color: AppTheme.ink,
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 16 * scale,
                      height: 24 / 16,
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

  Widget _completed(double scale) {
    final result = _result;
    final urgent =
        _item10Positive || (result?.immediateReviewRequired ?? false);
    final bodyStyle = TextStyle(
      color: AppTheme.muted,
      fontFamily: AppTheme.fontFamily,
      fontSize: 14 * scale,
      height: 20 / 14,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _closeButton(scale),
        SizedBox(height: 24 * scale),
        Text(
          'Terima kasih sudah mengisi EPDS mingguan!',
          key: const Key('mother-weekly-epds-complete-message'),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.coralText,
            fontFamily: AppTheme.fontFamily,
            fontSize: 16 * scale,
            fontWeight: FontWeight.w600,
            height: 24 / 16,
          ),
        ),
        if (urgent) ...[
          SizedBox(height: 16 * scale),
          Container(
            key: const Key('mother-weekly-epds-urgent'),
            padding: EdgeInsets.all(12 * scale),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F0),
              border: Border.all(color: AppTheme.coralText),
              borderRadius: BorderRadius.circular(12 * scale),
            ),
            child: Text(
              'Kamu tidak sendirian. Jika ada pikiran menyakiti diri sendiri, '
              'segera hubungi 119 atau datang ke IGD terdekat, dan minta '
              'orang terdekat menemanimu.',
              style: TextStyle(
                color: const Color(0xFFB42318),
                fontFamily: AppTheme.fontFamily,
                fontSize: 14 * scale,
                fontWeight: FontWeight.w600,
                height: 20 / 14,
              ),
            ),
          ),
        ],
        SizedBox(height: 16 * scale),
        if (result == null)
          Text(
            'Mode pratinjau: jawaban tidak dikirim ke server.',
            key: const Key('mother-weekly-epds-preview'),
            textAlign: TextAlign.center,
            style: bodyStyle,
          )
        else ...[
          Text(
            'Skor EPDS: ${result.totalScore} dari 30',
            key: const Key('mother-weekly-epds-score'),
            textAlign: TextAlign.center,
            style: bodyStyle.copyWith(
              color: AppTheme.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8 * scale),
          Text(
            result.followUpRequired
                ? 'Jawabanmu menunjukkan kamu mungkin sedang melalui masa yang '
                      'berat. Sebaiknya ceritakan hasil ini ke bidan, dokter, '
                      'atau tenaga kesehatan yang mendampingimu.'
                : 'Terima kasih sudah jujur dengan perasaanmu. Tetap catat '
                      'mood-mu setiap hari, ya.',
            textAlign: TextAlign.center,
            style: bodyStyle,
          ),
          SizedBox(height: 12 * scale),
          Text(
            result.disclaimer,
            key: const Key('mother-weekly-epds-disclaimer'),
            textAlign: TextAlign.center,
            style: bodyStyle.copyWith(fontSize: 12 * scale, height: 18 / 12),
          ),
        ],
        SizedBox(height: 24 * scale),
        _primaryButton(
          key: const Key('mother-weekly-epds-finish'),
          label: 'Selesai',
          scale: scale,
          onPressed: _close,
        ),
      ],
    );
  }

  Widget _closeButton(double scale) {
    return SizedBox(
      height: 24 * scale,
      child: Align(
        alignment: Alignment.centerRight,
        child: IconButton(
          key: const Key('mother-weekly-epds-close'),
          onPressed: _close,
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

  Widget _primaryButton({
    required Key key,
    required String label,
    required double scale,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48 * scale,
      child: FilledButton(
        key: key,
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.coral,
          foregroundColor: Colors.white,
          elevation: 1,
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8 * scale),
          ),
          textStyle: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 16 * scale,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: Text(label),
      ),
    );
  }

  void _close() => Navigator.of(context).pop();
}
