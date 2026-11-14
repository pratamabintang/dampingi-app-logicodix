import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/authenticated_api.dart';
import '../../auth/controller/auth_controller.dart';

final epdsRepositoryProvider = Provider<EpdsRepository>(
  (ref) => EpdsRepository(ref.watch(authenticatedApiProvider)),
);

final epdsWeekStatusProvider = FutureProvider.autoDispose<EpdsWeekStatus?>((ref) async {
  if (ref.watch(backendTokenProvider) == null) return null;
  return ref.watch(epdsRepositoryProvider).weekStatus();
});

class EpdsWeekStatus {
  const EpdsWeekStatus({required this.filled, required this.canSubmit, required this.nextAvailableDate});
  final bool filled;
  final bool canSubmit;
  final String nextAvailableDate;

  factory EpdsWeekStatus.fromJson(Map<String, dynamic> json) {
    final filled = json['filled'];
    final allowed = json['can_submit'];
    if (filled is! bool || allowed is! bool || json['next_available_date'] is! String) {
      throw const FormatException('Status EPDS tidak sesuai.');
    }
    return EpdsWeekStatus(filled: filled, canSubmit: allowed, nextAvailableDate: json['next_available_date'] as String);
  }
}

/// EPDS terakhir milik ibu yang login. null = belum pernah mengisi, atau
/// mode preview.
final latestEpdsProvider = FutureProvider.autoDispose<EpdsResult?>((ref) async {
  final token = ref.watch(backendTokenProvider);
  final motherId = ref
      .watch(authControllerProvider)
      .asData
      ?.value
      .session
      ?.user
      .id;
  if (token == null || motherId == null) return null;
  return ref.watch(epdsRepositoryProvider).latest(motherId: motherId);
});

/// EPDS mingguan dianggap sudah diisi kalau ada hasil sejak Senin minggu ini.
bool epdsFilledThisWeek(EpdsResult? latest, DateTime now) {
  final createdAt = latest?.createdAt;
  if (createdAt == null) return false;
  final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
  return !createdAt.toLocal().isBefore(monday);
}

/// Satu hasil EPDS (mode demo) yang tersimpan di backend.
class EpdsResult {
  const EpdsResult({
    required this.totalScore,
    required this.followUpRequired,
    required this.immediateReviewRequired,
    required this.disclaimer,
    this.createdAt,
  });

  final int totalScore;
  final bool followUpRequired;
  final bool immediateReviewRequired;
  final String disclaimer;

  /// Kapan EPDS ini dikirim. null kalau backend tidak menyebutkannya.
  final DateTime? createdAt;

  factory EpdsResult.fromJson(Map<String, dynamic> json) {
    final totalScore = json['total_score'];
    final followUp = json['follow_up_required'];
    final immediate = json['immediate_review_required'];
    final disclaimer = json['disclaimer'];
    final createdAt = json['created_at'];
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
      createdAt: createdAt is String ? DateTime.tryParse(createdAt) : null,
    );
  }
}

class EpdsRepository {
  EpdsRepository(this._api);

  final AuthenticatedApi _api;

  Future<EpdsWeekStatus> weekStatus() async => EpdsWeekStatus.fromJson(
    await _api.getJson('/v1/me/epds-status'),
  );

  /// Menghitung **dan menyimpan** EPDS.
  /// `answers[i]` = indeks pilihan (0–3) untuk pertanyaan ke-(i + 1).
  Future<EpdsResult> submit({required List<int> answers}) async {
    if (answers.length != 10) {
      throw ArgumentError.value(
        answers.length,
        'answers',
        'EPDS butuh 10 jawaban',
      );
    }
    final json = await _api.postJson(
      '/v1/me/epds-assessments',
      body: {
        'answers': [
          for (var index = 0; index < answers.length; index++)
            {'item_id': 'Q${index + 1}', 'option_index': answers[index]},
        ],
      },
    );
    final assessment = json['assessment'];
    if (assessment is! Map<String, dynamic>) {
      throw const FormatException('EPDS submission has an invalid shape.');
    }
    return EpdsResult.fromJson(assessment);
  }

  /// EPDS terbaru milik ibu ini, atau null kalau belum pernah mengisi.
  Future<EpdsResult?> latest({required String motherId}) async {
    final json = await _api.getJson(
      '/v1/mothers/$motherId/epds-assessments',
      query: {'limit': '1'},
    );
    final items = json['items'];
    if (items is! List) {
      throw const FormatException('EPDS history has an invalid shape.');
    }
    if (items.isEmpty) return null;
    final first = items.first;
    if (first is! Map<String, dynamic>) {
      throw const FormatException('EPDS history has an invalid shape.');
    }
    return EpdsResult.fromJson(first);
  }
}
