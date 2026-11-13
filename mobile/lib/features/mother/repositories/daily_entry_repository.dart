import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/backend_api.dart';

final dailyEntryRepositoryProvider = Provider<DailyEntryRepository>(
  (ref) => DailyEntryRepository(ref.watch(backendApiProvider)),
);

class MoodEntry {
  const MoodEntry({
    required this.id,
    required this.date,
    required this.mood,
    this.description,
  });

  final String id;
  final String date;
  final int mood;
  final String? description;

  factory MoodEntry.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final date = json['created_at'];
    final mood = json['mood'];
    final description = json['description'];
    if (id is! String ||
        date is! String ||
        mood is! int ||
        mood < 1 ||
        mood > 5 ||
        (description != null && description is! String)) {
      throw const FormatException('Mood entry has an invalid shape.');
    }
    return MoodEntry(
      id: id,
      date: date,
      mood: mood,
      description: description as String?,
    );
  }
}

/// Mood dan jurnal harian ibu.
///
/// Backend hanya menerima satu mood dan satu jurnal per hari. Kalau hari ini sudah
/// tercatat (409), entri terbaru diperbarui, sehingga ibu bisa mengubah mood-nya.
class DailyEntryRepository {
  DailyEntryRepository(this._api);

  final BackendApi _api;

  Future<MoodEntry> saveMoodToday({
    required String accessToken,
    required int mood,
    String? description,
  }) async {
    final body = <String, Object?>{
      'mood': mood,
      'description': ?description,
    };
    try {
      return MoodEntry.fromJson(
        await _api.postJson('/moods', body: body, accessToken: accessToken),
      );
    } on BackendApiException catch (error) {
      if (error.statusCode != 409) rethrow;
    }
    final latest = await listMoods(accessToken: accessToken, limit: 1);
    if (latest.isEmpty) {
      throw const FormatException('Mood hari ini tidak ditemukan.');
    }
    return MoodEntry.fromJson(
      await _api.patchJson(
        '/moods/${latest.first.id}',
        body: body,
        accessToken: accessToken,
      ),
    );
  }

  Future<List<MoodEntry>> listMoods({
    required String accessToken,
    String? startDate,
    String? endDate,
    int? limit,
  }) async {
    final json = await _api.getJson(
      '/moods',
      accessToken: accessToken,
      query: {
        'start_date': ?startDate,
        'end_date': ?endDate,
        if (limit != null) 'limit': '$limit',
      },
    );
    final moods = json['moods'];
    if (moods is! List) {
      throw const FormatException('Mood list has an invalid shape.');
    }
    final entries = <MoodEntry>[];
    for (final item in moods) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Mood list has an invalid item.');
      }
      entries.add(MoodEntry.fromJson(item));
    }
    return entries;
  }

  Future<void> saveJournalToday({
    required String accessToken,
    required String title,
    required String content,
  }) async {
    final body = <String, Object?>{'title': title, 'content': content};
    try {
      await _api.postJson('/journals', body: body, accessToken: accessToken);
      return;
    } on BackendApiException catch (error) {
      if (error.statusCode != 409) rethrow;
    }
    final json = await _api.getJson(
      '/journals',
      accessToken: accessToken,
      query: const {'limit': '1'},
    );
    final journals = json['journals'];
    if (journals is! List ||
        journals.isEmpty ||
        journals.first is! Map<String, dynamic> ||
        (journals.first as Map<String, dynamic>)['id'] is! String) {
      throw const FormatException('Jurnal hari ini tidak ditemukan.');
    }
    final id = (journals.first as Map<String, dynamic>)['id'] as String;
    await _api.patchJson('/journals/$id', body: body, accessToken: accessToken);
  }
}