import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/authenticated_api.dart';
import '../../auth/controller/auth_controller.dart';
import '../../mother/repositories/daily_entry_repository.dart';

final companionHistoryRepositoryProvider = Provider<CompanionHistoryRepository>(
  (ref) => CompanionHistoryRepository(ref.watch(authenticatedApiProvider)),
);

final companionWeekProvider = FutureProvider.autoDispose
    .family<CompanionWeek, String>((ref, start) async {
      if (ref.watch(backendTokenProvider) == null) {
        return const CompanionWeek(journals: [], observations: []);
      }
      return ref.watch(companionHistoryRepositoryProvider).week(start);
    });

final companionRecentNotesProvider =
    FutureProvider.autoDispose<List<JournalEntry>>((ref) async {
      if (ref.watch(backendTokenProvider) == null) return const [];
      return ref.watch(companionHistoryRepositoryProvider).recent();
    });

final companionNoteProvider = FutureProvider.autoDispose
    .family<JournalEntry, String>((ref, id) {
      // Mengikuti perubahan sesi agar hasil dari akun lama tidak dipakai ulang.
      if (ref.watch(backendTokenProvider) == null) {
        throw const FormatException('Masuk kembali untuk membaca catatan.');
      }
      return ref.watch(companionHistoryRepositoryProvider).note(id);
    });

String companionDay(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

DateTime companionMonday(DateTime now) =>
    DateTime(now.year, now.month, now.day - (now.weekday - 1));

class CompanionWeek {
  const CompanionWeek({required this.journals, required this.observations});
  final List<JournalEntry> journals;
  final List<CompanionObservation> observations;
}

class CompanionObservation {
  const CompanionObservation({
    required this.id,
    required this.day,
    required this.motherId,
    required this.answers,
  });
  final String id;
  final String day;
  final String motherId;
  final List<({String question, String answer})> answers;

  factory CompanionObservation.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final day = json['day'];
    final motherId = json['mother_id'];
    final questions = json['questions'];
    final rawAnswers = json['answers'];
    if (id is! String ||
        day is! String ||
        motherId is! String ||
        questions is! List ||
        rawAnswers is! List ||
        json['status'] != 'completed') {
      throw const FormatException('Format observasi tidak sesuai.');
    }
    final answers = <({String question, String answer})>[];
    for (final question in questions) {
      if (question is! Map<String, dynamic> ||
          question['id'] is! String ||
          question['prompt'] is! String ||
          question['options'] is! List) {
        throw const FormatException('Format pertanyaan tidak sesuai.');
      }
      final matches = rawAnswers
          .where(
            (answer) =>
                answer is Map<String, dynamic> &&
                answer['question_id'] == question['id'],
          )
          .toList();
      if (matches.length != 1) {
        throw const FormatException('Jawaban observasi tidak lengkap.');
      }
      final answer = matches.single as Map<String, dynamic>;
      final options = (question['options'] as List)
          .where(
            (option) =>
                option is Map<String, dynamic> &&
                option['id'] == answer['option_id'] &&
                option['label'] is String,
          )
          .toList();
      if (options.length != 1) {
        throw const FormatException('Pilihan observasi tidak ditemukan.');
      }
      answers.add((
        question: question['prompt'] as String,
        answer: (options.single as Map<String, dynamic>)['label'] as String,
      ));
    }
    return CompanionObservation(
      id: id,
      day: day,
      motherId: motherId,
      answers: answers,
    );
  }
}

class CompanionHistoryRepository {
  CompanionHistoryRepository(this._api);
  final AuthenticatedApi _api;

  Future<List<Map<String, dynamic>>> _all(
    String path,
    String key,
    Map<String, String> filters,
  ) async {
    final result = <Map<String, dynamic>>[];
    var offset = 0;
    while (true) {
      final json = await _api.getJson(
        path,
        query: {...filters, 'offset': '$offset', 'limit': '100'},
      );
      final items = json[key];
      final total = json['total'];
      if (items is! List || total is! int || total < 0) {
        throw const FormatException('Daftar riwayat tidak sesuai.');
      }
      for (final item in items) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException('Isi riwayat tidak sesuai.');
        }
        result.add(item);
      }
      offset += items.length;
      if (offset >= total) break;
      if (items.isEmpty) {
        throw const FormatException('Halaman riwayat tidak lengkap.');
      }
    }
    return result;
  }

  Future<CompanionWeek> week(String start) async {
    final end = companionDay(
      DateTime.parse(start).add(const Duration(days: 6)),
    );
    final journals = await _all('/journals', 'journals', {
      'start_date': start,
      'end_date': end,
    });
    // /observations belum menyediakan filter rentang tanggal.
    // Ambil seluruh halaman milik akun ini, lalu filter tanggal di aplikasi.
    final observations = await _all('/observations', 'observations', {
      'status': 'completed',
    });
    final notes = journals.map(JournalEntry.fromJson).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final records =
        observations
            .map(CompanionObservation.fromJson)
            .where(
              (item) =>
                  item.day.compareTo(start) >= 0 &&
                  item.day.compareTo(end) <= 0,
            )
            .toList()
          ..sort((a, b) => b.day.compareTo(a.day));
    return CompanionWeek(journals: notes, observations: records);
  }

  Future<List<JournalEntry>> recent() async {
    final json = await _api.getJson('/journals', query: {'limit': '3'});
    final items = json['journals'];
    if (items is! List)
      throw const FormatException('Daftar catatan tidak sesuai.');
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          JournalEntry.fromJson(item)
        else
          throw const FormatException('Isi catatan tidak sesuai.'),
    ];
  }

  Future<JournalEntry> note(String id) async =>
      JournalEntry.fromJson(await _api.getJson('/journals/$id'));

  Future<void> save({
    String? id,
    required String day,
    required String title,
    required String content,
  }) async {
    final body = <String, Object?>{
      'title': title.trim(),
      'content': content.trim(),
    };
    if (id == null) {
      await _api.postJson('/journals', body: {...body, 'created_at': day});
    } else {
      // Edit hanya ID yang sedang dibuka; jangan menimpa catatan terbaru.
      await _api.patchJson('/journals/$id', body: body);
    }
  }
}
