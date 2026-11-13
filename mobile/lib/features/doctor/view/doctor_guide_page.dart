import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_brand_header.dart';
import '../../../core/widgets/app_card.dart';
import 'doctor_patient_picker.dart';

class DoctorGuidePage extends StatefulWidget {
  const DoctorGuidePage({required this.bottomNavigation, super.key});

  final Widget bottomNavigation;

  @override
  State<DoctorGuidePage> createState() => _DoctorGuidePageState();
}

class _DoctorGuidePageState extends State<DoctorGuidePage> {
  static const _sampleDate = 'Senin, 12 Agustus 2026';
  static const _sampleInstruction =
      "Lorem Ipsum is simply dummy text of the printing and typesetting "
      "industry. Lorem Ipsum has been the industry's standard dummy text "
      'ever since the 1500s.';

  String _selectedPatient = 'Ny. Shopia Mudj.';
  String? _instruction = _sampleInstruction;

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

            return Center(
              child: SizedBox(
                width: width,
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        key: const Key('doctor-guide-scroll'),
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
                            'Arahkan pasien anda',
                            key: const Key('doctor-guide-title'),
                            style: TextStyle(
                              color: AppTheme.ink,
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 24 * scale,
                              fontWeight: FontWeight.w600,
                              height: 32 / 24,
                            ),
                          ),
                          SizedBox(height: 36 * scale),
                          DoctorPatientPicker(
                            keyPrefix: 'doctor-guide',
                            value: _selectedPatient,
                            onChanged: (value) =>
                                setState(() => _selectedPatient = value),
                          ),
                          SizedBox(height: 36 * scale),
                          _GuidanceCard(
                            instruction: _instruction,
                            onCreate: () => _editInstruction(),
                            onEdit: () =>
                                _editInstruction(initialText: _instruction),
                            onDelete: () => _deleteInstruction(),
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

  Future<void> _editInstruction({String? initialText}) async {
    final isEditing = initialText != null;
    final instruction = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Tutup form arahan pasien',
      barrierColor: Colors.transparent,
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final screenWidth = MediaQuery.sizeOf(dialogContext).width;
        final dialogWidth = math.min(
          MediaQuery.sizeOf(dialogContext).width / 390 * 342,
          screenWidth - screenWidth / 390 * 40,
        );
        final scale = (screenWidth / 390).clamp(0.7, 1.15).toDouble();
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
                  padding: EdgeInsets.symmetric(vertical: 24 * scale),
                  child: SizedBox(
                    width: dialogWidth,
                    child: _InstructionFormDialog(
                      initialText: initialText ?? '',
                      scale: scale,
                      title: isEditing
                          ? 'Ubah arahan kepada pasien'
                          : 'Tulis arahan kepada pasien',
                      doneLabel: isEditing ? 'Simpan' : 'Selesai',
                    ),
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

    if (instruction != null && mounted) {
      setState(() => _instruction = instruction);
      await _showCompletionDialog(
        context,
        message: isEditing
            ? 'Arahan berhasil diperbarui!'
            : 'Arahan berhasil diberikan ke pasien!',
      );
    }
  }

  Future<void> _deleteInstruction() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus arahan?'),
        content: const Text('Arahan untuk pasien ini akan dihapus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (shouldDelete == true && mounted) {
      setState(() => _instruction = null);
      await _showCompletionDialog(context, message: 'Arahan berhasil dihapus!');
    }
  }

  Future<void> _showCompletionDialog(
    BuildContext context, {
    required String message,
  }) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final scale = (screenWidth / 390).clamp(0.7, 1.15).toDouble();
    final width = math.min(scale * 342, screenWidth - scale * 40);
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Tutup konfirmasi arahan',
      barrierColor: Colors.transparent,
      pageBuilder: (dialogContext, animation, secondaryAnimation) => Material(
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
                padding: EdgeInsets.symmetric(vertical: 24 * scale),
                child: SizedBox(
                  width: width,
                  child: Container(
                    key: const Key('doctor-guide-success-dialog'),
                    padding: EdgeInsets.all(20 * scale),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFFAFAFA)),
                      borderRadius: BorderRadius.circular(32 * scale),
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
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _GuideDialogCloseButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          scale: scale,
                        ),
                        SizedBox(height: 16 * scale),
                        SizedBox(
                          height: 24 * scale,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              message,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppTheme.coralText,
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 16 * scale,
                                fontWeight: FontWeight.w600,
                                height: 24 / 16,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 24 * scale),
                        _GuideButton(
                          key: const Key('doctor-guide-success-done'),
                          label: 'Selesai',
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          scale: scale,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      transitionDuration: const Duration(milliseconds: 180),
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
    );
  }
}

class _InstructionFormDialog extends StatefulWidget {
  const _InstructionFormDialog({
    required this.initialText,
    required this.scale,
    required this.title,
    required this.doneLabel,
  });

  final String initialText;
  final double scale;
  final String title;
  final String doneLabel;

  @override
  State<_InstructionFormDialog> createState() => _InstructionFormDialogState();
}

class _InstructionFormDialogState extends State<_InstructionFormDialog> {
  late final TextEditingController _controller;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;
    return Container(
      key: const Key('doctor-guide-form-dialog'),
      padding: EdgeInsets.fromLTRB(
        20 * scale,
        20 * scale,
        20 * scale,
        20 * scale,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFFAFAFA)),
        borderRadius: BorderRadius.circular(32 * scale),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _GuideDialogCloseButton(
            onPressed: () => Navigator.of(context).pop(),
            scale: scale,
          ),
          SizedBox(height: 20 * scale),
          SizedBox(
            height: 24 * scale,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                widget.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.coralText,
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 16 * scale,
                  fontWeight: FontWeight.w600,
                  height: 24 / 16,
                ),
              ),
            ),
          ),
          SizedBox(height: 20 * scale),
          Container(
            key: const Key('doctor-guide-form-field'),
            height: 156 * scale,
            padding: EdgeInsets.symmetric(
              horizontal: 14 * scale,
              vertical: 14 * scale,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppTheme.border),
              borderRadius: BorderRadius.circular(8 * scale),
              boxShadow: AppTheme.inputShadow,
            ),
            child: TextField(
              key: const Key('doctor-guide-form-input'),
              controller: _controller,
              minLines: null,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(
                color: AppTheme.body,
                fontFamily: AppTheme.fontFamily,
                fontSize: 16 * scale,
                height: 24 / 16,
              ),
              onChanged: (_) {
                if (_errorMessage != null) {
                  setState(() => _errorMessage = null);
                }
              },
              decoration: InputDecoration(
                hintText: 'Tulis arahan untuk pasien',
                hintStyle: TextStyle(
                  color: AppTheme.secondary,
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 16 * scale,
                  height: 24 / 16,
                ),
                isCollapsed: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (_errorMessage case final message?) ...[
            SizedBox(height: 8 * scale),
            Text(
              message,
              key: const Key('doctor-guide-form-error'),
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontFamily: AppTheme.fontFamily,
                fontSize: 12 * scale,
              ),
            ),
          ],
          SizedBox(height: 24 * scale),
          _GuideButton(
            key: const Key('doctor-guide-form-done'),
            label: widget.doneLabel,
            onPressed: _submit,
            scale: scale,
          ),
          SizedBox(height: 10 * scale),
          _GuideButton(
            key: const Key('doctor-guide-form-back'),
            label: 'Kembali',
            onPressed: () => Navigator.of(context).pop(),
            scale: scale,
            secondary: true,
          ),
        ],
      ),
    );
  }

  void _submit() {
    final instruction = _controller.text.trim();
    if (instruction.isEmpty) {
      setState(() => _errorMessage = 'Tulis arahan untuk pasien.');
      return;
    }

    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(instruction);
  }
}

class _GuideDialogCloseButton extends StatelessWidget {
  const _GuideDialogCloseButton({required this.onPressed, required this.scale});

  final VoidCallback onPressed;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('doctor-guide-form-close'),
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16 * scale),
          child: SizedBox(
            width: 32 * scale,
            height: 32 * scale,
            child: Icon(
              Icons.close,
              color: AppTheme.coralText,
              size: 24 * scale,
            ),
          ),
        ),
      ),
    );
  }
}

class _GuidanceCard extends StatelessWidget {
  const _GuidanceCard({
    required this.instruction,
    required this.onCreate,
    required this.onEdit,
    required this.onDelete,
  });

  final String? instruction;
  final VoidCallback onCreate;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scale = _scaleFor(context);
    return AppCard(
      key: const Key('doctor-guide-card'),
      padding: EdgeInsets.all(20 * scale),
      borderRadius: 32 * scale,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Arahan anda',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.ink,
              fontFamily: AppTheme.fontFamily,
              fontSize: 16 * scale,
              fontWeight: FontWeight.w600,
              height: 24 / 16,
            ),
          ),
          SizedBox(height: 24 * scale),
          _GuideButton(
            key: const Key('doctor-guide-create'),
            label: 'Tulis arahan tidak lanjut',
            onPressed: onCreate,
            scale: scale,
          ),
          SizedBox(height: 24 * scale),
          if (instruction case final text?)
            _InstructionCard(
              date: _DoctorGuidePageState._sampleDate,
              instruction: text,
              onEdit: onEdit,
              onDelete: onDelete,
              scale: scale,
            )
          else
            Text(
              'Belum ada arahan untuk pasien ini.',
              key: const Key('doctor-guide-empty'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.muted,
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

class _InstructionCard extends StatelessWidget {
  const _InstructionCard({
    required this.date,
    required this.instruction,
    required this.onEdit,
    required this.onDelete,
    required this.scale,
  });

  final String date;
  final String instruction;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('doctor-guide-instruction'),
      padding: EdgeInsets.symmetric(
        horizontal: 18 * scale,
        vertical: 16 * scale,
      ),
      decoration: BoxDecoration(
        color: AppTheme.selectedSurface,
        border: Border.all(color: AppTheme.coral),
        borderRadius: BorderRadius.circular(24 * scale),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            date,
            style: TextStyle(
              color: AppTheme.coralText,
              fontFamily: AppTheme.fontFamily,
              fontSize: 14 * scale,
              height: 20 / 14,
            ),
          ),
          SizedBox(height: 10 * scale),
          Text(
            instruction,
            key: const Key('doctor-guide-instruction-text'),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppTheme.coralText,
              fontFamily: AppTheme.fontFamily,
              fontSize: 14 * scale,
              height: 20 / 14,
            ),
          ),
          SizedBox(height: 12 * scale),
          _GuideButton(
            key: const Key('doctor-guide-edit'),
            label: 'Edit',
            onPressed: onEdit,
            scale: scale,
          ),
          SizedBox(height: 10 * scale),
          _GuideButton(
            key: const Key('doctor-guide-delete'),
            label: 'Hapus',
            onPressed: onDelete,
            secondary: true,
            scale: scale,
          ),
        ],
      ),
    );
  }
}

class _GuideButton extends StatelessWidget {
  const _GuideButton({
    required this.label,
    required this.onPressed,
    required this.scale,
    this.secondary = false,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final double scale;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48 * scale,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: secondary ? AppTheme.coralLight : AppTheme.coral,
          foregroundColor: secondary ? AppTheme.coralText : Colors.white,
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8 * scale),
          ),
          textStyle: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 16 * scale,
            fontWeight: FontWeight.w600,
            height: 24 / 16,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

double _scaleFor(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  return (width / 390).clamp(0.7, 1.15).toDouble();
}
