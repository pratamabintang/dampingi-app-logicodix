import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/authenticated_api.dart';
import '../models/login_models.dart';

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(authenticatedApiProvider)),
);

/// Profil milik pengguna yang sedang login (ibu atau pendamping).
class ProfileRepository {
  ProfileRepository(this._api);

  final AuthenticatedApi _api;

  /// Hanya nama yang boleh diubah; email dan peran tetap.
  Future<AuthUser> updateName({required String name}) async {
    return AuthUser.fromJson(await _api.patchJson('/me', body: {'name': name}));
  }

  /// Backend mencabut semua sesi setelah berhasil, jadi pengguna harus login lagi.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _api.postJson(
      '/auth/password',
      body: {'current_password': currentPassword, 'new_password': newPassword},
    );
  }
}
