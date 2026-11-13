import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_text_field.dart';

const _doctorPreviewPatientCode = 'K4DSTP';

Future<void> showDoctorInvitationFlow(
  BuildContext context, {
  required double scale,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Tutup undangan pasien',
    barrierColor: Colors.transparent,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      final screenWidth = MediaQuery.sizeOf(dialogContext).width;
      final dialogWidth = math.min(scale * 342, screenWidth - scale * 40);
      return Material(
        type: MaterialType.transparency,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(dialogContext).pop(),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
                child: const ColoredBox(color: Color(0x1A000000)),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(vertical: scale * 24),
                child: SizedBox(
                  width: dialogWidth,
                  child: _DoctorInvitationDialog(scale: scale),
                ),
              ),
            ),
          ],
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 180),
    transitionBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

enum _DoctorInvitationStep { enterCode, confirm, success }

class _DoctorInvitationDialog extends StatefulWidget {
  const _DoctorInvitationDialog({required this.scale});

  final double scale;

  @override
  State<_DoctorInvitationDialog> createState() =>
      _DoctorInvitationDialogState();
}

class _DoctorInvitationDialogState extends State<_DoctorInvitationDialog> {
  final _codeController = TextEditingController();
  _DoctorInvitationStep _step = _DoctorInvitationStep.enterCode;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;
    return Container(
      key: Key('doctor-invitation-${_step.name}-dialog'),
      padding: EdgeInsets.fromLTRB(
        scale * 20,
        scale * (_step == _DoctorInvitationStep.success ? 12 : 16),
        scale * 20,
        scale *
            switch (_step) {
              _DoctorInvitationStep.enterCode => 14,
              _DoctorInvitationStep.confirm => 16,
              _DoctorInvitationStep.success => 10,
            },
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFFAFAFA)),
        borderRadius: BorderRadius.circular(scale * 32),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A101828),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: switch (_step) {
        _DoctorInvitationStep.enterCode => _buildCodeForm(scale),
        _DoctorInvitationStep.confirm => _buildConfirmation(scale),
        _DoctorInvitationStep.success => _buildSuccess(scale),
      },
    );
  }

  Widget _buildCodeForm(double scale) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DoctorDialogCloseButton(
          key: const Key('doctor-invitation-code-close'),
          scale: scale,
          onPressed: _close,
        ),
        SizedBox(height: scale * 16),
        SizedBox(
          height: scale * 24,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Masukan kode pendampingan Ibu',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.coralText,
                fontFamily: AppTheme.fontFamily,
                fontSize: scale * 16,
                fontWeight: FontWeight.w600,
                height: 24 / 16,
              ),
            ),
          ),
        ),
        SizedBox(height: scale * 16),
        AppTextField(
          key: const Key('doctor-invitation-code-field'),
          controller: _codeController,
          label: 'Kode Pendampingan Ibu',
          hintText: 'Masukan kode',
          inputHeight: scale * 44,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          onFieldSubmitted: (_) => _submitCode(),
          labelStyle: TextStyle(
            fontFamily: AppTheme.fontFamily,
            color: AppTheme.body,
            fontSize: scale * 14,
            fontWeight: FontWeight.w500,
            height: 20 / 14,
          ),
          textStyle: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: scale * 16,
            color: AppTheme.ink,
          ),
          hintStyle: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: scale * 16,
            color: AppTheme.muted,
          ),
        ),
        if (_errorMessage case final message?) ...[
          SizedBox(height: scale * 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              message,
              key: const Key('doctor-invitation-code-error'),
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontFamily: AppTheme.fontFamily,
                fontSize: scale * 12,
              ),
            ),
          ),
        ],
        SizedBox(height: scale * 16),
        _DoctorInvitationButton(
          key: const Key('doctor-invitation-code-next'),
          label: 'Lanjut',
          scale: scale,
          onPressed: _submitCode,
        ),
      ],
    );
  }

  Widget _buildConfirmation(double scale) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DoctorDialogCloseButton(
          key: const Key('doctor-invitation-confirm-close'),
          scale: scale,
          onPressed: _close,
        ),
        SizedBox(height: scale * 16),
        SizedBox(
          height: scale * 48,
          child: Text(
            key: const Key('doctor-invitation-confirm-title'),
            'Apakah anda ingin mendampingi pengguna ini?',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.coralText,
              fontFamily: AppTheme.fontFamily,
              fontSize: scale * 14,
              fontWeight: FontWeight.w600,
              height: 24 / 14,
            ),
          ),
        ),
        SizedBox(height: scale * 16),
        Container(
          key: const Key('doctor-invitation-patient-card'),
          padding: EdgeInsets.all(scale * 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFAF9),
            borderRadius: BorderRadius.circular(scale * 32),
          ),
          child: Row(
            children: [
              ClipOval(
                child: Image.asset(
                  'assets/images/doctor/patient-avatar.png',
                  width: scale * 56,
                  height: scale * 56,
                  fit: BoxFit.cover,
                  semanticLabel: 'Foto Ny. Shopia Mudj.',
                ),
              ),
              SizedBox(width: scale * 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: scale * 24,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Ny. Shopia Mudj.',
                          style: TextStyle(
                            color: AppTheme.coralText,
                            fontFamily: AppTheme.fontFamily,
                            fontSize: scale * 16,
                            fontWeight: FontWeight.w600,
                            height: 24 / 16,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: scale * 20,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'shopiamu@gmail.com',
                          style: TextStyle(
                            color: AppTheme.muted,
                            fontFamily: AppTheme.fontFamily,
                            fontSize: scale * 14,
                            height: 20 / 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: scale * 16),
        _DoctorInvitationButton(
          key: const Key('doctor-invitation-confirm-yes'),
          label: 'Ya',
          scale: scale,
          onPressed: () => setState(() {
            _step = _DoctorInvitationStep.success;
            _errorMessage = null;
          }),
        ),
        SizedBox(height: scale * 8),
        _DoctorInvitationButton(
          key: const Key('doctor-invitation-confirm-back'),
          label: 'Kembali',
          scale: scale,
          secondary: true,
          onPressed: () => setState(() {
            _step = _DoctorInvitationStep.enterCode;
            _errorMessage = null;
          }),
        ),
      ],
    );
  }

  Widget _buildSuccess(double scale) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DoctorDialogCloseButton(
          key: const Key('doctor-invitation-success-close'),
          scale: scale,
          onPressed: _close,
        ),
        SizedBox(height: scale * 16),
        SizedBox(
          height: scale * 24,
          child: Text(
            'Pengguna berhasil anda dampingi!',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.coralText,
              fontFamily: AppTheme.fontFamily,
              fontSize: scale * 14,
              fontWeight: FontWeight.w600,
              height: 24 / 14,
            ),
          ),
        ),
        SizedBox(height: scale * 16),
        _DoctorInvitationButton(
          key: const Key('doctor-invitation-success-done'),
          label: 'Selesai',
          scale: scale,
          onPressed: _close,
        ),
      ],
    );
  }

  void _submitCode() {
    final code = _codeController.text.trim().toUpperCase();
    if (code != _doctorPreviewPatientCode) {
      setState(() {
        _errorMessage = code.isEmpty
            ? 'Masukan kode pendampingan Ibu.'
            : 'Kode pendampingan tidak dikenali.';
      });
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _step = _DoctorInvitationStep.confirm;
      _errorMessage = null;
    });
  }

  void _close() => Navigator.of(context).pop();
}

class _DoctorDialogCloseButton extends StatelessWidget {
  const _DoctorDialogCloseButton({
    required this.scale,
    required this.onPressed,
    super.key,
  });

  final double scale;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Semantics(
        button: true,
        label: 'Tutup',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: key,
            onTap: onPressed,
            borderRadius: BorderRadius.circular(scale * 16),
            child: SizedBox(
              width: scale * 32,
              height: scale * 32,
              child: Icon(Icons.close, color: AppTheme.coral, size: scale * 24),
            ),
          ),
        ),
      ),
    );
  }
}

class _DoctorInvitationButton extends StatelessWidget {
  const _DoctorInvitationButton({
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
          backgroundColor: secondary ? AppTheme.coralLight : AppTheme.coral,
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
