
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/authenticated_api.dart';
import '../../../services/backend_api.dart';
import '../../auth/controller/auth_controller.dart';

final dailySummaryRepositoryProvider = Provider<DailySummaryRepository>(
  (ref) => DailySummaryRepository(ref.watch(authenticatedApiProvider)),
);

/// Ringkasan tersimpan untuk tanggal lokal tertentu (YYYY-MM-DD).
/// null berarti belum ada ringkasan atau sedang dalam mode preview.
final dailySummaryProvider = FutureProvider.autoDispose
    .family<DailySummary?, String>((ref, summaryDate) async {
      final token = ref.watch(backendTokenProvider);
      if (token == null) return null;

      return ref
          .watch(dailySummaryRepositoryProvider)
          .get(summaryDate: summaryDate);
    });

class DailySummary {
  const DailySummary({
    required this.summaryDate,
    required this.status,
    required this.overview,
    required this.limitations,
  });

  final DateTime summaryDate;
  final String status;
  final String? overview;
  final List<String> limitations;

  factory DailySummary.fromJson(Map<String, dynamic> json) {
    final date = json['summary_date'];
    final status = json['status'];
    final overview = json['overview'];
    final limitations = json['limitations'];

    if (date is! String ||
        status is! String ||
        (overview != null && overview is! String) ||
        limitations is! List) {
      throw const FormatException('Daily summary has an invalid shape.');
    }

    return DailySummary(
      summaryDate: DateTime.parse(date),
      status: status,
      overview: overview as String?,
      limitations: [
        for (final item in limitations)
          if (item is String) item,
      ],
    );
  }
}

class DailySummaryRepository {
  DailySummaryRepository(this._api);

  final AuthenticatedApi _api;

  /// Membaca ringkasan yang sudah tersimpan. Tidak memanggil AI.
  Future<DailySummary?> get({required String summaryDate}) async {
    try {
      return DailySummary.fromJson(
        await _api.getJson(
          '/summaries/daily',
          query: {'summary_date': summaryDate},
        ),
      );
    } on BackendApiException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }
}

String dailySummaryFailureMessage(Object error) => switch (error) {
  ApiNetworkException() =>
    'Ringkasan belum dapat dimuat. Periksa koneksi dan coba lagi.',
  BackendApiException(statusCode: 401) =>
    'Sesi login telah berakhir. Silakan masuk kembali.',
  BackendApiException(:final message) => message,
  _ => 'Ringkasan belum dapat dimuat. Coba lagi.',
};
