import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/mother/models/epds_questions.dart';
import 'package:mobile/features/mother/repositories/epds_repository.dart';
import 'package:mobile/services/backend_api.dart';

import 'support/authenticated_api.dart';

const _assessment = {
  'id': 'a-1',
  'mother_id': 'mother-1',
  'instrument': 'EPDS-10',
  'instrument_version': 'demo-v1',
  'evaluation_mode': 'demo_only',
  'answers': <Object>[],
  'total_score': 14,
  'follow_up_required': true,
  'item10_positive': false,
  'immediate_review_required': false,
  'rules_version': 'demo-cope-2023-v1',
  'disclaimer':
      'Hasil ini merupakan simulasi untuk demonstrasi aplikasi. '
      'EPDS adalah instrumen skrining, bukan diagnosis.',
  'created_at': '2026-11-16T03:00:00+00:00',
};

void main() {
  test('EPDS has 10 questions with 4 options each', () {
    expect(epdsQuestions, hasLength(10));
    for (final question in epdsQuestions) {
      expect(question.options, hasLength(4));
    }
    expect(epdsQuestions.last.options[epdsSafeItem10Index], 'Tidak pernah');
  });

  test('submitting saves all 10 answers and reads the stored result', () async {
    final api = _EpdsApi();
    final result = await EpdsRepository(authenticatedApiFor(api))
        .submit(answers: [0, 1, 2, 3, 0, 1, 2, 3, 0, 3]);

    expect(api.path, '/v1/me/epds-assessments');
    expect(api.token, 'valid-access-token');
    final answers = api.body!['answers']! as List<Object?>;
    expect(answers, hasLength(10));
    expect(answers.first, {'item_id': 'Q1', 'option_index': 0});
    expect(answers.last, {'item_id': 'Q10', 'option_index': 3});
    expect(result.totalScore, 14);
    expect(result.followUpRequired, isTrue);
    expect(result.immediateReviewRequired, isFalse);
    expect(result.disclaimer, contains('bukan diagnosis'));
    expect(result.createdAt, DateTime.utc(2026, 11, 16, 3));
  });

  test('refuses to send an incomplete questionnaire', () async {
    final api = _EpdsApi();
    await expectLater(
      EpdsRepository(authenticatedApiFor(api)).submit(answers: [0, 1, 2]),
      throwsArgumentError,
    );
    expect(api.path, isNull);
  });

  test('the latest EPDS is read from the mother history', () async {
    final api = _EpdsApi(history: [_assessment]);

    final latest = await EpdsRepository(authenticatedApiFor(api))
        .latest(motherId: 'mother-1');

    expect(api.path, '/v1/mothers/mother-1/epds-assessments');
    expect(api.query, {'limit': '1'});
    expect(latest?.totalScore, 14);
  });

  test('a mother who never filled EPDS has no latest result', () async {
    final api = _EpdsApi();
    final latest = await EpdsRepository(authenticatedApiFor(api))
        .latest(motherId: 'mother-1');

    expect(latest, isNull);
  });

  test('EPDS counts as filled only from Monday of this week', () {
    EpdsResult filledAt(DateTime createdAt) => EpdsResult(
      totalScore: 5,
      followUpRequired: false,
      immediateReviewRequired: false,
      disclaimer: '',
      createdAt: createdAt,
    );
    final wednesday = DateTime(2026, 11, 18, 10);

    expect(
      epdsFilledThisWeek(filledAt(DateTime(2026, 11, 16, 9)), wednesday),
      isTrue,
    );
    expect(
      epdsFilledThisWeek(filledAt(DateTime(2026, 11, 15, 23)), wednesday),
      isFalse,
    );
    expect(epdsFilledThisWeek(null, wednesday), isFalse);
  });
}

class _EpdsApi extends BackendApi {
  _EpdsApi({this.history = const []})
    : super(baseUrl: 'https://backend.example.test');

  final List<Map<String, dynamic>> history;
  String? path;
  String? token;
  Map<String, Object?>? body;
  Map<String, String>? query;

  @override
  Future<Map<String, dynamic>> postJson(
    String path, {
    required Map<String, Object?> body,
    String? accessToken,
  }) async {
    this.path = path;
    token = accessToken;
    this.body = body;
    return {'assessment': _assessment, 'alerts': <Object>[]};
  }

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? query,
    String? accessToken,
  }) async {
    this.path = path;
    this.query = query;
    token = accessToken;
    return {'items': history, 'total': history.length, 'offset': 0, 'limit': 1};
  }
}
