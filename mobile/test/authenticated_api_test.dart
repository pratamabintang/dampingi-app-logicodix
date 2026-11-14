import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/auth/models/login_models.dart';
import 'package:mobile/models/app_role.dart';
import 'package:mobile/services/authenticated_api.dart';
import 'package:mobile/services/backend_api.dart';

const _user = AuthUser(
  id: 'mother-1',
  email: 'ibu@gmail.com',
  name: 'Ibu',
  role: AppRole.mother,
);

LoginResponse _session({required Duration expiresIn, String token = 'OLD'}) {
  return LoginResponse(
    accessToken: token,
    refreshToken: 'REFRESH',
    expiresIn: expiresIn.inSeconds,
    expiresAt: DateTime.now().toUtc().add(expiresIn),
    user: _user,
  );
}

class _Harness {
  _Harness(LoginResponse? session) : _session = session;

  LoginResponse? _session;
  LoginResponse? get session => _session;
  var expired = 0;
  var refreshed = 0;

  late final AuthenticatedApi client = AuthenticatedApi(
    transport: transport,
    refresher: SessionRefresher(transport),
    currentToken: () => _session?.accessToken,
    currentSession: () => _session,
    onRefreshed: (session) async {
      refreshed++;
      _session = session;
    },
    onExpired: () async {
      expired++;
      _session = null;
    },
  );

  final transport = _FakeTransport();
}

class _FakeTransport extends BackendApi {
  _FakeTransport() : super(baseUrl: 'https://backend.example.test');

  final calls = <String>[];
  final tokens = <String?>[];
  final _responses = <String, FutureOr<Map<String, dynamic>> Function()>{};
  var refreshCount = 0;

  void respond(String key, FutureOr<Map<String, dynamic>> Function() response) {
    _responses[key] = response;
  }

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? query,
    String? accessToken,
  }) async {
    calls.add('GET $path');
    tokens.add(accessToken);
    return _answer('GET $path');
  }

  @override
  Future<Map<String, dynamic>> postJson(
    String path, {
    required Map<String, Object?> body,
    String? accessToken,
  }) async {
    calls.add('POST $path');
    tokens.add(accessToken);
    if (path == '/auth/refresh') refreshCount++;
    return _answer('POST $path');
  }

  Future<Map<String, dynamic>> _answer(String key) async {
    final response = _responses[key];
    if (response == null) throw StateError('no response for $key');
    return response();
  }
}

void main() {
  test('a token about to expire is refreshed before the request', () async {
    final harness = _Harness(_session(expiresIn: const Duration(seconds: 30)));
    harness.transport
      ..respond(
        'POST /auth/refresh',
        () => {
          'access_token': 'NEW',
          'refresh_token': 'REFRESH-2',
          'expires_in': 3600,
        },
      )
      ..respond('GET /moods', () => const {'moods': <Object?>[]});

    await harness.client.getJson('/moods');

    expect(harness.transport.calls, ['POST /auth/refresh', 'GET /moods']);
    expect(harness.transport.tokens, [null, 'NEW']);
    expect(harness.session?.refreshToken, 'REFRESH-2');
  });

  test('a token with plenty of life is used as is', () async {
    final harness = _Harness(_session(expiresIn: const Duration(hours: 1)));
    harness.transport.respond('GET /moods', () => const {'moods': []});

    await harness.client.getJson('/moods');

    expect(harness.transport.calls, ['GET /moods']);
    expect(harness.transport.tokens, ['OLD']);
  });

  test('one 401 refreshes once and retries with the new token', () async {
    final harness = _Harness(_session(expiresIn: const Duration(hours: 1)));
    var groups = 0;
    harness.transport
      ..respond('POST /auth/refresh', () {
        return {
          'access_token': 'NEW',
          'refresh_token': 'REFRESH-2',
          'expires_in': 3600,
        };
      })
      ..respond('GET /moods', () {
        groups++;
        if (groups == 1) {
          throw const BackendApiException(statusCode: 401, message: 'expired');
        }
        return const {'moods': <Object?>[]};
      });

    await harness.client.getJson('/moods');

    expect(harness.transport.calls, [
      'GET /moods',
      'POST /auth/refresh',
      'GET /moods',
    ]);
    expect(harness.transport.tokens, ['OLD', null, 'NEW']);
    expect(harness.transport.refreshCount, 1);
  });

  test('concurrent 401s share one refresh, so rotation happens once', () async {
    final harness = _Harness(_session(expiresIn: const Duration(hours: 1)));
    final gate = Completer<void>();
    final failed = <String>{};
    harness.transport
      ..respond('POST /auth/refresh', () async {
        await gate.future;
        return {
          'access_token': 'NEW',
          'refresh_token': 'REFRESH-2',
          'expires_in': 3600,
        };
      })
      ..respond('GET /moods', () {
        if (failed.add('moods')) {
          throw const BackendApiException(statusCode: 401, message: 'expired');
        }
        return const {'moods': <Object?>[]};
      })
      ..respond('GET /journals', () {
        if (failed.add('journals')) {
          throw const BackendApiException(statusCode: 401, message: 'expired');
        }
        return const {'journals': <Object?>[]};
      });

    final calls = [
      harness.client.getJson('/moods'),
      harness.client.getJson('/journals'),
    ];
    await Future<void>.delayed(Duration.zero);
    gate.complete();
    await Future.wait(calls);

    expect(harness.transport.refreshCount, 1);
    expect(harness.session?.refreshToken, 'REFRESH-2');
    expect(harness.expired, 0);
  });

  test('a rejected refresh ends the Session and is not retried', () async {
    final harness = _Harness(_session(expiresIn: const Duration(hours: 1)));
    harness.transport
      ..respond(
        'GET /moods',
        () => throw const BackendApiException(statusCode: 401, message: 'x'),
      )
      ..respond(
        'POST /auth/refresh',
        () => throw const BackendApiException(
          statusCode: 401,
          message: 'Sesi tidak valid. Silakan masuk kembali.',
        ),
      );

    await expectLater(
      harness.client.getJson('/moods'),
      throwsA(isA<SessionExpiredException>()),
    );

    expect(harness.expired, 1);
    expect(harness.session, isNull);
    expect(harness.transport.calls, ['GET /moods', 'POST /auth/refresh']);
  });

  test(
    'network trouble keeps the Session so a later request can retry',
    () async {
      final harness = _Harness(
        _session(expiresIn: const Duration(seconds: 10)),
      );
      harness.transport.respond(
        'POST /auth/refresh',
        () => throw const ApiNetworkException('Tidak dapat terhubung.'),
      );

      await expectLater(
        harness.client.getJson('/moods'),
        throwsA(isA<ApiNetworkException>()),
      );

      expect(harness.expired, 0);
      expect(harness.session?.refreshToken, 'REFRESH');
      expect(harness.transport.calls, ['POST /auth/refresh']);
    },
  );

  test('without a Session the client refuses before any request', () async {
    final harness = _Harness(null);

    await expectLater(
      harness.client.getJson('/moods'),
      throwsA(isA<SessionExpiredException>()),
    );

    expect(harness.transport.calls, isEmpty);
  });
}
