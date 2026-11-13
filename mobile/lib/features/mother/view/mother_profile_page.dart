import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_brand_header.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_profile_avatar.dart';
import '../../../core/widgets/app_submit_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../auth/controller/auth_controller.dart';
import '../../../services/backend_api.dart';
import '../repositories/connection_repository.dart';
import '../repositories/mother_story_repository.dart';
import 'mother_navigation.dart';

const _previewCompanionCode = 'ENZOKULIN';

class MotherProfilePage extends ConsumerStatefulWidget {
  const MotherProfilePage({super.key});

  @override
  ConsumerState<MotherProfilePage> createState() => _MotherProfilePageState();
}

class _MotherProfilePageState extends ConsumerState<MotherProfilePage> {
  final Map<String, Map<String, bool>> _permissions = {
    'enzokulin': {'weekly-summary': true},
    'indra': {'weekly-summary': true, 'epds': true, 'journal': true},
  };
  final List<_CompanionProfile> _companions = [..._defaultCompanions];

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).asData?.value.session?.user;
    final name = user?.name?.trim();
    final email = user?.email.trim();
    final live = ref.watch(backendTokenProvider) != null;
    final codeAsync = live ? ref.watch(motherCompanionCodeProvider) : null;
    final connectionsAsync = live ? ref.watch(motherConnectionsProvider) : null;

    final code = codeAsync == null
        ? 'K4DSTP'
        : codeAsync.when(
            data: (invite) => invite?.code ?? '-',
            loading: () => '…',
            error: (error, stackTrace) => 'gagal dimuat',
          );
    final companions = connectionsAsync == null
        ? _companions
        : [
            for (final person
                in connectionsAsync.asData?.value ?? const <ConnectionPerson>[])
              _CompanionProfile(
                id: person.id,
                name: person.name,
                email: person.roleLabel,
                // Aturan berbagi tetap (hanya ringkasan mingguan): tidak ada toggle.
                permissions: const [],
              ),
          ];
    final permissions = connectionsAsync == null
        ? _permissions
        : {for (final companion in companions) companion.id: <String, bool>{}};

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
            double scaled(double value) => value * scale;

            return Center(
              child: SizedBox(
                width: width,
                child: DefaultTextStyle(
                  style: const TextStyle(fontFamily: AppTheme.fontFamily),
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView(
                          key: const Key('mother-profile-scroll'),
                          padding: EdgeInsets.fromLTRB(
                            scaled(24),
                            scaled(20),
                            scaled(24),
                            scaled(34),
                          ),
                          children: [
                            const AppBrandHeader(),
                            SizedBox(height: scaled(36)),
                            _ProfileInformationCard(
                              name: name == null || name.isEmpty
                                  ? 'Jane Doe'
                                  : name,
                              email: email == null || email.isEmpty
                                  ? 'janedoe@gmail.com'
                                  : email,
                              scale: scaled,
                              code: code,
                              onEditProfile: () =>
                                  context.push('/mother/profile/edit'),
                              onAddCompanion: _showAddCompanionFlow,
                            ),
                            SizedBox(height: scaled(36)),
                            _CompanionPermissionsCard(
                              scale: scaled,
                              title: live ? 'Orang yang terhubung' : 'Pilih data yang boleh dilihat orang yang terhubung',
                              subtitle: live
                                  ? 'Orang yang terhubung hanya dapat melihat '
                                        'ringkasan mingguan Anda. Jurnal, mood '
                                        'harian, dan hasil EPDS tetap pribadi.'
                                  : null,
                              companions: companions,
                              permissions: permissions,
                              onPermissionChanged: _setPermission,
                            ),
                            SizedBox(height: scaled(36)),
                            SizedBox(
                              height: scaled(48),
                              child: AppSubmitButton(
                                key: const Key('mother-profile-logout'),
                                label: 'Keluar',
                                onPressed: _logout,
                                textStyle: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: scaled(16),
                                  fontWeight: FontWeight.w600,
                                  height: 24 / 16,
                                ),
                                buttonStyle: FilledButton.styleFrom(
                                  backgroundColor: AppTheme.coral,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: scaled(20),
                                    vertical: scaled(12),
                                  ),
                                  elevation: 1,
                                  shadowColor: const Color(0x0D101828),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      scaled(8),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      MotherNavigationBar(
                        selectedTab: MotherNavigationTab.profile,
                        onHomeTap: () => context.go('/mother'),
                        onCalendarTap: () => context.go('/mother/calendar'),
                        onChatTap: () => context.go('/mother/chat'),
                        onMeditationTap: () => context.go('/mother/meditation'),
                        onProfileTap: () => context.go('/mother/profile'),
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

  void _setPermission(String companionId, String permission, bool value) {
    setState(() {
      _permissions[companionId]![permission] = value;
    });
  }

  Future<void> _showAddCompanionFlow() async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Tutup tambah pendamping',
      barrierColor: Colors.transparent,
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final screenWidth = MediaQuery.sizeOf(dialogContext).width;
        final scaleFactor = (screenWidth / 390).clamp(0.7, 1.15).toDouble();
        double scale(double value) => value * scaleFactor;
        final width = math.min(scale(342), screenWidth - scale(40));
        return Material(
          type: MaterialType.transparency,
          child: Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                onTap: () => Navigator.of(dialogContext).pop(),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
                  child: const ColoredBox(color: Color(0x1A000000)),
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(vertical: scale(24)),
                  child: Transform.translate(
                    offset: Offset(scale(4), scale(-0.5)),
                    child: SizedBox(
                      width: width,
                      child: _MotherProfileCompanionDialog(
                        scale: scale,
                        isAlreadyConnected: _companions.any(
                          (companion) => companion.id == _previewCompanion.id,
                        ),
                        onClose: () => Navigator.of(dialogContext).pop(),
                        onCompanionConfirmed: _addPreviewCompanion,
                        onShareCode: _copyCompanionCode,
                        onRedeem: ref.read(backendTokenProvider) == null
                            ? null
                            : _redeemCode,
                      ),
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
  }

  void _addPreviewCompanion() {
    if (_companions.any((companion) => companion.id == _previewCompanion.id)) {
      return;
    }
    setState(() {
      _companions.add(_previewCompanion);
      _permissions[_previewCompanion.id] = {
        'weekly-summary': false,
        'epds': false,
        'journal': false,
      };
    });
  }

  Future<void> _copyCompanionCode() async {
    final code = ref.read(backendTokenProvider) == null
        ? 'K4DSTP'
        : ref.read(motherCompanionCodeProvider).asData?.value?.code;
    if (code == null) return;
    await Clipboard.setData(ClipboardData(text: code));
  }

  /// Mengembalikan pesan error, atau null kalau berhasil terhubung.
  Future<String?> _redeemCode(String code) async {
    final token = ref.read(backendTokenProvider);
    if (token == null) return 'Sesi login tidak valid. Silakan masuk kembali.';
    try {
      await ref
          .read(connectionRepositoryProvider)
          .redeem(accessToken: token, code: code);
      ref.invalidate(motherConnectionsProvider);
      return null;
    } on Exception catch (error) {
      return switch (error) {
        BackendApiException(statusCode: 404) =>
          'Kode tidak valid atau sudah kedaluwarsa (kode berlaku 1 jam).',
        BackendApiException(statusCode: 400) =>
          'Format kode tidak dikenali. Periksa lagi kodenya.',
        BackendApiException(statusCode: 403) =>
          'Kode ini bukan untuk akun ibu.',
        BackendApiException(
          message: 'This mother already has a professional',
        ) =>
          'Anda sudah terhubung dengan tenaga kesehatan.',
        BackendApiException(statusCode: 409) =>
          'Pendamping ini sudah terhubung dengan ibu lain.',
        BackendApiException(statusCode: 401) =>
          'Sesi login telah berakhir. Silakan masuk kembali.',
        BackendApiException(:final message) => message,
        ApiNetworkException(:final message) => message,
        ApiConfigurationException(:final message) => message,
        _ => 'Respons server tidak dapat dibaca. Coba lagi.',
      };
    }
  }

  void _logout() {
    ref.read(authControllerProvider.notifier).logout();
    context.go('/roles');
  }
}

class _ProfileInformationCard extends StatelessWidget {
  const _ProfileInformationCard({
    required this.name,
    required this.email,
    required this.code,
    required this.scale,
    required this.onEditProfile,
    required this.onAddCompanion,
  });

  final String name;
  final String email;
  final String code;
  final double Function(double) scale;
  final VoidCallback onEditProfile;
  final VoidCallback onAddCompanion;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: const Key('mother-profile-information-card'),
      padding: EdgeInsets.all(scale(20)),
      borderRadius: scale(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              AppProfileAvatar(
                key: const Key('mother-profile-avatar'),
                assetPath: 'assets/images/mother_home/avatar-a.png',
                size: scale(85),
                semanticLabel: 'Foto profil $name',
              ),
              SizedBox(height: scale(16)),
              Text(
                name,
                key: const Key('mother-profile-name'),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppTheme.ink,
                  fontSize: scale(20),
                  fontWeight: FontWeight.w600,
                  height: 30 / 20,
                ),
              ),
              SizedBox(height: scale(4)),
              Text(
                email,
                key: const Key('mother-profile-email'),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppTheme.muted,
                  fontSize: scale(16),
                  height: 24 / 16,
                ),
              ),
              SizedBox(height: scale(16)),
              SizedBox(
                height: scale(24),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Kode Pendampingan : $code',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.muted,
                      fontSize: scale(16),
                      height: 24 / 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: scale(16)),
          _ProfileActionButton(
            key: const Key('mother-profile-edit'),
            label: 'Ubah Profil',
            scale: scale,
            onPressed: onEditProfile,
          ),
          SizedBox(height: scale(16)),
          _ProfileActionButton(
            key: const Key('mother-profile-add-companion'),
            label: 'Tambah Pendamping',
            scale: scale,
            secondary: true,
            onPressed: onAddCompanion,
          ),
        ],
      ),
    );
  }
}

class _ProfileActionButton extends StatelessWidget {
  const _ProfileActionButton({
    required this.label,
    required this.scale,
    required this.onPressed,
    this.secondary = false,
    super.key,
  });

  final String label;
  final double Function(double) scale;
  final VoidCallback onPressed;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: scale(48),
      child: AppSubmitButton(
        label: label,
        onPressed: onPressed,
        textStyle: TextStyle(
          fontFamily: AppTheme.fontFamily,
          color: secondary ? AppTheme.coralText : Colors.white,
          fontSize: scale(16),
          fontWeight: FontWeight.w600,
          height: 24 / 16,
        ),
        buttonStyle: FilledButton.styleFrom(
          backgroundColor: secondary ? AppTheme.coralLight : AppTheme.coral,
          foregroundColor: secondary ? AppTheme.coralText : Colors.white,
          padding: EdgeInsets.symmetric(
            horizontal: scale(20),
            vertical: scale(12),
          ),
          elevation: 1,
          shadowColor: const Color(0x0D101828),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(scale(8)),
          ),
        ),
      ),
    );
  }
}

enum _CompanionDialogStep { enterCode, confirm, success }

class _MotherProfileCompanionDialog extends StatefulWidget {
  const _MotherProfileCompanionDialog({
    required this.scale,
    required this.isAlreadyConnected,
    required this.onClose,
    required this.onCompanionConfirmed,
    required this.onShareCode,
    this.onRedeem,
  });

  /// Login sungguhan: tukar kode ke backend. null = mode preview.
  final Future<String?> Function(String code)? onRedeem;
  final double Function(double) scale;
  final bool isAlreadyConnected;
  final VoidCallback onClose;
  final VoidCallback onCompanionConfirmed;
  final Future<void> Function() onShareCode;

  @override
  State<_MotherProfileCompanionDialog> createState() =>
      _MotherProfileCompanionDialogState();
}

class _MotherProfileCompanionDialogState
    extends State<_MotherProfileCompanionDialog> {
  final TextEditingController _codeController = TextEditingController();
  _CompanionDialogStep _step = _CompanionDialogStep.enterCode;
  String? _errorMessage;
  String? _statusMessage;
  bool _submitting = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;
    final content = switch (_step) {
      _CompanionDialogStep.enterCode => _buildCodeForm(scale),
      _CompanionDialogStep.confirm => _buildConfirmation(scale),
      _CompanionDialogStep.success => _buildSuccess(scale),
    };

    return Container(
      key: const Key('mother-profile-companion-dialog'),
      padding: EdgeInsets.all(scale(20)),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFFAFAFA)),
        borderRadius: BorderRadius.circular(scale(32)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A0A0D12),
            offset: Offset(0, 1),
            blurRadius: 3,
          ),
          BoxShadow(
            color: Color(0x0F0A0D12),
            offset: Offset(0, 1),
            blurRadius: 2,
          ),
        ],
      ),
      child: content,
    );
  }

  Widget _buildCodeForm(double Function(double) scale) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DialogCloseButton(scale: scale, onPressed: widget.onClose),
        SizedBox(height: scale(24)),
        SizedBox(
          height: scale(24),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Tambahkan Pendamping Anda',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                color: AppTheme.coralText,
                fontSize: scale(16),
                fontWeight: FontWeight.w600,
                height: 24 / 16,
              ),
            ),
          ),
        ),
        SizedBox(height: scale(24)),
        AppTextField(
          key: const Key('mother-profile-companion-code-field'),
          controller: _codeController,
          label: 'Kode Pendampingan (Pendamping/Ahli)',
          hintText: 'Masukan kode',
          inputHeight: scale(44),
          fitLabelToWidth: true,
          labelStyle: TextStyle(
            fontFamily: AppTheme.fontFamily,
            color: AppTheme.body,
            fontSize: scale(14),
            fontWeight: FontWeight.w500,
            height: 20 / 14,
          ),
          textStyle: TextStyle(
            fontFamily: AppTheme.fontFamily,
            color: AppTheme.body,
            fontSize: scale(16),
            height: 24 / 16,
          ),
          hintStyle: TextStyle(
            fontFamily: AppTheme.fontFamily,
            color: AppTheme.secondary,
            fontSize: scale(16),
            height: 24 / 16,
          ),
          textInputAction: TextInputAction.done,
          autocorrect: false,
          textCapitalization: TextCapitalization.characters,
          onFieldSubmitted: (_) => _continueWithCode(),
        ),
        if (_errorMessage != null) ...[
          SizedBox(height: scale(6)),
          Text(
            _errorMessage!,
            key: const Key('mother-profile-companion-code-error'),
            style: TextStyle(
              color: const Color(0xFFD92D20),
              fontFamily: AppTheme.fontFamily,
              fontSize: scale(12),
              height: 16 / 12,
            ),
          ),
        ],
        SizedBox(height: scale(24)),
        Column(
          children: [
            _ProfileActionButton(
              key: const Key('mother-profile-companion-code-next'),
              label: 'Lanjut',
              scale: scale,
              onPressed: _continueWithCode,
            ),
            SizedBox(height: scale(10)),
            _ProfileActionButton(
              key: const Key('mother-profile-companion-code-share'),
              label: 'Bagikan Kode Pendampingan',
              scale: scale,
              secondary: true,
              onPressed: _shareCode,
            ),
          ],
        ),
        if (_statusMessage != null) ...[
          SizedBox(height: scale(8)),
          Text(
            _statusMessage!,
            key: const Key('mother-profile-companion-code-copied'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              color: AppTheme.coralText,
              fontSize: scale(12),
              height: 16 / 12,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildConfirmation(double Function(double) scale) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DialogCloseButton(scale: scale, onPressed: widget.onClose),
        SizedBox(height: scale(24)),
        SizedBox(
          height: scale(48),
          child: Center(
            child: Text(
              'Apakah ini pengguna yang ingin mendampingi anda?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.coralText,
                fontFamily: AppTheme.fontFamily,
                fontSize: scale(16),
                fontWeight: FontWeight.w600,
                height: 24 / 16,
              ),
            ),
          ),
        ),
        SizedBox(height: scale(24)),
        _CompanionConfirmationTile(scale: scale),
        SizedBox(height: scale(24)),
        Column(
          children: [
            _ProfileActionButton(
              key: const Key('mother-profile-companion-confirm'),
              label: 'Ya',
              scale: scale,
              onPressed: () {
                widget.onCompanionConfirmed();
                setState(() {
                  _step = _CompanionDialogStep.success;
                  _errorMessage = null;
                });
              },
            ),
            SizedBox(height: scale(10)),
            _ProfileActionButton(
              key: const Key('mother-profile-companion-back'),
              label: 'Kembali',
              scale: scale,
              secondary: true,
              onPressed: () => setState(() {
                _step = _CompanionDialogStep.enterCode;
                _errorMessage = null;
              }),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSuccess(double Function(double) scale) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DialogCloseButton(scale: scale, onPressed: widget.onClose),
        SizedBox(height: scale(24)),
        SizedBox(
          height: scale(48),
          child: Center(
            child: Text(
              'Pengguna berhasil menjadi pendamping anda!',
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                color: AppTheme.coralText,
                fontFamily: AppTheme.fontFamily,
                fontSize: scale(16),
                fontWeight: FontWeight.w600,
                height: 24 / 16,
              ),
            ),
          ),
        ),
        SizedBox(height: scale(24)),
        _ProfileActionButton(
          key: const Key('mother-profile-companion-success-done'),
          label: 'Selesai',
          scale: scale,
          onPressed: widget.onClose,
        ),
      ],
    );
  }

  Future<void> _continueWithCode() async {
    if (_submitting) return;
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() {
        _errorMessage = 'Masukkan kode pendampingan.';
        _statusMessage = null;
      });
      return;
    }

    final redeem = widget.onRedeem;
    if (redeem != null) {
      // Backend langsung menghubungkan saat kode ditukar, jadi langsung ke layar sukses.
      setState(() {
        _submitting = true;
        _errorMessage = null;
        _statusMessage = null;
      });
      final error = await redeem(code);
      if (!mounted) return;
      setState(() {
        _submitting = false;
        if (error == null) {
          _step = _CompanionDialogStep.success;
        } else {
          _errorMessage = error;
        }
      });
      return;
    }

    if (widget.isAlreadyConnected) {
      setState(() {
        _errorMessage = 'Pendamping ini sudah terhubung.';
        _statusMessage = null;
      });
      return;
    }
    if (code != _previewCompanionCode) {
      setState(() {
        _errorMessage = 'Kode tidak dikenali dalam mode pratinjau.';
        _statusMessage = null;
      });
      return;
    }
    setState(() {
      _step = _CompanionDialogStep.confirm;
      _errorMessage = null;
      _statusMessage = null;
    });
  }

  Future<void> _shareCode() async {
    await widget.onShareCode();
    if (!mounted) return;
    setState(() {
      _statusMessage = 'Kode pendampingan disalin.';
    });
  }
}

class _DialogCloseButton extends StatelessWidget {
  const _DialogCloseButton({required this.scale, required this.onPressed});

  final double Function(double) scale;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: scale(24),
        height: scale(24),
        child: IconButton(
          key: const Key('mother-profile-companion-close'),
          onPressed: onPressed,
          tooltip: 'Tutup',
          padding: EdgeInsets.zero,
          constraints: BoxConstraints.tightFor(
            width: scale(24),
            height: scale(24),
          ),
          icon: SvgPicture.asset(
            'assets/images/mother_home/close.svg',
            width: scale(24),
            height: scale(24),
          ),
        ),
      ),
    );
  }
}

class _CompanionConfirmationTile extends StatelessWidget {
  const _CompanionConfirmationTile({required this.scale});

  final double Function(double) scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('mother-profile-companion-preview'),
      height: scale(72),
      padding: EdgeInsets.all(scale(8)),
      decoration: BoxDecoration(
        color: AppTheme.selectedSurface,
        borderRadius: BorderRadius.circular(scale(24)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: scale(56),
            height: scale(56),
            child: ClipOval(
              child: Image.asset(
                'assets/images/mother_profile/man-1.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          SizedBox(width: scale(16)),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _previewCompanion.name,
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
                SizedBox(height: scale(4)),
                Text(
                  _previewCompanion.email,
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
        ],
      ),
    );
  }
}

class _CompanionPermissionsCard extends StatelessWidget {
  const _CompanionPermissionsCard({
    required this.scale,
    required this.title,
    this.subtitle,
    required this.companions,
    required this.permissions,
    required this.onPermissionChanged,
  });

  final double Function(double) scale;
  final String title;
  final String? subtitle;
  final List<_CompanionProfile> companions;
  final Map<String, Map<String, bool>> permissions;
  final void Function(String companionId, String permission, bool value)
  onPermissionChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: const Key('mother-profile-permissions-card'),
      padding: EdgeInsets.all(scale(20)),
      borderRadius: scale(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            maxLines: 2,
            style: TextStyle(
              color: const Color(0xFF252B37),
              fontSize: scale(16),
              fontWeight: FontWeight.w600,
              height: 24 / 16,
            ),
          ),
          if (subtitle case final text?) ...[
            SizedBox(height: scale(8)),
            Text(
              text,
              key: const Key('mother-profile-sharing-rule'),
              style: TextStyle(
                color: AppTheme.muted,
                fontSize: scale(14),
                height: 20 / 14,
              ),
            ),
          ],
          SizedBox(height: scale(24)),
          if (companions.isEmpty)
            Text(
              'Belum ada pendamping yang terhubung.',
              key: const Key('mother-profile-no-companions'),
              style: TextStyle(
                color: AppTheme.muted,
                fontSize: scale(14),
                height: 20 / 14,
              ),
            ),
          for (var index = 0; index < companions.length; index++) ...[
            _CompanionPermissionCard(
              companion: companions[index],
              scale: scale,
              permissions: permissions[companions[index].id]!,
              onPermissionChanged: (permission, value) =>
                  onPermissionChanged(companions[index].id, permission, value),
            ),
            if (index < companions.length - 1) SizedBox(height: scale(24)),
          ],
        ],
      ),
    );
  }
}

class _CompanionPermissionCard extends StatelessWidget {
  const _CompanionPermissionCard({
    required this.companion,
    required this.scale,
    required this.permissions,
    required this.onPermissionChanged,
  });

  final _CompanionProfile companion;
  final double Function(double) scale;
  final Map<String, bool> permissions;
  final void Function(String permission, bool value) onPermissionChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('mother-profile-companion-${companion.id}'),
      padding: EdgeInsets.all(scale(16)),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFFAFAFA)),
        borderRadius: BorderRadius.circular(scale(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.all(scale(8)),
            decoration: BoxDecoration(
              color: AppTheme.selectedSurface,
              borderRadius: BorderRadius.circular(scale(24)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: scale(56),
                  height: scale(56),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/mother_profile/man-1.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                SizedBox(width: scale(16)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        companion.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.coralText,
                          fontSize: scale(16),
                          fontWeight: FontWeight.w600,
                          height: 24 / 16,
                        ),
                      ),
                      SizedBox(height: scale(4)),
                      Text(
                        companion.email,
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
              ],
            ),
          ),
          SizedBox(height: scale(16)),
          for (
            var index = 0;
            index < companion.permissions.length;
            index++
          ) ...[
            _PermissionRow(
              companionId: companion.id,
              permission: companion.permissions[index],
              scale: scale,
              value: permissions[companion.permissions[index].id] ?? false,
              onChanged: (value) =>
                  onPermissionChanged(companion.permissions[index].id, value),
            ),
            if (index < companion.permissions.length - 1)
              SizedBox(height: scale(16)),
          ],
        ],
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.companionId,
    required this.permission,
    required this.scale,
    required this.value,
    required this.onChanged,
  });

  final String companionId;
  final _PrivacyPermission permission;
  final double Function(double) scale;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: scale(20),
      child: Row(
        children: [
          Expanded(
            child: Text(
              permission.label,
              style: TextStyle(
                color: const Color(0xFF252B37),
                fontSize: scale(14),
                fontWeight: FontWeight.w500,
                height: 20 / 14,
              ),
            ),
          ),
          Semantics(
            button: true,
            toggled: value,
            label: '${permission.label} untuk ${_companionName(companionId)}',
            child: InkWell(
              key: Key('mother-profile-toggle-$companionId-${permission.id}'),
              onTap: () => onChanged(!value),
              borderRadius: BorderRadius.circular(scale(10)),
              child: SizedBox(
                width: scale(36),
                height: scale(20),
                child: SvgPicture.asset(
                  value
                      ? 'assets/images/mother_profile/toggle-on.svg'
                      : 'assets/images/mother_profile/toggle-off.svg',
                  width: scale(36),
                  height: scale(20),
                  key: Key(
                    'mother-profile-toggle-$companionId-${permission.id}-${value ? 'on' : 'off'}',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _companionName(String companionId) => switch (companionId) {
  'enzokulin' => 'Tn. Enzokulin',
  'indra' => 'dr. Indra Waspada',
  'preview-enzokulin-samsidan' => _previewCompanion.name,
  _ => '',
};

class _CompanionProfile {
  const _CompanionProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.permissions,
  });

  final String id;
  final String name;
  final String email;
  final List<_PrivacyPermission> permissions;
}

class _PrivacyPermission {
  const _PrivacyPermission({required this.id, required this.label});

  final String id;
  final String label;
}

const _defaultCompanions = <_CompanionProfile>[
  _CompanionProfile(
    id: 'enzokulin',
    name: 'Tn. Enzokulin',
    email: 'enzo***@gmail.com',
    permissions: [
      _PrivacyPermission(id: 'weekly-summary', label: 'Ringkasan mingguan'),
    ],
  ),
  _CompanionProfile(
    id: 'indra',
    name: 'dr. Indra Waspada',
    email: 'indrax@gmail.com',
    permissions: [
      _PrivacyPermission(id: 'weekly-summary', label: 'Ringkasan mingguan'),
      _PrivacyPermission(id: 'epds', label: 'Hasil EPDS'),
      _PrivacyPermission(id: 'journal', label: 'Jurnal pribadi'),
    ],
  ),
];

const _previewCompanion = _CompanionProfile(
  id: 'preview-enzokulin-samsidan',
  name: 'Tn. Enzokulin Samsidan',
  email: 'samsidan@gmail.com',
  permissions: [
    _PrivacyPermission(id: 'weekly-summary', label: 'Ringkasan mingguan'),
    _PrivacyPermission(id: 'epds', label: 'Hasil EPDS'),
    _PrivacyPermission(id: 'journal', label: 'Jurnal pribadi'),
  ],
);
