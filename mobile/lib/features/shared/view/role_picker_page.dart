import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_error.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../features/auth/controller/auth_controller.dart';
import '../../../models/app_role.dart';

class RolePickerPage extends ConsumerWidget {
  const RolePickerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: auth.when(
          loading: () => const AppLoading(message: 'Memuat pilihan peran...'),
          error: (error, stackTrace) => AppError(
            message: 'Pilihan peran tidak dapat dimuat.',
            onRetry: () => ref.invalidate(authControllerProvider),
          ),
          data: (value) => _RolePickerContent(
            selectedRole: value.selectedRole,
            onSelect: ref.read(authControllerProvider.notifier).selectRole,
            onCreateAccount: () => context.go('/register'),
            onLogin: () => context.go('/login'),
          ),
        ),
      ),
    );
  }
}

class _RolePickerContent extends StatelessWidget {
  const _RolePickerContent({
    required this.selectedRole,
    required this.onSelect,
    required this.onCreateAccount,
    required this.onLogin,
  });

  final AppRole? selectedRole;
  final ValueChanged<AppRole> onSelect;
  final VoidCallback onCreateAccount;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 43, 28, 44),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const _RolePickerHeader(),
                  Column(
                    children: [
                      for (
                        var index = 0;
                        index < AppRole.values.length;
                        index++
                      )
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: index == AppRole.values.length - 1 ? 0 : 12,
                          ),
                          child: _RoleCard(
                            role: AppRole.values[index],
                            selected: AppRole.values[index] == selectedRole,
                            onTap: () => onSelect(AppRole.values[index]),
                          ),
                        ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton(
                        key: const Key('role-create-account'),
                        onPressed: selectedRole == null
                            ? null
                            : onCreateAccount,
                        style: AppButtonStyles.primary.merge(
                          FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            textStyle: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              height: 24 / 16,
                            ),
                          ),
                        ),
                        child: const Text('Buat akun'),
                      ),
                      const SizedBox(height: 10),
                      FilledButton(
                        key: const Key('role-login'),
                        onPressed: selectedRole == null ? null : onLogin,
                        style: AppButtonStyles.secondary.merge(
                          FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            textStyle: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              height: 24 / 16,
                            ),
                          ),
                        ),
                        child: const Text(
                          'Masuk',
                          style: TextStyle(fontFamily: 'Mona Sans'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RolePickerHeader extends StatelessWidget {
  const _RolePickerHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Pilih Peranmu di Dampingi',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Mona Sans',
            color: AppTheme.coral,
            fontSize: 24,
            fontWeight: FontWeight.w600,
            height: 32 / 24,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Bersama merawat kesehatan mental ibu dan keluarga pasca-melahirkan.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            color: AppTheme.muted,
            fontSize: 16,
            height: 24 / 16,
          ),
        ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.selected,
    required this.onTap,
  });

  final AppRole role;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppTheme.selectedSurface : AppTheme.unselectedSurface,
      borderRadius: BorderRadius.circular(32),
      child: InkWell(
        key: Key('role-${role.value}'),
        borderRadius: BorderRadius.circular(32),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 23),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            border: selected
                ? Border.all(color: AppTheme.coral)
                : Border.all(color: Colors.transparent),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 47,
                backgroundColor: selected ? AppTheme.pink2 : AppTheme.gray200,
                child: SizedBox(
                  key: Key('role-emoji-${role.value}'),
                  width: 36,
                  height: 36,
                  child: Center(
                    child: Text(
                      _roleEmoji(role),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        inherit: false,
                        fontSize: 32,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Stack(
                  children: [
                    Padding(
                      padding: EdgeInsets.only(right: selected ? 36 : 0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _roleTitle(role),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              color: AppTheme.ink,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              height: 24 / 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _roleDescription(role),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              color: AppTheme.gray500,
                              fontSize: 16,
                              height: 24 / 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (selected)
                      Positioned(
                        top: 24,
                        right: 0,
                        child: SvgPicture.asset(
                          'assets/images/role_selected_check.svg',
                          width: 24,
                          height: 24,
                          semanticsLabel: 'Dipilih',
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _roleTitle(AppRole role) => switch (role) {
  AppRole.mother => 'Ibu',
  AppRole.companion => 'Saya Pendamping Ibu',
  AppRole.professional => 'Tenaga kesehatan',
};

String _roleDescription(AppRole role) => switch (role) {
  AppRole.mother => 'Pantau kondisi harian dan EPDS',
  AppRole.companion => 'Dukung ibu, catat pengamatan harian',
  AppRole.professional => 'Lihat ringkasan tren perkembangan ibu',
};

String _roleEmoji(AppRole role) => switch (role) {
  AppRole.mother => '🤱',
  AppRole.companion => '👨‍💼',
  AppRole.professional => '🩺',
};
