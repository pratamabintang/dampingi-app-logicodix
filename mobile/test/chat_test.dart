import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/auth/controller/auth_controller.dart';
import 'package:mobile/features/auth/models/login_models.dart';
import 'package:mobile/features/auth/repositories/auth_repository.dart';
import 'package:mobile/features/mother/controller/chat_controller.dart';
import 'package:mobile/features/mother/models/chat_models.dart';
import 'package:mobile/models/app_role.dart';
import 'package:mobile/services/backend_api.dart';
import 'package:mobile/services/role_repository.dart';

void main() {
  const Map<String, dynamic> successfulResponse = {
    'session_id': 'session-1',
    'user_message': {'id': 'user-1', 'role': 'user', 'content': 'Hai'},
    'reply': {
      'id': 'assistant-1',
      'role': 'assistant',
      'content': 'Halo, saya mendengarkan.',
    },
    'urgent': true,
    'context_used': ['mood_7d'],
  };

  test('chat response parses the actual backend fields', () {
    final response = ChatResponse.fromJson(successfulResponse);

    expect(response.sessionId, 'session-1');
    expect(response.userMessage.content, 'Hai');
    expect(response.reply.content, 'Halo, saya mendengarkan.');
    expect(response.urgent, isTrue);
    expect(response.contextUsed, ['mood_7d']);
  });

  test('chat response rejects messages returned in the wrong roles', () {
    final invalid = {
      ...successfulResponse,
      'reply': {
        'id': 'assistant-1',
        'role': 'user',
        'content': 'Not an assistant reply',
      },
    };

    expect(() => ChatResponse.fromJson(invalid), throwsFormatException);
  });

  test('default preview login works without configuring the backend', () async {
    final container = ProviderContainer(
      overrides: [
        roleRepositoryProvider.overrideWithValue(_MotherRoleRepository()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authControllerProvider.future);
    final response = await container
        .read(authControllerProvider.notifier)
        .login(email: 'demo.mother@dampingi.test', password: 'demo1234');

    expect(response?.user.role, AppRole.mother);
    expect(response?.accessToken, 'mock-access-token');
  });

  test(
    'chat sends once, prevents duplicate submissions, and reuses session',
    () async {
      final api = _PendingBackendApi();
      final container = _authenticatedContainer(api);
      addTearDown(container.dispose);
      addTearDown(api.close);

      await container.read(authControllerProvider.future);
      await container
          .read(authControllerProvider.notifier)
          .login(email: 'mother@example.test', password: 'password');
      await container.read(chatControllerProvider.future);

      final controller = container.read(chatControllerProvider.notifier);
      final firstRequest = controller.send('Hai');
      expect(
        container.read(chatControllerProvider).requireValue.isSending,
        isTrue,
      );
      expect(await controller.send('Jangan dikirim dua kali'), isFalse);
      expect(api.requestCount, 1);
      expect(api.lastBody, {'message': 'Hai', 'session_id': null});
      expect(api.lastAccessToken, 'valid-access-token');

      api.pending.complete(successfulResponse);
      expect(await firstRequest, isTrue);
      expect(
        container.read(chatControllerProvider).requireValue.messages,
        hasLength(2),
      );
      expect(
        container.read(chatControllerProvider).requireValue.urgent,
        isTrue,
      );
      expect(container.read(chatControllerProvider).requireValue.contextUsed, [
        'mood_7d',
      ]);

      api.pending = Completer<Map<String, dynamic>>();
      final secondRequest = controller.send('Lanjut');
      await Future<void>.delayed(Duration.zero);
      expect(api.lastBody, {'message': 'Lanjut', 'session_id': 'session-1'});
      api.pending.complete({
        ...successfulResponse,
        'session_id': 'session-1',
        'user_message': {'id': 'user-2', 'role': 'user', 'content': 'Lanjut'},
      });
      expect(await secondRequest, isTrue);
      expect(api.requestCount, 2);
    },
  );

  test('chat opens the latest conversation from the backend', () async {
    final api = _ScriptedBackendApi(
      sessions: [_session],
      messages: [
        {
          'id': 'm-1',
          'role': 'user',
          'content': 'Hai',
          'created_at': '2026-11-14T01:00:00Z',
        },
        {
          'id': 'm-2',
          'role': 'assistant',
          'content': 'Halo, saya mendengarkan.',
          'created_at': '2026-11-14T01:00:02Z',
        },
      ],
    );
    final container = await _loggedIn(api);

    final chat = container.read(chatControllerProvider).requireValue;
    expect(api.gets, ['/chat/sessions', '/chat/sessions/session-9/messages']);
    expect(chat.sessionId, 'session-9');
    expect(chat.messages.map((message) => message.content), [
      'Hai',
      'Halo, saya mendengarkan.',
    ]);

    await container.read(chatControllerProvider.notifier).send('Lanjut');
    expect(api.bodies.single, {'message': 'Lanjut', 'session_id': 'session-9'});
  });

  test(
    'a missing conversation is forgotten so the next message starts fresh',
    () async {
      final api = _ScriptedBackendApi(
        sessions: [_session],
        postError: const BackendApiException(
          statusCode: 404,
          message: 'Percakapan tidak ditemukan.',
        ),
      );
      final container = await _loggedIn(api);

      final sent = await container
          .read(chatControllerProvider.notifier)
          .send('Hai');

      final chat = container.read(chatControllerProvider).requireValue;
      expect(sent, isFalse);
      expect(api.bodies.single['session_id'], 'session-9');
      expect(chat.sessionId, isNull);
      expect(chat.errorMessage, contains('percakapan baru'));
    },
  );

  test('limit messages from the backend are shown as they are', () async {
    const limit =
        'Batas 50 pesan per 24 jam sudah tercapai. Coba lagi nanti, ya.';
    final api = _ScriptedBackendApi(
      postError: const BackendApiException(statusCode: 429, message: limit),
    );
    final container = await _loggedIn(api);

    await container.read(chatControllerProvider.notifier).send('Hai');

    expect(
      container.read(chatControllerProvider).requireValue.errorMessage,
      limit,
    );
  });
}

ProviderContainer _authenticatedContainer(BackendApi api) {
  return ProviderContainer(
    overrides: [
      roleRepositoryProvider.overrideWithValue(_MotherRoleRepository()),
      authRepositoryProvider.overrideWithValue(_ValidAuthRepository()),
      backendApiProvider.overrideWithValue(api),
      backendTokenProvider.overrideWithValue('valid-access-token'),
    ],
  );
}

class _MotherRoleRepository extends RoleRepository {
  @override
  Future<AppRole?> loadStartupRole() async => AppRole.mother;
}

class _ValidAuthRepository implements AuthRepository {
  @override
  Future<LoginResponse> login({required LoginRequest request}) async {
    return const LoginResponse(
      accessToken: 'valid-access-token',
      user: AuthUser(
        id: 'mother-1',
        email: 'mother@example.test',
        name: 'Ibu',
        role: AppRole.mother,
      ),
    );
  }

  @override
  Future<void> register({required RegisterRequest request}) async {}
}

class _PendingBackendApi extends BackendApi {
  _PendingBackendApi() : super(baseUrl: 'https://backend.example.test');

  Completer<Map<String, dynamic>> pending = Completer<Map<String, dynamic>>();
  var requestCount = 0;
  Map<String, Object?>? lastBody;
  String? lastAccessToken;

  @override
  Future<Map<String, dynamic>> postJson(
    String path, {
    required Map<String, Object?> body,
    String? accessToken,
  }) {
    expect(path, '/chat');
    requestCount++;
    lastBody = body;
    lastAccessToken = accessToken;
    return pending.future;
  }

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? query,
    String? accessToken,
  }) async {
    // Belum ada percakapan tersimpan.
    return {'sessions': <Object?>[], 'count': 0};
  }
}

const Map<String, dynamic> _session = {
  'id': 'session-9',
  'title': 'Hai',
  'created_at': '2026-11-14T01:00:00Z',
  'updated_at': '2026-11-14T01:00:02Z',
};

Future<ProviderContainer> _loggedIn(BackendApi api) async {
  final container = _authenticatedContainer(api);
  addTearDown(container.dispose);
  await container.read(authControllerProvider.future);
  await container
      .read(authControllerProvider.notifier)
      .login(email: 'mother@example.test', password: 'password');
  await container.read(chatControllerProvider.future);
  return container;
}

class _ScriptedBackendApi extends BackendApi {
  _ScriptedBackendApi({
    this.sessions = const [],
    this.messages = const [],
    this.postError,
  }) : super(baseUrl: 'https://backend.example.test');

  final List<Map<String, dynamic>> sessions;
  final List<Map<String, dynamic>> messages;
  final BackendApiException? postError;

  final gets = <String>[];
  final bodies = <Map<String, Object?>>[];

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? query,
    String? accessToken,
  }) async {
    gets.add(path);
    if (path == '/chat/sessions') {
      return {'sessions': sessions, 'count': sessions.length};
    }
    return {'messages': messages, 'count': messages.length};
  }

  @override
  Future<Map<String, dynamic>> postJson(
    String path, {
    required Map<String, Object?> body,
    String? accessToken,
  }) async {
    bodies.add(body);
    final error = postError;
    if (error != null) throw error;
    return {
      'session_id': body['session_id'] ?? 'session-new',
      'user_message': {'id': 'u-1', 'role': 'user', 'content': body['message']},
      'reply': {'id': 'a-1', 'role': 'assistant', 'content': 'Baik.'},
      'urgent': false,
      'context_used': <String>[],
    };
  }
}
