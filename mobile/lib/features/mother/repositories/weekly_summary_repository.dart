import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/authenticated_api.dart';
import '../../../services/backend_api.dart';
import '../../auth/controller/auth_controller.dart';

final weeklySummaryRepositoryProvider = Provider<WeeklySummaryRepository>(
  (ref) => WeeklySummaryRepository(ref.watch(authenticatedApiProvider)),
);

/// Ringkasan yang sudah tersimpan untuk minggu yang dimulai `periodStart`
/// (hari Senin, `YYYY-MM-DD`). null = belum pernah dibuat, atau mode preview.
final weeklySummaryProvider = FutureProvider.autoDispose
    .family<WeeklySummary?, String>((ref, periodStart) async {
      final token = ref.watch(backendTokenProvider);
      if (token == null) return null;
      return ref
          .watch(weeklySummaryRepositoryProvider)
          .get(periodStart: periodStart);
    });

/// Senin dari minggu yang memuat `day`. Backend hanya menerima minggu
/// Senin–Minggu.
DateTime mondayOf(DateTime day) =>
    DateTime(day.year, day.month, day.day - (day.weekday - 1));

class WeeklySummary {
  const WeeklySummary({
    required this.periodStart,
    required this.periodEnd,
    required this.status,
    required this.overview,
    required this.limitations,
  });

  final DateTime periodStart;
  final DateTime periodEnd;

  /// `completed`, `partial`, atau `failed`.
  final String status;

  /// Ringkasan dari AI. null kalau datanya kurang atau AI sedang gagal.
  final String? overview;

  /// Keterbatasan data, mis. "Catatan mood tersedia pada 3 dari 7 hari."
  final List<String> limitations;

  factory WeeklySummary.fromJson(Map<String, dynamic> json) {
    final start = json['period_start'];
    final end = json['period_end'];
    final status = json['status'];
    final overview = json['overview'];
    final limitations = json['limitations'];
    if (start is! String ||
        end is! String ||
        status is! String ||
        (overview != null && overview is! String) ||
        limitations is! List) {
      throw const FormatException('Weekly summary has an invalid shape.');
    }
    return WeeklySummary(
      periodStart: DateTime.parse(start),
      periodEnd: DateTime.parse(end),
      status: status,
      overview: overview as String?,
      limitations: [
        for (final item in limitations)
          if (item is String) item,
      ],
    );
  }
}

class WeeklySummaryRepository {
  WeeklySummaryRepository(this._api);

  final AuthenticatedApi _api;

  /// Membaca ringkasan yang sudah tersimpan. Tidak memanggil AI.
  Future<WeeklySummary?> get({required String periodStart}) async {
    try {
      return WeeklySummary.fromJson(
        await _api.getJson(
          '/summaries/weekly',
          query: {'period_start': periodStart},
        ),
      );
    } on BackendApiException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Membuat (atau memperbarui) ringkasan minggu itu. Memanggil AI, jadi
  /// bisa butuh beberapa detik.
  Future<WeeklySummary> create({required String periodStart}) async {
    return WeeklySummary.fromJson(
      await _api.postJson(
        '/summaries/weekly',
        body: {'period_start': periodStart},
      ),
    );
  }
}

String weeklySummaryFailureMessage(Object error) => switch (error) {
  ApiNetworkException() =>
    'Ringkasan belum selesai dibuat. Coba muat ulang sebentar lagi.',
  BackendApiException(statusCode: 401) =>
    'Sesi login telah berakhir. Silakan masuk kembali.',
  BackendApiException(:final message) => message,
  _ => 'Ringkasan belum dapat dibuat. Coba lagi.',
};
