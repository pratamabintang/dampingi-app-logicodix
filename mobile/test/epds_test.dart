import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/mother/models/epds_questions.dart';
import 'package:mobile/features/mother/repositories/epds_repository.dart';
import 'package:mobile/services/backend_api.dart';

void main() {
  test('EPDS has 10 questions with 4 options each', () {
    expect(epdsQuestions, hasLength(10));
    for (final question in epdsQuestions) {
      expect(question.options, hasLength(4));
    }
    expect(epdsQuestions.last.options[epdsSafeItem10Index], 'Tidak pernah');
  });

  test('sends all 10 answers to the backend in order', () async {
    final api = _EpdsApi();
    final result = await EpdsRepository(api).evaluate(
      accessToken: 'valid-access-token',
      answers: [0, 1, 2, 3, 0, 1, 2, 3, 0, 3],
    );

    expect(api.path, '/epds/evaluate');
    expect(api.token, 'valid-access-token');
    final answers = api.body!['answers']! as List<Object?>;
    expect(answers, hasLength(10));
    expect(answers.first, {'item_id': 'Q1', 'option_index': 0});
    expect(answers.last, {'item_id': 'Q10', 'option_index': 3});
    expect(result.totalScore, 14);
    expect(result.followUpRequired, isTrue);
    expect(result.immediateReviewRequired, isFalse);
    expect(result.disclaimer, contains('bukan diagnosis'));
  });

  test('refuses to send an incomplete questionnaire', () async {
    final api = _EpdsApi();
    await expectLater(
      EpdsRepository(api)
          .evaluate(accessToken: 'valid-access-token', answers: [0, 1, 2]),
      throwsArgumentError,
    );
    expect(api.path, isNull);
  });
}

class _EpdsApi extends BackendApi {
  _EpdsApi() : super(baseUrl: 'https://backend.example.test');

  String? path;
  String? token;
  Map<String, Object?>? body;

  @override
  Future<Map<String, dynamic>> postJson(
    String path, {
    required Map<String, Object?> body,
    String? accessToken,
  }) async {
    this.path = path;
    token = accessToken;
    this.body = body;
    return {
      'evaluation_mode': 'demo_only',
      'instrument': 'EPDS-10',
      'rules_version': 'demo-cope-2023-v1',
      'total_score': 14,
      'follow_up_required': true,
      'item10_positive': false,
      'immediate_review_required': false,
      'disclaimer':
          'Hasil ini merupakan simulasi untuk demonstrasi aplikasi. '
          'EPDS adalah instrumen skrining, bukan diagnosis.',
    };
  }
}
