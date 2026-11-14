import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/companion/repositories/observation_repository.dart';
import 'package:mobile/features/connections/repositories/connection_repository.dart';
import 'package:mobile/services/backend_api.dart';

import 'support/authenticated_api.dart';

import 'package:mobile/features/auth/controller/auth_controller.dart';

const _motherConnection = {
  'id': 'conn-1',
  'connected_at': '2026-11-14T10:00:00+00:00',
  'counterpart': {'id': 'mother-1', 'name': 'Ibu Seed', 'role': 'mother'},
};

void main() {
  test('a connection carries the counterpart account id when sent', () {
    final person = ConnectionPerson.fromJson(_motherConnection);
    expect(person.id, 'conn-1');
    expect(person.userId, 'mother-1');

    final older = ConnectionPerson.fromJson({
      'id': 'conn-1',
      'connected_at': '2026-11-14T10:00:00+00:00',
      'counterpart': {'name': 'Ibu Seed', 'role': 'mother'},
    });
    expect(older.userId, isNull);
  });

  test(
    'submitting creates a draft then completes it with server ids',
    () async {
      final api = _ObservationApi();
      final answers = List<int>.filled(observationQuestions.length, 2);

      await ObservationRepository(authenticatedApiFor(api, token: 'token'))
          .submit(
            motherId: 'mother-1',
            selectedOptions: answers,
            day: DateTime(2026, 11, 14),
          );

      expect(api.posts.single.$1, '/observations');
      expect(api.posts.single.$2['mother_id'], 'mother-1');
      final questions = api.posts.single.$2['questions'] as List;
      expect(questions.length, observationQuestions.length);
      expect(
        [for (final question in questions) (question as Map)['prompt']],
        [for (final question in observationQuestions) question.prompt],
      );
      // Tiap soal membawa pilihannya sendiri, bukan satu daftar bersama.
      expect(
        [for (final question in questions) (question as Map)['options']],
        [
          for (final question in observationQuestions)
            [
              for (final label in question.options) {'label': label},
            ],
        ],
      );
      expect(api.patches.single.$1, '/observations/obs-1');
      expect(api.patches.single.$2, {
        'answers': [
          for (var index = 0; index < observationQuestions.length; index++)
            {'question_id': 'q${index + 1}', 'option_id': 'q${index + 1}o3'},
        ],
        'day': '2026-11-14',
      });
    },
  );

  test(
    "today's status asks for completed observations on the connection",
    () async {
      final api = _ObservationApi(total: 1);

      final done = await ObservationRepository(
        authenticatedApiFor(api, token: 'token'),
      ).hasCompletedFor(connectionId: 'conn-1', day: DateTime(2026, 11, 14));

      expect(done, isTrue);
      expect(api.queries.single, {
        'connection_id': 'conn-1',
        'day': '2026-11-14',
        'status': 'completed',
      });
    },
  );

  test('the dashboard finds the connected mother', () async {
    final container = ProviderContainer(
      overrides: [
        backendApiProvider.overrideWithValue(
          _ObservationApi(connections: [_motherConnection]),
        ),
        backendTokenProvider.overrideWith((ref) => 'token'),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      companionMotherProvider.future,
      (previous, next) {},
    );
    addTearDown(subscription.close);

    final mother = await subscription.read();

    expect(mother?.name, 'Ibu Seed');
    expect(mother?.userId, 'mother-1');
  });

  test('preview mode has no connected mother', () async {
    final container = ProviderContainer(
      overrides: [
        backendApiProvider.overrideWithValue(_ObservationApi()),
        backendTokenProvider.overrideWith((ref) => null),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      companionMotherProvider.future,
      (previous, next) {},
    );
    addTearDown(subscription.close);

    expect(await subscription.read(), isNull);
  });

  test('a second observation on the same day reads as already filled', () {
    expect(
      observationFailureMessage(
        const BackendApiException(
          statusCode: 409,
          message: 'An Observation already exists for 2026-11-14',
        ),
      ),
      'Observasi untuk hari ini sudah diisi.',
    );
  });
}

class _ObservationApi extends BackendApi {
  _ObservationApi({this.total = 0, this.connections = const []})
    : super(baseUrl: 'https://backend.example.test');

  final int total;
  final List<Map<String, dynamic>> connections;
  final posts = <(String, Map<String, Object?>)>[];
  final patches = <(String, Map<String, Object?>)>[];
  final queries = <Map<String, String>?>[];

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? query,
    String? accessToken,
  }) async {
    if (path == '/connections') return {'connections': connections};
    queries.add(query);
    return {
      'observations': <Object>[],
      'count': 0,
      'offset': 0,
      'limit': 100,
      'total': total,
    };
  }

  @override
  Future<Map<String, dynamic>> postJson(
    String path, {
    required Map<String, Object?> body,
    String? accessToken,
  }) async {
    posts.add((path, body));
    return {
      'id': 'obs-1',
      'questions': [
        for (var index = 0; index < observationQuestions.length; index++)
          {
            'id': 'q${index + 1}',
            'prompt': observationQuestions[index].prompt,
            'options': [
              for (
                var option = 0;
                option < observationQuestions[index].options.length;
                option++
              )
                {
                  'id': 'q${index + 1}o${option + 1}',
                  'label': observationQuestions[index].options[option],
                },
            ],
          },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> patchJson(
    String path, {
    required Map<String, Object?> body,
    String? accessToken,
  }) async {
    patches.add((path, body));
    return {'id': 'obs-1', 'status': 'completed'};
  }
}
