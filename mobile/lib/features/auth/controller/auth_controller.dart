import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../models/app_role.dart';
import '../../../services/authenticated_api.dart';
import '../../../services/backend_api.dart';
import '../../../services/role_repository.dart';
import '../models/login_models.dart';
import '../models/stored_session.dart';
import '../repositories/auth_repository.dart';
import '../repositories/mock_auth_repository.dart';
import '../repositories/session_store.dart';

final authControllerProvider = AsyncNotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

/// Persistence only exists when the app talks to the real backend; preview
/// mode keeps everything in memory so design runs leave no trace on device.
final authPersistenceEnabledProvider = Provider<bool>(
  (ref) => AppConfig.useBackendAuth,
);

/// Access token of the live Session, or null in preview mode.
///
/// Live-vs-preview checks read this instead of inspecting the raw token shape.
final backendTokenProvider = Provider<String?>((ref) {
  if (!ref.watch(authPersistenceEnabledProvider)) return null;
  return ref.watch(authControllerProvider).asData?.value.session?.accessToken;
});

class AuthController extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    final selectedRole = await ref
        .watch(roleRepositoryProvider)
        .loadStartupRole();
    final persistenceEnabled = ref.watch(authPersistenceEnabledProvider);
    final store = ref.watch(sessionStoreProvider);
    final rememberedEmail = persistenceEnabled ? await store.readEmail() : null;
    final restored = persistenceEnabled
        ? await _restoreSession(store.readSession, store.writeSession)
        : null;
    return AuthState(
      selectedRole: selectedRole,
      rememberedEmail: rememberedEmail,
      session: restored == null ? null : _fromStored(restored),
    );
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
    bool rememberMe = false,
  }) async {
    final current = state.requireValue;
    final trimmedEmail = email.trim();
    state = AsyncData(
      current.copyWith(
        isSubmitting: true,
        clearError: true,
        clearSession: true,
      ),
    );

    try {
      final response = _withExpiry(
        await ref
            .read(authRepositoryProvider)
            .login(
              request: LoginRequest(email: trimmedEmail, password: password),
            ),
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
      await _remember(response, email: trimmedEmail, rememberMe: rememberMe);
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

  /// Perbarui nama di sesi setelah `PATCH /me` berhasil, tanpa login ulang.
  void updateUserName(String name) {
    final current = state.asData?.value;
    final session = current?.session;
    if (current == null || session == null) return;
    final user = session.user;
    state = AsyncData(
      current.copyWith(
        session: LoginResponse(
          accessToken: session.accessToken,
          refreshToken: session.refreshToken,
          expiresIn: session.expiresIn,
          expiresAt: session.expiresAt,
          user: AuthUser(
            id: user.id,
            email: user.email,
            name: name,
            role: user.role,
          ),
        ),
      ),
    );
  }

  /// Replace the Session after a refresh rotation, before the caller proceeds.
  ///
  /// A storage failure keeps the fresh Session in memory: the user stays in,
  /// the worst case is logging in again next launch.
  Future<void> applyRefreshedSession(LoginResponse session) async {
    final current = state.requireValue;
    state = AsyncData(
      current.copyWith(
        selectedRole: session.user.role,
        session: session,
        clearError: true,
      ),
    );
    if (!ref.read(authPersistenceEnabledProvider)) return;
    final refreshToken = session.refreshToken;
    if (refreshToken == null) return;
    try {
      await ref
          .read(sessionStoreProvider)
          .writeSession(
            StoredSession(
              accessToken: session.accessToken,
              refreshToken: refreshToken,
              expiresAt:
                  session.expiresAt ??
                  DateTime.now().toUtc().add(const Duration(hours: 1)),
              user: session.user,
            ),
          );
    } catch (_) {
      // Keep going with the in-memory Session.
    }
  }

  /// The refresh token was rejected: keep the remembered email, forget the
  /// Session, and send the user back to login with a clear message.
  Future<void> expireSession() async {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        clearSession: true,
        errorMessage: 'Sesi telah berakhir. Silakan masuk kembali.',
      ),
    );
    await _clearStoredSession();
  }

  Future<void> logout() async {
    final current = state.requireValue;
    final session = current.session;
    if (session != null && ref.read(authPersistenceEnabledProvider)) {
      try {
        await ref
            .read(backendApiProvider)
            .postJson(
              '/auth/logout',
              body: const {},
              accessToken: session.accessToken,
            );
      } catch (_) {
        // Best effort: a network failure must not block the local logout.
      }
    }
    await _clearStoredSession();
    state = AsyncData(
      AuthState(
        selectedRole: current.selectedRole,
        rememberedEmail: current.rememberedEmail,
      ),
    );
  }

  void clearError() {
    final current = state.requireValue;
    state = AsyncData(current.copyWith(clearError: true));
  }

  /// Remember the Session on this device and, when "Ingat saya" is ticked,
  /// the email too. Storage failures never fail the login: the user is in
  /// either way, and the worst case is logging in again next launch.
  Future<void> _remember(
    LoginResponse response, {
    required String email,
    required bool rememberMe,
  }) async {
    if (!ref.read(authPersistenceEnabledProvider)) return;

    final store = ref.read(sessionStoreProvider);
    try {
      // "Ingat saya" is about the email only, so it is saved even when the
      // backend did not hand out a refresh token.
      if (rememberMe) {
        await store.writeEmail(email);
      } else {
        await store.clearEmail();
      }
      final refreshToken = response.refreshToken;
      if (refreshToken != null) {
        await store.writeSession(
          StoredSession(
            accessToken: response.accessToken,
            refreshToken: refreshToken,
            expiresAt: DateTime.now().toUtc().add(
              Duration(seconds: response.expiresIn ?? 3600),
            ),
            user: response.user,
          ),
        );
      }
    } catch (_) {
      // A storage failure must not turn a successful login into an error.
    }

    final current = state.requireValue;
    state = AsyncData(
      current.copyWith(
        rememberedEmail: rememberMe ? email : null,
        clearRememberedEmail: !rememberMe,
      ),
    );
  }

  /// Restore the remembered Session at launch.
  ///
  /// An expired access token is refreshed before the user reaches a home page;
  /// a rejected refresh token ends the Session, while network trouble keeps it
  /// so the next request can retry.
  Future<StoredSession?> _restoreSession(
    Future<StoredSession?> Function() read,
    Future<void> Function(StoredSession) write,
  ) async {
    var stored = await read();
    if (stored == null) return null;
    if (!stored.isExpired) return stored;

    try {
      final refreshed = await ref
          .read(sessionRefresherProvider)
          .refresh(refreshToken: stored.refreshToken, user: stored.user);
      stored = StoredSession(
        accessToken: refreshed.accessToken,
        refreshToken: refreshed.refreshToken!,
        expiresAt: refreshed.expiresAt!,
        user: stored.user,
      );
      try {
        await write(stored);
      } catch (_) {
        // Keep the refreshed Session in memory.
      }
      return stored;
    } on SessionExpiredException {
      await _clearStoredSession();
      return null;
    } catch (_) {
      // No connection at launch: stay logged in and refresh on first request.
      return stored;
    }
  }

  LoginResponse _fromStored(StoredSession stored) {
    return LoginResponse(
      accessToken: stored.accessToken,
      refreshToken: stored.refreshToken,
      expiresAt: stored.expiresAt,
      user: stored.user,
    );
  }

  LoginResponse _withExpiry(LoginResponse response) {
    if (response.expiresAt != null || response.expiresIn == null) {
      return response;
    }
    return LoginResponse(
      accessToken: response.accessToken,
      refreshToken: response.refreshToken,
      expiresIn: response.expiresIn,
      expiresAt: DateTime.now().toUtc().add(
        Duration(seconds: response.expiresIn!),
      ),
      user: response.user,
    );
  }

  Future<void> _clearStoredSession() async {
    if (!ref.read(authPersistenceEnabledProvider)) return;
    try {
      await ref.read(sessionStoreProvider).clearSession();
    } catch (_) {
      // Nothing else to do: the in-memory Session is already gone.
    }
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
