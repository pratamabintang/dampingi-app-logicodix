import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/authenticated_api.dart';

final epdsRepositoryProvider = Provider<EpdsRepository>(
  (ref) => EpdsRepository(ref.watch(authenticatedApiProvider)),
);

/// Hasil `POST /epds/evaluate` (mode demo).
class EpdsResult {
  const EpdsResult({
    required this.totalScore,
    required this.followUpRequired,
    required this.immediateReviewRequired,
    required this.disclaimer,
  });

  final int totalScore;
  final bool followUpRequired;
  final bool immediateReviewRequired;
  final String disclaimer;

  factory EpdsResult.fromJson(Map<String, dynamic> json) {
    final totalScore = json['total_score'];
    final followUp = json['follow_up_required'];
    final immediate = json['immediate_review_required'];
    final disclaimer = json['disclaimer'];
    if (totalScore is! int ||
        followUp is! bool ||
        immediate is! bool ||
        disclaimer is! String) {
      throw const FormatException('EPDS result has an invalid shape.');
    }
    return EpdsResult(
      totalScore: totalScore,
      followUpRequired: followUp,
      immediateReviewRequired: immediate,
      disclaimer: disclaimer,
    );
  }
}

class EpdsRepository {
  EpdsRepository(this._api);

  final AuthenticatedApi _api;

  /// `answers[i]` = indeks pilihan (0–3) untuk pertanyaan ke-(i + 1).
  Future<EpdsResult> evaluate({required List<int> answers}) async {
    if (answers.length != 10) {
      throw ArgumentError.value(
        answers.length,
        'answers',
        'EPDS butuh 10 jawaban',
      );
    }
    final json = await _api.postJson(
      '/epds/evaluate',
      body: {
        'answers': [
          for (var index = 0; index < answers.length; index++)
            {'item_id': 'Q${index + 1}', 'option_index': answers[index]},
        ],
      },
    );
    return EpdsResult.fromJson(json);
  }
}
