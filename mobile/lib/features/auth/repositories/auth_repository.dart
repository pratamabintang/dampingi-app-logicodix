import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../services/backend_api.dart';
import '../models/login_models.dart';
import 'mock_auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AppConfig.useBackendAuth
      ? BackendAuthRepository(ref.watch(backendApiProvider))
      : MockAuthRepository(),
);

abstract interface class AuthRepository {
  Future<LoginResponse> login({required LoginRequest request});

  Future<void> register({required RegisterRequest request});
}

class BackendAuthRepository implements AuthRepository {
  const BackendAuthRepository(this._api);

  final BackendApi _api;

  @override
  Future<LoginResponse> login({required LoginRequest request}) async {
    final json = await _api.postJson('/auth/login', body: request.toJson());
    return LoginResponse.fromJson(json);
  }

  @override
  Future<void> register({required RegisterRequest request}) async {
    await _api.postJson('/auth/register', body: request.toJson());
  }
}
