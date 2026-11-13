import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_submit_button.dart';
import '../../auth/controller/auth_controller.dart';
import 'mother_navigation.dart';

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

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).asData?.value.session?.user;
    final name = user?.name?.trim();
    final email = user?.email.trim();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false,
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
                  style: const TextStyle(fontFamily: 'Mona Sans'),
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView(
                          key: const Key('mother-profile-scroll'),
                          padding: EdgeInsets.fromLTRB(
                            scaled(24),
                            scaled(44),
                            scaled(24),
                            scaled(34),
                          ),
                          children: [
                            SizedBox(
                              height: scaled(56),
                              child: Center(
                                child: Text(
                                  'Dampingi',
                                  style: TextStyle(
                                    color: AppTheme.coral,
                                    fontSize: scaled(24),
                                    fontWeight: FontWeight.w600,
                                    height: 32 / 24,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: scaled(36)),
                            _ProfileInformationCard(
                              name: name == null || name.isEmpty
                                  ? 'Jane Doe'
                                  : name,
                              email: email == null || email.isEmpty
                                  ? 'janedoe@gmail.com'
                                  : email,
                              scale: scaled,
                              onEditProfile: () => _showUnavailableNotice(
                                'Fitur ubah profil belum tersedia.',
                              ),
                              onAddCompanion: () => _showUnavailableNotice(
                                'Fitur tambah pendamping belum tersedia.',
                              ),
                            ),
                            SizedBox(height: scaled(36)),
                            _CompanionPermissionsCard(
                              scale: scaled,
                              permissions: _permissions,
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
                                  fontFamily: 'Mona Sans',
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

  void _showUnavailableNotice(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
    required this.scale,
    required this.onEditProfile,
    required this.onAddCompanion,
  });

  final String name;
  final String email;
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
              SizedBox(
                key: const Key('mother-profile-avatar'),
                width: scale(85),
                height: scale(85),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/mother_home/avatar-a.png',
                    fit: BoxFit.cover,
                  ),
                ),
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
                    'Kode Pendampingan : K4DSTP',
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
          fontFamily: 'Mona Sans',
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

class _CompanionPermissionsCard extends StatelessWidget {
  const _CompanionPermissionsCard({
    required this.scale,
    required this.permissions,
    required this.onPermissionChanged,
  });

  final double Function(double) scale;
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
            'Pilih data yang boleh dilihat orang yang terhubung',
            maxLines: 2,
            style: TextStyle(
              color: const Color(0xFF252B37),
              fontSize: scale(16),
              fontWeight: FontWeight.w600,
              height: 24 / 16,
            ),
          ),
          SizedBox(height: scale(24)),
          for (var index = 0; index < _companions.length; index++) ...[
            _CompanionPermissionCard(
              companion: _companions[index],
              scale: scale,
              permissions: permissions[_companions[index].id]!,
              onPermissionChanged: (permission, value) =>
                  onPermissionChanged(_companions[index].id, permission, value),
            ),
            if (index < _companions.length - 1) SizedBox(height: scale(24)),
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

const _companions = <_CompanionProfile>[
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
