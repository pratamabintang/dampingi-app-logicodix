import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/auth/controller/auth_controller.dart';
import 'package:mobile/features/auth/models/login_models.dart';
import 'package:mobile/features/auth/repositories/auth_repository.dart';
import 'package:mobile/features/mother/controller/daily_entry_controller.dart';
import 'package:mobile/models/app_role.dart';
import 'package:mobile/services/backend_api.dart';
import 'package:mobile/services/role_repository.dart';

const _todayMood = {
  'id': 'mood-1',
  'user_id': 'mother-1',
  'created_at': '2026-11-13',
  'mood': 2,
  'description': 'Lelah',
};

void main() {
  test(
    'saves mood with feelings and skips the journal when story is empty',
    () async {
      final api = _RecordingBackendApi();
      final controller = await _loggedIn(api);

      final result = await controller.save(
        mood: 2,
        feelings: ['Lelah', 'Cemas'],
        title: '',
        story: '   ',
      );

      expect(result.status, DailyEntryStatus.saved);
      expect(api.calls, ['POST /moods']);
      expect(api.bodies.single, {'mood': 2, 'description': 'Lelah, Cemas'});
      expect(api.tokens.single, 'valid-access-token');
    },
  );

  test(
    'saves the journal with a default title when only the story is filled',
    () async {
      final api = _RecordingBackendApi();
      final controller = await _loggedIn(api);

      await controller.save(
        mood: 4,
        feelings: const [],
        title: ' ',
        story: 'Hari ini lumayan.',
      );

      expect(api.calls, ['POST /moods', 'POST /journals']);
      expect(api.bodies.first, {'mood': 4});
      expect(api.bodies.last, {
        'title': 'Catatan harian',
        'content': 'Hari ini lumayan.',
      });
    },
  );

  test(
    'updates today\'s mood when the backend says it already exists (409)',
    () async {
      final api = _RecordingBackendApi(moodAlreadyExists: true);
      final controller = await _loggedIn(api);

      final result = await controller.save(
        mood: 5,
        feelings: const [],
        title: '',
        story: '',
      );

      expect(result.status, DailyEntryStatus.saved);
      expect(api.calls, ['POST /moods', 'GET /moods', 'PATCH /moods/mood-1']);
      expect(api.queries[1], {'limit': '1'});
      expect(api.bodies.last, {'mood': 5});
    },
  );

  test('preview login never calls the backend', () async {
    final api = _RecordingBackendApi();
    final container = ProviderContainer(
      overrides: [
        roleRepositoryProvider.overrideWithValue(_MotherRoleRepository()),
        backendApiProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);
    await container
        .read(authControllerProvider.notifier)
        .login(email: 'demo.mother@dampingi.test', password: 'demo1234');

    final result = await container
        .read(dailyEntryControllerProvider)
        .save(mood: 3, feelings: const [], title: '', story: '');

    expect(result.status, DailyEntryStatus.preview);
    expect(result.canContinue, isTrue);
    expect(api.calls, isEmpty);
  });

  test(
    'a failed mood save keeps the dialog open with a clear message',
    () async {
      final api = _RecordingBackendApi(
        moodError: const BackendApiException(statusCode: 401, message: 'x'),
      );
      final controller = await _loggedIn(api);

      final result = await controller.save(
        mood: 3,
        feelings: const [],
        title: '',
        story: 'cerita',
      );

      expect(result.canContinue, isFalse);
      expect(
        result.message,
        'Sesi login telah berakhir. Silakan masuk kembali.',
      );
      expect(api.calls, ['POST /moods']); // jurnal tidak dicoba
    },
  );
}

Future<DailyEntryController> _loggedIn(_RecordingBackendApi api) async {
  final container = ProviderContainer(
    overrides: [
      roleRepositoryProvider.overrideWithValue(_MotherRoleRepository()),
      authRepositoryProvider.overrideWithValue(_ValidAuthRepository()),
      backendApiProvider.overrideWithValue(api),
      backendTokenProvider.overrideWithValue('valid-access-token'),
    ],
  );
  addTearDown(container.dispose);
  await container.read(authControllerProvider.future);
  await container
      .read(authControllerProvider.notifier)
      .login(email: 'mother@example.test', password: 'password');
  return container.read(dailyEntryControllerProvider);
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

class _RecordingBackendApi extends BackendApi {
  _RecordingBackendApi({this.moodAlreadyExists = false, this.moodError})
    : super(baseUrl: 'https://backend.example.test');

  final bool moodAlreadyExists;
  final BackendApiException? moodError;

  final calls = <String>[];
  final bodies = <Map<String, Object?>>[];
  final queries = <Map<String, String>?>[];
  final tokens = <String?>[];

  void _record(
    String call, {
    Map<String, Object?>? body,
    Map<String, String>? query,
    String? token,
  }) {
    calls.add(call);
    if (body != null) bodies.add(body);
    queries.add(query);
    tokens.add(token);
  }

  @override
  Future<Map<String, dynamic>> postJson(
    String path, {
    required Map<String, Object?> body,
    String? accessToken,
  }) async {
    _record('POST $path', body: body, token: accessToken);
    if (path == '/moods') {
      final error = moodError;
      if (error != null) throw error;
      if (moodAlreadyExists) {
        throw const BackendApiException(statusCode: 409, message: 'exists');
      }
      return {..._todayMood, 'mood': body['mood']};
    }
    return {
      'id': 'journal-1',
      'user_id': 'mother-1',
      'created_at': '2026-11-13',
      ...body,
    };
  }

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? query,
    String? accessToken,
  }) async {
    _record('GET $path', query: query, token: accessToken);
    return {
      'moods': [_todayMood],
      'count': 1,
      'offset': 0,
      'limit': 1,
      'total': 1,
    };
  }

  @override
  Future<Map<String, dynamic>> patchJson(
    String path, {
    required Map<String, Object?> body,
    String? accessToken,
  }) async {
    _record('PATCH $path', body: body, token: accessToken);
    return {..._todayMood, ...body};
  }
}
