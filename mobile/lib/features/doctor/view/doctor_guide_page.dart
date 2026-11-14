import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_brand_header.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty.dart';
import '../../../core/widgets/app_error.dart';
import '../../../core/widgets/app_loading.dart';
import '../../connections/repositories/connection_repository.dart';
import '../repositories/doctor_professional_note_repository.dart';
import '../../mother/repositories/mother_story_repository.dart';
import 'doctor_patient_picker.dart';

class DoctorGuidePage extends ConsumerStatefulWidget {
  const DoctorGuidePage({required this.bottomNavigation, super.key});

  final Widget bottomNavigation;

  @override
  ConsumerState<DoctorGuidePage> createState() => _DoctorGuidePageState();
}

class _DoctorGuidePageState extends ConsumerState<DoctorGuidePage> {
  static const _sampleDate = 'Senin, 12 Agustus 2026';
  static const _sampleInstruction =
      "Lorem Ipsum is simply dummy text of the printing and typesetting "
      "industry. Lorem Ipsum has been the industry's standard dummy text "
      'ever since the 1500s.';

  String _selectedPreviewPatient = 'Ny. Shopia Mudj.';
  String? _selectedConnectionId;
  String? _instruction = _sampleInstruction;

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
    final notes = backendSession && selectedPatient != null
        ? ref.watch(doctorProfessionalNotesProvider(selectedPatient.id))
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
                          _buildPatientPicker(
                            backendSession: backendSession,
                            connections: connections,
                            patients: patients,
                            selectedPatient: selectedPatient,
                          ),
                          SizedBox(height: 36 * scale),
                          _buildGuidance(
                            backendSession: backendSession,
                            connections: connections,
                            selectedPatient: selectedPatient,
                            notes: notes,
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
        keyPrefix: 'doctor-guide',
        value: _selectedPreviewPatient,
        onChanged: (value) => setState(() => _selectedPreviewPatient = value),
      );
    }

    return connections.when(
      data: (_) => patients.isEmpty
          ? const AppEmpty(
              key: Key('doctor-guide-no-patients'),
              title: 'Belum ada pasien terhubung',
              message: 'Ibu yang terhubung akan muncul di sini.',
            )
          : DoctorPatientPicker(
              keyPrefix: 'doctor-guide',
              value: selectedPatient!.id,
              patients: patients,
              onChanged: (value) =>
                  setState(() => _selectedConnectionId = value),
            ),
      loading: () => const SizedBox(
        key: Key('doctor-guide-patients-loading'),
        height: 100,
        child: AppLoading(message: 'Memuat pasien...'),
      ),
      error: (error, stackTrace) => AppError(
        key: const Key('doctor-guide-patients-error'),
        message: connectionFailureMessage(error),
        onRetry: () => ref.invalidate(activeConnectionsProvider),
      ),
    );
  }

  Widget _buildGuidance({
    required bool backendSession,
    required AsyncValue<List<ConnectionPerson>?> connections,
    required ConnectionPerson? selectedPatient,
    required AsyncValue<List<DoctorProfessionalNote>>? notes,
  }) {
    if (!backendSession) {
      final items = _instruction == null
          ? const <_GuidanceItem>[]
          : [
              _GuidanceItem(
                id: 'preview',
                content: _instruction!,
                date: _sampleDate,
              ),
            ];
      return _GuidanceCard(
        items: items,
        onCreate: () => _editInstruction(),
        onEdit: (item) => _editInstruction(item: item),
        onDelete: (item) => _deleteInstruction(item: item),
      );
    }

    if (connections.isLoading ||
        connections.hasError ||
        selectedPatient == null ||
        notes == null) {
      return const SizedBox.shrink();
    }

    return notes.when(
      data: (items) => _GuidanceCard(
        items: [
          for (final note in items)
            _GuidanceItem(
              id: note.id,
              content: note.content,
              date: formatStoryDate(DateTime.parse(note.updatedAt).toLocal()),
            ),
        ],
        onCreate: () => _editInstruction(connectionId: selectedPatient.id),
        onEdit: (item) =>
            _editInstruction(connectionId: selectedPatient.id, item: item),
        onDelete: (item) =>
            _deleteInstruction(connectionId: selectedPatient.id, item: item),
      ),
      loading: () => const SizedBox(
        key: Key('doctor-guide-notes-loading'),
        height: 100,
        child: AppLoading(message: 'Memuat arahan...'),
      ),
      error: (error, stackTrace) => AppError(
        key: const Key('doctor-guide-notes-error'),
        message: connectionFailureMessage(error),
        onRetry: () =>
            ref.invalidate(doctorProfessionalNotesProvider(selectedPatient.id)),
      ),
    );
  }

  Future<void> _editInstruction({
    String? connectionId,
    _GuidanceItem? item,
  }) async {
    final isEditing = item != null;
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
                      initialText: item?.content ?? '',
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
      if (connectionId == null) {
        setState(() => _instruction = instruction);
      } else {
        final token = ref.read(backendTokenProvider);
        if (token == null) {
          _showSessionExpired();
          return;
        }
        try {
          final repository = ref.read(doctorProfessionalNoteRepositoryProvider);
          if (item == null) {
            await repository.createNote(
              accessToken: token,
              connectionId: connectionId,
              content: instruction,
            );
          } else {
            await repository.updateNote(
              accessToken: token,
              noteId: item.id,
              content: instruction,
            );
          }
          ref.invalidate(doctorProfessionalNotesProvider(connectionId));
        } catch (error) {
          if (mounted) _showFailure(error);
          return;
        }
      }
      if (!mounted) return;
      await _showCompletionDialog(
        context,
        message: isEditing
            ? 'Arahan berhasil diperbarui!'
            : 'Arahan berhasil diberikan ke pasien!',
      );
    }
  }

  Future<void> _deleteInstruction({
    String? connectionId,
    _GuidanceItem? item,
  }) async {
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
      if (connectionId == null || item == null) {
        setState(() => _instruction = null);
      } else {
        final token = ref.read(backendTokenProvider);
        if (token == null) {
          _showSessionExpired();
          return;
        }
        try {
          await ref
              .read(doctorProfessionalNoteRepositoryProvider)
              .deleteNote(accessToken: token, noteId: item.id);
          ref.invalidate(doctorProfessionalNotesProvider(connectionId));
        } catch (error) {
          if (mounted) _showFailure(error);
          return;
        }
      }
      if (!mounted) return;
      await _showCompletionDialog(context, message: 'Arahan berhasil dihapus!');
    }
  }

  void _showFailure(Object error) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(connectionFailureMessage(error))));
  }

  void _showSessionExpired() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Sesi login telah berakhir. Silakan masuk kembali.'),
        ),
      );
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
                      border: Border.all(color: AppTheme.white3),
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
        border: Border.all(color: AppTheme.white3),
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
    required this.items,
    required this.onCreate,
    required this.onEdit,
    required this.onDelete,
  });

  final List<_GuidanceItem> items;
  final VoidCallback onCreate;
  final ValueChanged<_GuidanceItem> onEdit;
  final ValueChanged<_GuidanceItem> onDelete;

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
          if (items.isEmpty)
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
            )
          else
            for (var index = 0; index < items.length; index++) ...[
              _InstructionCard(
                item: items[index],
                onEdit: () => onEdit(items[index]),
                onDelete: () => onDelete(items[index]),
                scale: scale,
              ),
              if (index < items.length - 1) SizedBox(height: 20 * scale),
            ],
        ],
      ),
    );
  }
}

class _GuidanceItem {
  const _GuidanceItem({
    required this.id,
    required this.content,
    required this.date,
  });

  final String id;
  final String content;
  final String date;
}

class _InstructionCard extends StatelessWidget {
  const _InstructionCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
    required this.scale,
  });

  final _GuidanceItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('doctor-guide-instruction-${item.id}'),
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
            item.date,
            style: TextStyle(
              color: AppTheme.coralText,
              fontFamily: AppTheme.fontFamily,
              fontSize: 14 * scale,
              height: 20 / 14,
            ),
          ),
          SizedBox(height: 10 * scale),
          Text(
            item.content,
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
        style: AppButtonStyles.forType(
          secondary ? AppButtonType.secondary : AppButtonType.primary,
        ).merge(
          FilledButton.styleFrom(
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
