import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/app_role.dart';
import '../../../services/backend_api.dart';
import '../../../services/role_repository.dart';
import '../models/login_models.dart';
import '../repositories/auth_repository.dart';
import '../repositories/mock_auth_repository.dart';

final authControllerProvider = AsyncNotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

class AuthController extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    final selectedRole = await ref
        .watch(roleRepositoryProvider)
        .loadStartupRole();
    return AuthState(selectedRole: selectedRole);
  }

  void selectRole(AppRole role) {
    final current = state.requireValue;
    state = AsyncData(
      current.copyWith(
        selectedRole: role,
        clearError: true,
        clearSession: current.session != null,
      ),
    );
  }

  Future<LoginResponse?> login({
    required String email,
    required String password,
  }) async {
    final current = state.requireValue;
    state = AsyncData(
      current.copyWith(
        isSubmitting: true,
        clearError: true,
        clearSession: true,
      ),
    );

    try {
      final response = await ref
          .read(authRepositoryProvider)
          .login(
            request: LoginRequest(email: email.trim(), password: password),
          );
      if (response.user.role == null) {
        throw const FormatException('Login response role is missing.');
      }

      state = AsyncData(
        current.copyWith(
          selectedRole: response.user.role,
          session: response,
          isSubmitting: false,
          clearError: true,
        ),
      );
      return response;
    } on InvalidCredentialsException {
      return _setFailure(current, 'Email atau kata sandi tidak benar.');
    } on MockNetworkException {
      return _setFailure(
        current,
        'Tidak dapat terhubung. Periksa jaringan lalu coba lagi.',
      );
    } on MockServerException {
      return _setFailure(
        current,
        'Layanan sedang bermasalah. Coba lagi beberapa saat.',
      );
    } on FormatException {
      return _setFailure(
        current,
        'Respons masuk tidak dapat digunakan. Silakan coba lagi.',
      );
    } on ApiConfigurationException catch (error) {
      return _setFailure(current, error.message);
    } on ApiNetworkException catch (error) {
      return _setFailure(current, error.message);
    } on BackendApiException catch (error) {
      if (error.statusCode == 401) {
        return _setFailure(current, 'Email atau kata sandi tidak benar.');
      }
      return _setFailure(current, error.message);
    } on ApiResponseFormatException {
      return _setFailure(
        current,
        'Respons masuk tidak dapat digunakan. Silakan coba lagi.',
      );
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final current = state.requireValue;
    final selectedRole = current.selectedRole;
    if (selectedRole == null) {
      state = AsyncData(
        current.copyWith(errorMessage: 'Pilih peran sebelum membuat akun.'),
      );
      return false;
    }

    state = AsyncData(current.copyWith(isSubmitting: true, clearError: true));

    try {
      await ref
          .read(authRepositoryProvider)
          .register(
            request: RegisterRequest(
              name: name.trim(),
              email: email.trim(),
              password: password,
              role: selectedRole,
            ),
          );
      state = AsyncData(
        current.copyWith(isSubmitting: false, clearError: true),
      );
      return true;
    } on EmailAlreadyRegisteredException {
      return _setRegistrationFailure(
        current,
        'Email sudah terdaftar. Silakan masuk dengan akun tersebut.',
      );
    } on MockNetworkException {
      return _setRegistrationFailure(
        current,
        'Tidak dapat terhubung. Periksa jaringan lalu coba lagi.',
      );
    } on MockServerException {
      return _setRegistrationFailure(
        current,
        'Layanan sedang bermasalah. Coba lagi beberapa saat.',
      );
    } on ApiConfigurationException catch (error) {
      return _setRegistrationFailure(current, error.message);
    } on ApiNetworkException catch (error) {
      return _setRegistrationFailure(current, error.message);
    } on BackendApiException catch (error) {
      if (error.statusCode == 409) {
        return _setRegistrationFailure(
          current,
          'Email sudah terdaftar. Silakan masuk dengan akun tersebut.',
        );
      }
      return _setRegistrationFailure(current, error.message);
    } on ApiResponseFormatException {
      return _setRegistrationFailure(
        current,
        'Respons pendaftaran tidak dapat digunakan. Silakan coba lagi.',
      );
    }
  }

  void logout() {
    final current = state.requireValue;
    state = AsyncData(AuthState(selectedRole: current.selectedRole));
  }

  void clearError() {
    final current = state.requireValue;
    state = AsyncData(current.copyWith(clearError: true));
  }

  LoginResponse? _setFailure(AuthState current, String message) {
    state = AsyncData(
      current.copyWith(
        isSubmitting: false,
        errorMessage: message,
        clearSession: true,
      ),
    );
    return null;
  }

  bool _setRegistrationFailure(AuthState current, String message) {
    state = AsyncData(
      current.copyWith(
        isSubmitting: false,
        errorMessage: message,
        clearSession: true,
      ),
    );
    return false;
  }
}
