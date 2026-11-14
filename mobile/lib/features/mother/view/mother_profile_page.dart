import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_brand_header.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_profile_avatar.dart';
import '../../../core/widgets/app_submit_button.dart';
import '../../auth/controller/auth_controller.dart';
import 'mother_navigation.dart';

class MotherProfilePage extends ConsumerStatefulWidget {
  const MotherProfilePage({super.key});

  @override
  ConsumerState<MotherProfilePage> createState() => _MotherProfilePageState();
}

class _MotherProfilePageState extends ConsumerState<MotherProfilePage> {
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).asData?.value.session?.user;
    final name = user?.name?.trim();
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
                              onEditProfile: () =>
                                  context.push('/mother/profile/edit'),
                              onOpenConnections: () =>
                                  context.push('/mother/connections'),
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

  Future<void> _logout() async {
    await ref.read(authControllerProvider.notifier).logout();
    if (mounted) context.go('/roles');
  }
}

class _ProfileInformationCard extends StatelessWidget {
  const _ProfileInformationCard({
    required this.name,
    required this.email,
    required this.scale,
    required this.onEditProfile,
    required this.onOpenConnections,
  });

  final String name;
  final String email;
  final double Function(double) scale;
  final VoidCallback onEditProfile;
  final VoidCallback onOpenConnections;

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
            key: const Key('mother-profile-connections'),
            label: 'Kelola Koneksi',
            scale: scale,
            onPressed: onOpenConnections,
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
    super.key,
  });

  final String label;
  final double Function(double) scale;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: scale(48),
      child: AppSubmitButton(
        label: label,
        onPressed: onPressed,
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
