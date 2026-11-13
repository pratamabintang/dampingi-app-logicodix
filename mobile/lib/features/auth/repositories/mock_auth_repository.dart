import '../models/login_models.dart';
import '../../../models/app_role.dart';
import 'auth_repository.dart';

sealed class MockAuthException implements Exception {
  const MockAuthException();
}

class InvalidCredentialsException extends MockAuthException {
  const InvalidCredentialsException();
}

class MockNetworkException extends MockAuthException {
  const MockNetworkException();
}

class MockServerException extends MockAuthException {
  const MockServerException();
}

class EmailAlreadyRegisteredException extends MockAuthException {
  const EmailAlreadyRegisteredException();
}

class MockAuthRepository implements AuthRepository {
  MockAuthRepository({this.latency = const Duration(milliseconds: 350)})
    : _users = {
        'demo.mother@dampingi.test': const _MockAccount(
          id: 'demo-mother',
          name: 'Ibu Demo',
          role: AppRole.mother,
          password: _demoPassword,
        ),
        'demo.companion@dampingi.test': const _MockAccount(
          id: 'demo-companion',
          name: 'Pendamping Demo',
          role: AppRole.companion,
          password: _demoPassword,
        ),
        'demo.doctor@dampingi.test': const _MockAccount(
          id: 'demo-doctor',
          name: 'Maya Estiyanti',
          role: AppRole.professional,
          password: _demoPassword,
        ),
      };

  final Duration latency;
  final Map<String, _MockAccount> _users;
  var _nextUserId = 1;

  static const _demoPassword = 'demo1234';

  @override
  Future<LoginResponse> login({required LoginRequest request}) async {
    await Future<void>.delayed(latency);

    if (request.email == 'network@dampingi.test') {
      throw const MockNetworkException();
    }
    if (request.email == 'server@dampingi.test') {
      throw const MockServerException();
    }

    final normalizedEmail = request.email.trim().toLowerCase();
    final account = _users[normalizedEmail];
    if (account == null || request.password != account.password) {
      throw const InvalidCredentialsException();
    }
    return LoginResponse.fromJson({
      'access_token': 'mock-access-token',
      'user': {
        'id': account.id,
        'email': normalizedEmail,
        'name': account.name,
        'role': account.role.value,
      },
    });
  }

  @override
  Future<void> register({required RegisterRequest request}) async {
    await Future<void>.delayed(latency);

    final email = request.email.trim().toLowerCase();
    if (email == 'network@dampingi.test') {
      throw const MockNetworkException();
    }
    if (email == 'server@dampingi.test') {
      throw const MockServerException();
    }
    if (_users.containsKey(email)) {
      throw const EmailAlreadyRegisteredException();
    }

    _users[email] = _MockAccount(
      id: 'mock-user-${_nextUserId++}',
      name: request.name.trim(),
      role: request.role,
      password: request.password,
    );
  }
}

class _MockAccount {
  const _MockAccount({
    required this.id,
    required this.name,
    required this.role,
    required this.password,
  });

  final String id;
  final String name;
  final AppRole role;
  final String password;
}
