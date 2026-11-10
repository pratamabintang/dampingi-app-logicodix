import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/app_role.dart';
import '../../../services/role_repository.dart';

final roleSessionProvider =
    AsyncNotifierProvider<RoleSessionController, AppRole?>(
      RoleSessionController.new,
    );

class RoleSessionController extends AsyncNotifier<AppRole?> {
  @override
  Future<AppRole?> build() {
    return ref.watch(roleRepositoryProvider).loadStartupRole();
  }

  void selectRole(AppRole role) {
    state = AsyncData(role);
  }
}
