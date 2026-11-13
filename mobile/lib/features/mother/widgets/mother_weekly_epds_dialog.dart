import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_theme.dart';

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

class _MotherWeeklyEpdsDialog extends StatefulWidget {
  const _MotherWeeklyEpdsDialog();

  @override
  State<_MotherWeeklyEpdsDialog> createState() =>
      _MotherWeeklyEpdsDialogState();
}

class _MotherWeeklyEpdsDialogState extends State<_MotherWeeklyEpdsDialog> {
  var _step = 0;
  var _selectedAnswer = 0;

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
                        border: Border.all(color: const Color(0xFFFAFAFA)),
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
    const answers = [
      'Ya, setiap saat',
      'Ya, hampir setiap saat',
      'Tidak, tidak terlalu sering',
      'Tidak pernah sama sekali',
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _closeButton(scale),
        SizedBox(height: 24 * scale),
        Text(
          '1. Saya merasa bahagia:',
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
        for (var index = 0; index < answers.length; index++) ...[
          if (index > 0) SizedBox(height: 16 * scale),
          _answerOption(index, answers[index], scale),
        ],
        SizedBox(height: 24 * scale),
        _primaryButton(
          key: const Key('mother-weekly-epds-next'),
          label: 'Lanjut',
          scale: scale,
          onPressed: () => setState(() => _step = 2),
        ),
        SizedBox(height: 10 * scale),
        SizedBox(
          width: double.infinity,
          height: 48 * scale,
          child: FilledButton(
            key: const Key('mother-weekly-epds-back'),
            onPressed: () => setState(() => _step = 0),
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

  Widget _answerOption(int index, String answer, double scale) {
    final isSelected = _selectedAnswer == index;
    const selectedGreen = Color(0xFF12B76A);

    return Semantics(
      button: true,
      selected: isSelected,
      label: answer,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('mother-weekly-epds-option-$index'),
          onTap: () => setState(() => _selectedAnswer = index),
          borderRadius: BorderRadius.circular(12 * scale),
          child: Container(
            height: 46 * scale,
            padding: EdgeInsets.symmetric(horizontal: 20 * scale),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : const Color(0xFFFAFAFA),
              border: Border.all(
                color: isSelected ? selectedGreen : const Color(0xFFE9EAEB),
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
    required VoidCallback onPressed,
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
