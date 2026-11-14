import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/controller/auth_controller.dart';
import '../../models/app_role.dart';

class RolePageScaffold extends ConsumerWidget {
  const RolePageScaffold({required this.role, super.key});

  final AppRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).asData?.value.session;
    return Scaffold(
      appBar: AppBar(
        title: Text(role.pageName),
        actions: [
          TextButton(
            key: const Key('logout'),
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).logout();
              if (context.mounted) context.go('/roles');
            },
            child: const Text('Keluar'),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Halaman ${role.pageName}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text('Peran: ${role.value}'),
              if (session?.user.email case final email?) ...[
                const SizedBox(height: 8),
                Text('Akun: $email'),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
