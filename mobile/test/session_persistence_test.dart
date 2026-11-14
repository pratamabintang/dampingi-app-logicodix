import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/auth/controller/auth_controller.dart';
import 'package:mobile/features/auth/models/login_models.dart';
import 'package:mobile/features/auth/models/stored_session.dart';
import 'package:mobile/features/auth/repositories/auth_repository.dart';
import 'package:mobile/features/auth/repositories/mock_auth_repository.dart';
import 'package:mobile/features/auth/repositories/session_store.dart';
import 'package:mobile/models/app_role.dart';
import 'package:mobile/services/role_repository.dart';

class _MemorySessionStore implements SessionStore {
  StoredSession? session;
  String? email;
  var sessionWrites = 0;
  var sessionClears = 0;

  @override
  Future<StoredSession?> readSession() async => session;

  @override
  Future<void> writeSession(StoredSession value) async {
    session = value;
    sessionWrites++;
  }

  @override
  Future<void> clearSession() async {
    session = null;
    sessionClears++;
  }

  @override
  Future<String?> readEmail() async => email;

  @override
  Future<void> writeEmail(String value) async {
    email = value;
  }

  @override
  Future<void> clearEmail() async {
    email = null;
  }
}

class _MotherRoleRepository extends RoleRepository {
  @override
  Future<AppRole?> loadStartupRole() async => AppRole.mother;
}

class _LoginRepository implements AuthRepository {
  _LoginRepository({this.refreshToken = 'REFRESH'});

  final String? refreshToken;
  var calls = 0;

  @override
  Future<LoginResponse> login({required LoginRequest request}) async {
    calls++;
    return LoginResponse.fromJson({
      'access_token': 'ACCESS',
      'expires_in': 900,
      if (refreshToken != null) 'refresh_token': refreshToken,
      'user': {
        'id': 'mother-1',
        'email': 'ibu@gmail.com',
        'name': 'Ibu',
        'role': 'mother',
      },
    });
  }

  @override
  Future<void> register({required RegisterRequest request}) async {}
}

ProviderContainer _container({
  required _MemorySessionStore store,
  required AuthRepository repository,
  bool persistence = true,
  String? rememberedEmail,
}) {
  store.email = rememberedEmail;
  final container = ProviderContainer(
    overrides: [
      roleRepositoryProvider.overrideWithValue(_MotherRoleRepository()),
      authRepositoryProvider.overrideWithValue(repository),
      sessionStoreProvider.overrideWithValue(store),
      authPersistenceEnabledProvider.overrideWithValue(persistence),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test(
    'a successful login remembers the Session without being asked',
    () async {
      final store = _MemorySessionStore();
      final container = _container(
        store: store,
        repository: _LoginRepository(),
      );
      await container.read(authControllerProvider.future);

      await container
          .read(authControllerProvider.notifier)
          .login(email: ' ibu@gmail.com ', password: 'password');

      expect(store.session, isNotNull);
      expect(store.session!.accessToken, 'ACCESS');
      expect(store.session!.refreshToken, 'REFRESH');
      expect(store.session!.user.email, 'ibu@gmail.com');
      expect(store.session!.role, AppRole.mother);
      final lifetime = store.session!.expiresAt.difference(
        DateTime.now().toUtc(),
      );
      expect(lifetime.inSeconds, inInclusiveRange(890, 900));
    },
  );

  test('"Ingat saya" only remembers the email, ticked', () async {
    final store = _MemorySessionStore();
    final container = _container(store: store, repository: _LoginRepository());
    await container.read(authControllerProvider.future);

    await container
        .read(authControllerProvider.notifier)
        .login(email: 'ibu@gmail.com', password: 'password', rememberMe: true);

    expect(store.email, 'ibu@gmail.com');
    expect(store.session, isNotNull);
  });

  test(
    '"Ingat saya" still works when the backend sends no refresh token',
    () async {
      final store = _MemorySessionStore();
      final container = _container(
        store: store,
        repository: _LoginRepository(refreshToken: null),
      );
      await container.read(authControllerProvider.future);

      await container
          .read(authControllerProvider.notifier)
          .login(
            email: 'ibu@gmail.com',
            password: 'password',
            rememberMe: true,
          );

      expect(store.email, 'ibu@gmail.com');
      expect(store.session, isNull);
      expect(
        container.read(authControllerProvider).requireValue.rememberedEmail,
        'ibu@gmail.com',
      );
    },
  );

  test('"Ingat saya" unticked forgets a previously remembered email', () async {
    final store = _MemorySessionStore();
    final container = _container(
      store: store,
      repository: _LoginRepository(),
      rememberedEmail: 'lama@gmail.com',
    );
    await container.read(authControllerProvider.future);

    await container
        .read(authControllerProvider.notifier)
        .login(email: 'ibu@gmail.com', password: 'password');

    expect(store.email, isNull);
    expect(store.session, isNotNull);
  });

  test('the remembered email is available before the user types', () async {
    final store = _MemorySessionStore();
    final container = _container(
      store: store,
      repository: _LoginRepository(),
      rememberedEmail: 'ibu@gmail.com',
    );

    final state = await container.read(authControllerProvider.future);

    expect(state.rememberedEmail, 'ibu@gmail.com');
  });

  test('a failed login remembers nothing', () async {
    final store = _MemorySessionStore();
    final container = _container(
      store: store,
      repository: _FailingRepository(),
    );
    await container.read(authControllerProvider.future);

    await container
        .read(authControllerProvider.notifier)
        .login(email: 'ibu@gmail.com', password: 'wrong');

    expect(store.session, isNull);
    expect(store.email, isNull);
  });

  test('preview mode never touches the device storage', () async {
    final store = _MemorySessionStore();
    final container = _container(
      store: store,
      repository: _LoginRepository(),
      persistence: false,
    );
    await container.read(authControllerProvider.future);

    await container
        .read(authControllerProvider.notifier)
        .login(
          email: 'demo.mother@dampingi.test',
          password: 'demo1234',
          rememberMe: true,
        );

    expect(store.sessionWrites, 0);
    expect(store.email, isNull);
  });

  test('renaming the Profile keeps the Session usable', () async {
    final store = _MemorySessionStore();
    final container = _container(store: store, repository: _LoginRepository());
    await container.read(authControllerProvider.future);
    await container
        .read(authControllerProvider.notifier)
        .login(email: 'ibu@gmail.com', password: 'password');

    container.read(authControllerProvider.notifier).updateUserName('Ibu Baru');

    final session = container.read(authControllerProvider).requireValue.session;
    expect(session!.user.name, 'Ibu Baru');
    expect(session.refreshToken, 'REFRESH');
    expect(session.expiresIn, 900);
  });
}

class _FailingRepository implements AuthRepository {
  @override
  Future<LoginResponse> login({required LoginRequest request}) async {
    throw const InvalidCredentialsException();
  }

  @override
  Future<void> register({required RegisterRequest request}) async {}
}
