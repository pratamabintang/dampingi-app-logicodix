import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_brand_header.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_profile_avatar.dart';
import '../../../core/widgets/app_submit_button.dart';
import '../../auth/controller/auth_controller.dart';
import 'doctor_invitation_flow.dart';

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
                            scale: scaled,
                            onEdit: () => _showNotice(
                              'Fitur ubah profil belum tersedia.',
                            ),
                            onAddPatient: () =>
                                showDoctorInvitationFlow(context, scale: scale),
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

  void _logout() {
    ref.read(authControllerProvider.notifier).logout();
    context.go('/roles');
  }
}

class _DoctorProfileInformationCard extends StatelessWidget {
  const _DoctorProfileInformationCard({
    required this.name,
    required this.email,
    required this.scale,
    required this.onEdit,
    required this.onAddPatient,
  });

  final String name;
  final String email;
  final double Function(double) scale;
  final VoidCallback onEdit;
  final VoidCallback onAddPatient;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: const Key('doctor-profile-information-card'),
      padding: EdgeInsets.all(scale(20)),
      borderRadius: scale(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppProfileAvatar(
            key: const Key('doctor-profile-avatar'),
            assetPath: 'assets/images/doctor/doctor-avatar.png',
            size: scale(85),
            semanticLabel: 'Foto profil $name',
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
          SizedBox(
            height: scale(24),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Kode pendampingan : AIS128',
                key: const Key('doctor-profile-code'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.muted,
                  fontFamily: AppTheme.fontFamily,
                  fontSize: scale(16),
                  height: 24 / 16,
                ),
              ),
            ),
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
