import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_brand_header.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_profile_avatar.dart';
import '../../../core/widgets/app_submit_button.dart';
import '../../auth/controller/auth_controller.dart';
import '../../connections/repositories/connection_repository.dart';

class DoctorProfilePage extends ConsumerStatefulWidget {
  const DoctorProfilePage({required this.bottomNavigation, super.key});

  final Widget bottomNavigation;

  @override
  ConsumerState<DoctorProfilePage> createState() => _DoctorProfilePageState();
}

class _DoctorProfilePageState extends ConsumerState<DoctorProfilePage> {
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).asData?.value.session?.user;
    final userName = user?.name?.trim();
    final email = user?.email.trim();
    final isPreview = ref.watch(backendTokenProvider) == null;
    final inviteCodes = ref.watch(liveInviteCodesProvider);
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
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        key: const Key('doctor-profile-scroll'),
                        padding: EdgeInsets.fromLTRB(
                          scaled(24),
                          scaled(20),
                          scaled(24),
                          scaled(34),
                        ),
                        children: [
                          const AppBrandHeader(),
                          SizedBox(height: scaled(36)),
                          _DoctorProfileInformationCard(
                            name: userName == null || userName.isEmpty
                                ? 'Jane Doe'
                                : userName,
                            email: email == null || email.isEmpty
                                ? 'janedoe@gmail.com'
                                : email,
                            inviteCodes: inviteCodes,
                            isPreview: isPreview,
                            scale: scaled,
                            onEdit: () => context.push('/doctor/profile/edit'),
                            onAddPatient: () =>
                                context.push('/doctor/connections'),
                            onRetryInviteCodes: () =>
                                ref.invalidate(liveInviteCodesProvider),
                            onCopyInviteCode: (code) => _copyInviteCode(code),
                          ),
                          SizedBox(height: scaled(36)),
                          SizedBox(
                            height: scaled(48),
                            child: AppSubmitButton(
                              key: const Key('doctor-profile-logout'),
                              label: 'Keluar',
                              onPressed: _logout,
                              textStyle: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: scaled(16),
                                fontWeight: FontWeight.w600,
                                height: 24 / 16,
                              ),
                              buttonStyle: FilledButton.styleFrom(
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

  void _showNotice(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _copyInviteCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) _showNotice('Kode undangan disalin.');
  }

  Future<void> _logout() async {
    await ref.read(authControllerProvider.notifier).logout();
    if (mounted) context.go('/roles');
  }
}

class _DoctorProfileInformationCard extends StatelessWidget {
  const _DoctorProfileInformationCard({
    required this.name,
    required this.email,
    required this.inviteCodes,
    required this.isPreview,
    required this.scale,
    required this.onEdit,
    required this.onAddPatient,
    required this.onRetryInviteCodes,
    required this.onCopyInviteCode,
  });

  final String name;
  final String email;
  final AsyncValue<List<InviteCode>?> inviteCodes;
  final bool isPreview;
  final double Function(double) scale;
  final VoidCallback onEdit;
  final VoidCallback onAddPatient;
  final VoidCallback onRetryInviteCodes;
  final ValueChanged<String> onCopyInviteCode;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: const Key('doctor-profile-information-card'),
      padding: EdgeInsets.all(scale(20)),
      borderRadius: scale(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: AppProfileAvatar(
              key: const Key('doctor-profile-avatar'),
              assetPath: 'assets/images/doctor/doctor-avatar.png',
              size: scale(85),
              semanticLabel: 'Foto profil $name',
            ),
          ),
          SizedBox(height: scale(16)),
          Text(
            name,
            key: const Key('doctor-profile-name'),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppTheme.ink,
              fontFamily: AppTheme.fontFamily,
              fontSize: scale(20),
              fontWeight: FontWeight.w600,
              height: 30 / 20,
            ),
          ),
          SizedBox(height: scale(4)),
          Text(
            email,
            key: const Key('doctor-profile-email'),
            textAlign: TextAlign.center,
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
          _DoctorInviteCode(
            codes: inviteCodes,
            isPreview: isPreview,
            scale: scale,
            onCopy: onCopyInviteCode,
            onRetry: onRetryInviteCodes,
          ),
          SizedBox(height: scale(16)),
          _ProfileActionButton(
            key: const Key('doctor-profile-edit'),
            label: 'Ubah Profil',
            scale: scale,
            onPressed: onEdit,
          ),
          SizedBox(height: scale(16)),
          _ProfileActionButton(
            key: const Key('doctor-profile-add-patient'),
            label: 'Tambah Pasien',
            scale: scale,
            onPressed: onAddPatient,
            secondary: true,
          ),
        ],
      ),
    );
  }
}

class _DoctorInviteCode extends StatelessWidget {
  const _DoctorInviteCode({
    required this.codes,
    required this.isPreview,
    required this.scale,
    required this.onCopy,
    required this.onRetry,
  });

  final AsyncValue<List<InviteCode>?> codes;
  final bool isPreview;
  final double Function(double) scale;
  final ValueChanged<String> onCopy;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (isPreview) return _code(context, 'AIS128');
    return codes.when(
      data: (items) {
        final code = items?.firstOrNull?.code;
        if (code == null) {
          return Text(
            'Belum ada kode undangan aktif',
            key: const Key('doctor-profile-no-invite-code'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.muted,
              fontFamily: AppTheme.fontFamily,
              fontSize: scale(14),
              height: 20 / 14,
            ),
          );
        }
        return _code(context, code);
      },
      loading: () => Text(
        'Memuat kode undangan...',
        key: const Key('doctor-profile-invite-code-loading'),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppTheme.muted,
          fontFamily: AppTheme.fontFamily,
          fontSize: scale(14),
          height: 20 / 14,
        ),
      ),
      error: (error, stackTrace) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              connectionFailureMessage(error),
              key: const Key('doctor-profile-invite-code-error'),
              style: TextStyle(
                color: AppTheme.muted,
                fontFamily: AppTheme.fontFamily,
                fontSize: scale(12),
                height: 16 / 12,
              ),
            ),
          ),
          TextButton(
            key: const Key('doctor-profile-invite-code-retry'),
            onPressed: onRetry,
            child: const Text('Coba lagi'),
          ),
        ],
      ),
    );
  }

  Widget _code(BuildContext context, String code) {
    return Container(
      key: const Key('doctor-profile-invite-code'),
      padding: EdgeInsets.symmetric(horizontal: scale(12), vertical: scale(4)),
      decoration: BoxDecoration(
        color: AppTheme.selectedSurface,
        borderRadius: BorderRadius.circular(scale(8)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Kode: ',
            style: TextStyle(
              color: AppTheme.muted,
              fontFamily: AppTheme.fontFamily,
              fontSize: scale(14),
              height: 20 / 14,
            ),
          ),
          Flexible(
            child: Text(
              code,
              key: const Key('doctor-profile-invite-code-value'),
              style: TextStyle(
                color: AppTheme.coralText,
                fontFamily: AppTheme.fontFamily,
                fontSize: scale(14),
                fontWeight: FontWeight.w600,
                height: 20 / 14,
              ),
            ),
          ),
          IconButton(
            key: const Key('doctor-profile-invite-code-copy'),
            tooltip: 'Salin kode undangan',
            onPressed: () => onCopy(code),
            visualDensity: VisualDensity.compact,
            constraints: BoxConstraints.tightFor(
              width: scale(32),
              height: scale(32),
            ),
            padding: EdgeInsets.zero,
            icon: Icon(
              Icons.copy_rounded,
              color: AppTheme.coralText,
              size: scale(16),
            ),
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
        type: secondary ? AppButtonType.secondary : AppButtonType.primary,
        textStyle: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: scale(16),
          fontWeight: FontWeight.w600,
          height: 24 / 16,
        ),
        buttonStyle: FilledButton.styleFrom(
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
