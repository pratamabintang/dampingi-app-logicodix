import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_brand_header.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/app_profile_avatar.dart';
import '../../../core/widgets/app_submit_button.dart';
import '../../auth/controller/auth_controller.dart';
import '../../connections/repositories/connection_repository.dart';
import '../repositories/mother_story_repository.dart';
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
  final List<_CompanionProfile> _companions = [..._defaultCompanions];

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).asData?.value.session?.user;
    final name = user?.name?.trim();
    final email = user?.email.trim();
    final live = ref.watch(backendTokenProvider) != null;

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
                            if (!live) ...[
                              _CompanionPermissionsCard(
                                scale: scaled,
                                title: 'Pratinjau: pilih data yang boleh dilihat orang yang terhubung',
                                subtitle: null,
                                companions: _companions,
                                permissions: _permissions,
                                onPermissionChanged: _setPermission,
                              ),
                              SizedBox(height: scaled(36)),
                            ] else ...[
                              _ProfessionalSharingPermissionsSection(
                                scale: scaled,
                              ),
                              SizedBox(height: scaled(36)),
                            ],
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

  void _setPermission(String companionId, String permission, bool value) {
    setState(() {
      _permissions[companionId]![permission] = value;
    });
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
            label: 'Koneksi',
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
              color: AppTheme.white10,
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
        border: Border.all(color: AppTheme.white3),
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
              displayName: companion.name,
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
    this.displayName,
  });

  final String companionId;
  final _PrivacyPermission permission;
  final double Function(double) scale;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? displayName;

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
                color: AppTheme.white10,
                fontSize: scale(14),
                fontWeight: FontWeight.w500,
                height: 20 / 14,
              ),
            ),
          ),
          Semantics(
            button: true,
            toggled: value,
            label:
                '${permission.label} untuk ${displayName ?? _companionName(companionId)}',
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

const _professionalPermissions = <_PrivacyPermission>[
  _PrivacyPermission(id: 'weekly-summary', label: 'Ringkasan mingguan'),
  _PrivacyPermission(id: 'epds', label: 'Hasil EPDS'),
  _PrivacyPermission(id: 'journal', label: 'Jurnal pribadi'),
];

class _ProfessionalSharingPermissionsSection extends ConsumerWidget {
  const _ProfessionalSharingPermissionsSection({required this.scale});

  final double Function(double) scale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connections = ref.watch(activeConnectionsProvider);
    return AppCard(
      key: const Key('mother-profile-permissions-card'),
      padding: EdgeInsets.all(scale(20)),
      borderRadius: scale(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Bagikan data kepada tenaga kesehatan',
            style: TextStyle(
              color: AppTheme.white10,
              fontSize: scale(16),
              fontWeight: FontWeight.w600,
              height: 24 / 16,
            ),
          ),
          SizedBox(height: scale(8)),
          Text(
            'Izin berlaku hanya untuk tenaga kesehatan yang terhubung dan '
            'dapat dicabut kapan saja.',
            key: const Key('mother-profile-sharing-rule'),
            style: TextStyle(
              color: AppTheme.muted,
              fontSize: scale(14),
              height: 20 / 14,
            ),
          ),
          SizedBox(height: scale(24)),
          connections.when(
            data: (items) {
              final professionals = (items ?? const <ConnectionPerson>[])
                  .where((connection) => connection.role == 'professional')
                  .toList();
              if (professionals.isEmpty) {
                return Text(
                  'Belum ada tenaga kesehatan yang terhubung.',
                  key: const Key('mother-profile-no-professionals'),
                  style: TextStyle(
                    color: AppTheme.muted,
                    fontSize: scale(14),
                    height: 20 / 14,
                  ),
                );
              }
              return Column(
                children: [
                  for (
                    var index = 0;
                    index < professionals.length;
                    index++
                  ) ...[
                    _ProfessionalSharingEditor(
                      connection: professionals[index],
                      scale: scale,
                    ),
                    if (index < professionals.length - 1)
                      SizedBox(height: scale(20)),
                  ],
                ],
              );
            },
            loading: () => SizedBox(
              height: scale(100),
              child: const AppLoading(message: 'Memuat koneksi...'),
            ),
            error: (error, stackTrace) => AppError(
              message: connectionFailureMessage(error),
              onRetry: () => ref.invalidate(activeConnectionsProvider),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfessionalSharingEditor extends ConsumerStatefulWidget {
  const _ProfessionalSharingEditor({
    required this.connection,
    required this.scale,
  });

  final ConnectionPerson connection;
  final double Function(double) scale;

  @override
  ConsumerState<_ProfessionalSharingEditor> createState() =>
      _ProfessionalSharingEditorState();
}

class _ProfessionalSharingEditorState
    extends ConsumerState<_ProfessionalSharingEditor> {
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final permissions = ref.watch(
      professionalSharingPermissionsProvider(widget.connection.id),
    );
    return Container(
      key: Key('mother-profile-professional-${widget.connection.id}'),
      padding: EdgeInsets.all(widget.scale(16)),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppTheme.white3),
        borderRadius: BorderRadius.circular(widget.scale(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ClipOval(
                child: Image.asset(
                  'assets/images/doctor/doctor-avatar.png',
                  width: widget.scale(56),
                  height: widget.scale(56),
                  fit: BoxFit.cover,
                ),
              ),
              SizedBox(width: widget.scale(16)),
              Expanded(
                child: Text(
                  widget.connection.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.coralText,
                    fontSize: widget.scale(16),
                    fontWeight: FontWeight.w600,
                    height: 24 / 16,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: widget.scale(16)),
          permissions.when(
            data: (value) {
              if (value == null) {
                return const AppError(
                  message: 'Izin berbagi data tidak dapat dimuat.',
                );
              }
              return Column(
                children: [
                  for (
                    var index = 0;
                    index < _professionalPermissions.length;
                    index++
                  ) ...[
                    _PermissionRow(
                      companionId: widget.connection.id,
                      displayName: widget.connection.name,
                      permission: _professionalPermissions[index],
                      scale: widget.scale,
                      value: switch (_professionalPermissions[index].id) {
                        'weekly-summary' => value.weeklySummary,
                        'epds' => value.epds,
                        'journal' => value.journal,
                        _ => false,
                      },
                      onChanged: _isSaving
                          ? (_) {}
                          : (enabled) => _updatePermission(
                              _professionalPermissions[index].id,
                              enabled,
                            ),
                    ),
                    if (index < _professionalPermissions.length - 1)
                      SizedBox(height: widget.scale(16)),
                  ],
                ],
              );
            },
            loading: () => SizedBox(
              height: widget.scale(100),
              child: const AppLoading(message: 'Memuat izin berbagi...'),
            ),
            error: (error, stackTrace) => AppError(
              message: connectionFailureMessage(error),
              onRetry: () => ref.invalidate(
                professionalSharingPermissionsProvider(widget.connection.id),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updatePermission(String permission, bool enabled) async {
    final token = ref.read(backendTokenProvider);
    if (token == null) return;
    final field = switch (permission) {
      'weekly-summary' => 'weekly_summary',
      'epds' => 'epds',
      'journal' => 'journal',
      _ => throw ArgumentError.value(permission, 'permission'),
    };
    setState(() => _isSaving = true);
    try {
      await ref
          .read(connectionRepositoryProvider)
          .updateProfessionalSharingPermissions(
            accessToken: token,
            connectionId: widget.connection.id,
            changes: {field: enabled},
          );
      ref.invalidate(
        professionalSharingPermissionsProvider(widget.connection.id),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(connectionFailureMessage(error))),
          );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
