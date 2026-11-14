import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/mother/repositories/weekly_summary_repository.dart';
import 'package:mobile/services/backend_api.dart';

import 'support/authenticated_api.dart';

const _completed = {
  'schema_version': '1',
  'period_start': '2026-11-16',
  'period_end': '2026-11-22',
  'audience': 'mother',
  'status': 'completed',
  'overview': 'Minggu ini suasana hatimu cenderung membaik.',
  'limitations': ['Catatan mood tersedia pada 5 dari 7 hari.'],
  'source_refs': <Object>[],
  'prompt_version': 'weekly-summary-v2',
};

const _partial = {
  'schema_version': '1',
  'period_start': '2026-11-16',
  'period_end': '2026-11-22',
  'audience': 'mother',
  'status': 'partial',
  'overview': null,
  'limitations': ['Ringkasan AI tidak tersedia saat ini.'],
  'source_refs': <Object>[],
  'prompt_version': 'weekly-summary-v2',
};

void main() {
  test('mondayOf returns the Monday of that week', () {
    expect(mondayOf(DateTime(2026, 11, 16)), DateTime(2026, 11, 16));
    expect(mondayOf(DateTime(2026, 11, 18)), DateTime(2026, 11, 16));
    expect(mondayOf(DateTime(2026, 11, 22)), DateTime(2026, 11, 16));
  });

  test('a week without a saved summary reads as null', () async {
    final api = _SummaryApi();

    final summary = await WeeklySummaryRepository(authenticatedApiFor(api))
        .get(periodStart: '2026-11-16');

    expect(summary, isNull);
    expect(api.query, {'period_start': '2026-11-16'});
  });

  test('a saved summary keeps its overview and limitations', () async {
    final summary = await WeeklySummaryRepository(
      authenticatedApiFor(_SummaryApi(saved: _completed)),
    ).get(periodStart: '2026-11-16');

    expect(summary?.status, 'completed');
    expect(summary?.overview, 'Minggu ini suasana hatimu cenderung membaik.');
    expect(summary?.limitations, ['Catatan mood tersedia pada 5 dari 7 hari.']);
    expect(summary?.periodEnd, DateTime(2026, 11, 22));
  });

  test('creating a summary posts the Monday of the week', () async {
    final api = _SummaryApi(created: _partial);

    final summary = await WeeklySummaryRepository(authenticatedApiFor(api))
        .create(periodStart: '2026-11-16');

    expect(api.body, {'period_start': '2026-11-16'});
    expect(summary.status, 'partial');
    expect(summary.overview, isNull);
  });

  test('a slow summary asks the mother to reload later', () {
    expect(
      weeklySummaryFailureMessage(
        const ApiNetworkException('Permintaan ke server melewati batas waktu.'),
      ),
      'Ringkasan belum selesai dibuat. Coba muat ulang sebentar lagi.',
    );
  });
}

class _SummaryApi extends BackendApi {
  _SummaryApi({this.saved, this.created = _completed})
    : super(baseUrl: 'https://backend.example.test');

  final Map<String, dynamic>? saved;
  final Map<String, dynamic> created;
  Map<String, String>? query;
  Map<String, Object?>? body;

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? query,
    String? accessToken,
  }) async {
    this.query = query;
    final summary = saved;
    if (summary == null) {
      throw const BackendApiException(
        statusCode: 404,
        message: 'Weekly summary not found',
      );
    }
    return summary;
  }

  @override
  Future<Map<String, dynamic>> postJson(
    String path, {
    required Map<String, Object?> body,
    String? accessToken,
  }) async {
    this.body = body;
    return created;
  }
}
