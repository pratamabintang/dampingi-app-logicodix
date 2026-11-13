import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/backend_api.dart';
import '../../auth/controller/auth_controller.dart';
import '../repositories/daily_entry_repository.dart';
import '../repositories/mother_story_repository.dart';

final dailyEntryControllerProvider = Provider<DailyEntryController>(
  (ref) => DailyEntryController(ref),
);

enum DailyEntryStatus { saved, savedWithoutJournal, preview, failed }

class DailyEntryResult {
  const DailyEntryResult(this.status, [this.message]);

  final DailyEntryStatus status;
  final String? message;

  /// Dialog boleh lanjut ke layar ringkasan kecuali mood gagal disimpan.
  bool get canContinue => status != DailyEntryStatus.failed;
}

class DailyEntryController {
  DailyEntryController(this._ref);

  final Ref _ref;

  /// Simpan mood hari ini (wajib) dan jurnal (opsional, kalau cerita diisi).
  Future<DailyEntryResult> save({
    required int mood,
    required List<String> feelings,
    required String title,
    required String story,
  }) async {
    final session = _ref.read(authControllerProvider).asData?.value.session;
    final token = session?.accessToken;
    if (token == null || token.startsWith('mock-')) {
      return const DailyEntryResult(
        DailyEntryStatus.preview,
        'Mode pratinjau aktif. Mood belum disimpan ke server.',
      );
    }

    final repository = _ref.read(dailyEntryRepositoryProvider);
    final description = feelings.isEmpty ? null : _limit(feelings.join(', '), 500);
    try {
      await repository.saveMoodToday(
        accessToken: token,
        mood: mood,
        description: description,
      );
    } catch (error) {
      return DailyEntryResult(DailyEntryStatus.failed, _messageFor(error));
    }

    final content = story.trim();
    if (content.isEmpty) {
      _ref.invalidate(motherStoriesProvider);
      return const DailyEntryResult(DailyEntryStatus.saved);
    }
    final heading = title.trim().isEmpty ? 'Catatan harian' : title.trim();
    try {
      await repository.saveJournalToday(
        accessToken: token,
        title: _limit(heading, 255),
        content: _limit(content, 10000),
      );
      _ref.invalidate(motherStoriesProvider);
      return const DailyEntryResult(DailyEntryStatus.saved);
    } catch (error) {
      _ref.invalidate(motherStoriesProvider);
      return DailyEntryResult(
        DailyEntryStatus.savedWithoutJournal,
        'Mood tersimpan, tapi catatan belum tersimpan: ${_messageFor(error)}',
      );
    }
  }

  static String _limit(String text, int max) =>
      text.length <= max ? text : text.substring(0, max);

  static String _messageFor(Object error) {
    return switch (error) {
      BackendApiException(statusCode: 401) =>
        'Sesi login telah berakhir. Silakan masuk kembali.',
      BackendApiException(statusCode: 403) =>
        'Hanya akun ibu yang dapat mencatat mood.',
      BackendApiException(:final message) => message,
      ApiConfigurationException(:final message) => message,
      ApiNetworkException(:final message) => message,
      _ => 'Respons server tidak dapat dibaca. Coba lagi.',
    };
  }
}