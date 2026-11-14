import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/authenticated_api.dart';
import '../../../services/backend_api.dart';

final dailyEntryRepositoryProvider = Provider<DailyEntryRepository>(
  (ref) => DailyEntryRepository(ref.watch(authenticatedApiProvider)),
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

class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.date,
    required this.title,
    required this.content,
  });

  final String id;
  final String date;
  final String title;
  final String content;

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final date = json['created_at'];
    final title = json['title'];
    final content = json['content'];
    if (id is! String ||
        date is! String ||
        title is! String ||
        content is! String) {
      throw const FormatException('Journal entry has an invalid shape.');
    }
    return JournalEntry(id: id, date: date, title: title, content: content);
  }
}

/// Mood dan jurnal harian ibu.
///
/// Backend hanya menerima satu mood dan satu jurnal per hari. Kalau hari ini sudah
/// tercatat (409), entri terbaru diperbarui, sehingga ibu bisa mengubah mood-nya.
class DailyEntryRepository {
  DailyEntryRepository(this._api);

  final AuthenticatedApi _api;

  Future<MoodEntry> saveMoodToday({
    required int mood,
    String? description,
  }) async {
    final body = <String, Object?>{'mood': mood, 'description': ?description};
    try {
      return MoodEntry.fromJson(await _api.postJson('/moods', body: body));
    } on BackendApiException catch (error) {
      if (error.statusCode != 409) rethrow;
    }
    final latest = await listMoods(limit: 1);
    if (latest.isEmpty) {
      throw const FormatException('Mood hari ini tidak ditemukan.');
    }
    return MoodEntry.fromJson(
      await _api.patchJson('/moods/${latest.first.id}', body: body),
    );
  }

  Future<List<MoodEntry>> listMoods({
    String? startDate,
    String? endDate,
    int? limit,
  }) async {
    final json = await _api.getJson(
      '/moods',
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

  Future<List<JournalEntry>> listJournals({
    required String startDate,
    required String endDate,
  }) async {
    final json = await _api.getJson(
      '/journals',
      query: {'start_date': startDate, 'end_date': endDate},
    );
    final journals = json['journals'];
    if (journals is! List) {
      throw const FormatException('Journal list has an invalid shape.');
    }
    final entries = <JournalEntry>[];
    for (final item in journals) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Journal list has an invalid item.');
      }
      entries.add(JournalEntry.fromJson(item));
    }
    return entries;
  }

  Future<void> saveJournalToday({
    required String title,
    required String content,
  }) async {
    final body = <String, Object?>{'title': title, 'content': content};
    try {
      await _api.postJson('/journals', body: body);
      return;
    } on BackendApiException catch (error) {
      if (error.statusCode != 409) rethrow;
    }
    final json = await _api.getJson('/journals', query: const {'limit': '1'});
    final journals = json['journals'];
    if (journals is! List ||
        journals.isEmpty ||
        journals.first is! Map<String, dynamic> ||
        (journals.first as Map<String, dynamic>)['id'] is! String) {
      throw const FormatException('Jurnal hari ini tidak ditemukan.');
    }
    final id = (journals.first as Map<String, dynamic>)['id'] as String;
    await _api.patchJson('/journals/$id', body: body);
  }
}
