import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../features/auth/controller/role_session_controller.dart';
import '../../../models/app_role.dart';

class RolePickerPage extends ConsumerWidget {
  const RolePickerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose role')),
      body: ListView(
        children: [
          for (final role in AppRole.values)
            ListTile(
              title: Text(role.pageName),
              subtitle: Text('Role: ${role.value}'),
              onTap: () {
                ref.read(roleSessionProvider.notifier).selectRole(role);
                context.go(role.location);
              },
            ),
        ],
      ),
    );
  }
}
