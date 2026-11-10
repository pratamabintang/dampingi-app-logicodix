import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/controller/role_session_controller.dart';
import '../../models/app_role.dart';

class RolePageScaffold extends ConsumerWidget {
  const RolePageScaffold({required this.role, super.key});

  final AppRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(role.pageName)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Page: ${role.pageName}'),
          Text('Role: ${role.value}'),
          const SizedBox(height: 16),
          for (final destination in AppRole.values)
            ListTile(
              title: Text('Open ${destination.pageName}'),
              onTap: () {
                ref.read(roleSessionProvider.notifier).selectRole(destination);
                context.go(destination.location);
              },
            ),
          ListTile(
            title: const Text('Choose role'),
            onTap: () => context.go('/roles'),
          ),
        ],
      ),
    );
  }
}
