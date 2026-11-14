import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/auth/controller/auth_controller.dart';
import 'package:mobile/features/auth/models/login_models.dart';
import 'package:mobile/features/auth/models/stored_session.dart';
import 'package:mobile/features/auth/repositories/session_store.dart';
import 'package:mobile/models/app_role.dart';
import 'package:mobile/services/backend_api.dart';
import 'package:mobile/services/role_repository.dart';

const _user = AuthUser(
  id: 'mother-1',
  email: 'ibu@gmail.com',
  name: 'Ibu',
  role: AppRole.mother,
);

StoredSession _stored({required Duration expiresIn}) {
  return StoredSession(
    accessToken: 'OLD-ACCESS',
    refreshToken: 'OLD-REFRESH',
    expiresAt: DateTime.now().toUtc().add(expiresIn),
    user: _user,
  );
}

class _MemorySessionStore implements SessionStore {
  StoredSession? session;
  String? email;

  @override
  Future<StoredSession?> readSession() async => session;

  @override
  Future<void> writeSession(StoredSession value) async => session = value;

  @override
  Future<void> clearSession() async => session = null;

  @override
  Future<String?> readEmail() async => email;

  @override
  Future<void> writeEmail(String value) async => email = value;

  @override
  Future<void> clearEmail() async => email = null;
}

class _MotherRoleRepository extends RoleRepository {
  @override
  Future<AppRole?> loadStartupRole() async => AppRole.mother;
}

class _RefreshApi extends BackendApi {
  _RefreshApi({this.refreshError, this.logoutError})
    : super(baseUrl: 'https://backend.example.test');

  final Object? refreshError;
  final Object? logoutError;
  final calls = <String>[];

  @override
  Future<Map<String, dynamic>> postJson(
    String path, {
    required Map<String, Object?> body,
    String? accessToken,
  }) async {
    calls.add('POST $path');
    if (path == '/auth/refresh') {
      final error = refreshError;
      if (error != null) throw error;
      return {
        'access_token': 'NEW-ACCESS',
        'refresh_token': 'NEW-REFRESH',
        'expires_in': 3600,
      };
    }
    if (path == '/auth/logout') {
      final error = logoutError;
      if (error != null) throw error;
      return {};
    }
    return {};
  }
}

ProviderContainer _container(_MemorySessionStore store, {BackendApi? api}) {
  final container = ProviderContainer(
    overrides: [
      roleRepositoryProvider.overrideWithValue(_MotherRoleRepository()),
      sessionStoreProvider.overrideWithValue(store),
      authPersistenceEnabledProvider.overrideWithValue(true),
      if (api != null) backendApiProvider.overrideWithValue(api),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('a valid stored Session opens the app already logged in', () async {
    final store = _MemorySessionStore()
      ..session = _stored(expiresIn: const Duration(hours: 2))
      ..email = 'ibu@gmail.com';

    final state = await _container(store).read(authControllerProvider.future);

    expect(state.session?.user.email, 'ibu@gmail.com');
    expect(state.session?.user.role, AppRole.mother);
    expect(state.rememberedEmail, 'ibu@gmail.com');
  });

  test('no stored Session opens at role selection', () async {
    final state = await _container(_MemorySessionStore())
        .read(authControllerProvider.future);

    expect(state.session, isNull);
  });

  test('an expired stored Session is refreshed before reaching home', () async {
    final store = _MemorySessionStore()
      ..session = _stored(expiresIn: const Duration(seconds: -10));
    final api = _RefreshApi();

    final state = await _container(
      store,
      api: api,
    ).read(authControllerProvider.future);

    expect(api.calls, ['POST /auth/refresh']);
    expect(state.session?.accessToken, 'NEW-ACCESS');
    expect(store.session?.accessToken, 'NEW-ACCESS');
    expect(store.session?.refreshToken, 'NEW-REFRESH');
  });

  test(
    'a rejected refresh token forgets the Session but keeps the email',
    () async {
      final store = _MemorySessionStore()
        ..session = _stored(expiresIn: const Duration(seconds: -10))
        ..email = 'ibu@gmail.com';
      final api = _RefreshApi(
        refreshError: const BackendApiException(
          statusCode: 401,
          message: 'Sesi tidak valid.',
        ),
      );

      final state = await _container(
        store,
        api: api,
      ).read(authControllerProvider.future);

      expect(state.session, isNull);
      expect(state.rememberedEmail, 'ibu@gmail.com');
      expect(store.session, isNull);
    },
  );

  test('offline at launch keeps the Session for a later retry', () async {
    final store = _MemorySessionStore()
      ..session = _stored(expiresIn: const Duration(seconds: -10));
    final api = _RefreshApi(
      refreshError: const ApiNetworkException('Tidak dapat terhubung.'),
    );

    final state = await _container(
      store,
      api: api,
    ).read(authControllerProvider.future);

    expect(state.session?.accessToken, 'OLD-ACCESS');
    expect(store.session, isNotNull);
  });

  test('logout revokes the Session, forgets it, and keeps the email', () async {
    final store = _MemorySessionStore()
      ..session = _stored(expiresIn: const Duration(hours: 2))
      ..email = 'ibu@gmail.com';
    final api = _RefreshApi();
    final container = _container(store, api: api);
    await container.read(authControllerProvider.future);

    await container.read(authControllerProvider.notifier).logout();

    expect(api.calls, ['POST /auth/logout']);
    expect(store.session, isNull);
    expect(store.email, 'ibu@gmail.com');
    final state = container.read(authControllerProvider).requireValue;
    expect(state.session, isNull);
    expect(state.rememberedEmail, 'ibu@gmail.com');
  });

  test('logout still works when revoking the Session fails', () async {
    final store = _MemorySessionStore()
      ..session = _stored(expiresIn: const Duration(hours: 2))
      ..email = 'ibu@gmail.com';
    final api = _RefreshApi(
      logoutError: const ApiNetworkException('Tidak dapat terhubung.'),
    );
    final container = _container(store, api: api);
    await container.read(authControllerProvider.future);

    await container.read(authControllerProvider.notifier).logout();

    expect(store.session, isNull);
    expect(store.email, 'ibu@gmail.com');
  });

  test(
    'an expired Session mid-use returns to login with a clear message',
    () async {
      final store = _MemorySessionStore()
        ..session = _stored(expiresIn: const Duration(hours: 2))
        ..email = 'ibu@gmail.com';
      final container = _container(store);
      await container.read(authControllerProvider.future);

      await container.read(authControllerProvider.notifier).expireSession();

      final state = container.read(authControllerProvider).requireValue;
      expect(state.session, isNull);
      expect(state.rememberedEmail, 'ibu@gmail.com');
      expect(state.errorMessage, 'Sesi telah berakhir. Silakan masuk kembali.');
      expect(store.session, isNull);
      expect(store.email, 'ibu@gmail.com');
    },
  );
}
