import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/controller/auth_controller.dart';
import '../models/mother_story.dart';
import 'daily_entry_repository.dart';

final motherStoryRepositoryProvider = Provider<MotherStoryRepository>(
  (ref) => MotherStoryRepository(),
);

/// Cerita ibu: dari backend kalau login sungguhan, dari file contoh kalau mode preview.
final motherStoriesProvider = FutureProvider<List<MotherStory>>((ref) async {
  final token = ref
      .watch(authControllerProvider)
      .asData
      ?.value
      .session
      ?.accessToken;
  if (token == null || token.startsWith('mock-')) {
    return ref.watch(motherStoryRepositoryProvider).loadStories();
  }

  final repository = ref.watch(dailyEntryRepositoryProvider);
  final today = DateTime.now();
  final startDate = isoDate(today.subtract(const Duration(days: 30)));
  final endDate = isoDate(today);
  final journals = await repository.listJournals(
    accessToken: token,
    startDate: startDate,
    endDate: endDate,
  );
  final moods = await repository.listMoods(
    accessToken: token,
    startDate: startDate,
    endDate: endDate,
  );
  return storiesFromEntries(journals: journals, moods: moods);
});

/// Satu cerita = satu jurnal, ditemani mood di hari yang sama. Terbaru di atas.
List<MotherStory> storiesFromEntries({
  required List<JournalEntry> journals,
  required List<MoodEntry> moods,
}) {
  final moodByDate = {for (final mood in moods) mood.date: mood};
  final sorted = [...journals]..sort((a, b) => b.date.compareTo(a.date));
  return [
    for (final journal in sorted) _storyFrom(journal, moodByDate[journal.date]),
  ];
}

MotherStory _storyFrom(JournalEntry journal, MoodEntry? mood) {
  final day = DateTime.parse(journal.date);
  return MotherStory(
    id: journal.id,
    weekdayIndex: day.weekday - 1,
    date: formatStoryDate(day),
    mood: mood == null ? MotherMood.neutral : MotherMood.values[mood.mood - 1],
    moodLabel: mood == null ? 'Mood belum dicatat' : _moodLabels[mood.mood - 1],
    title: journal.title,
    note: journal.content,
    // Belum ada ringkasan AI per jurnal; halaman detail menyembunyikan kotaknya.
    summary: '',
  );
}

const _moodLabels = [
  'Anda merasa sangat sedih',
  'Anda merasa sedih',
  'Anda merasa biasa saja',
  'Anda merasa senang',
  'Anda merasa sangat bahagia',
];

const _dayNames = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];

const _monthNames = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];

/// "Jumat, 13 November 2026"
String formatStoryDate(DateTime day) =>
    '${_dayNames[day.weekday - 1]}, ${day.day} ${_monthNames[day.month - 1]} ${day.year}';

/// "2026-11-03", format tanggal yang diminta backend.
String isoDate(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

class MotherStoryRepository {
  MotherStoryRepository({
    AssetBundle? assetBundle,
    this.assetPath = 'assets/fixtures/mother-stories.json',
  }) : assetBundle = assetBundle ?? rootBundle;

  final AssetBundle assetBundle;
  final String assetPath;

  Future<List<MotherStory>> loadStories() async {
    final source = await assetBundle.loadString(assetPath);
    final decoded = jsonDecode(source);
    if (decoded is! List<Object?>) {
      throw const FormatException('Mother stories fixture must be a list.');
    }

    final stories = decoded
        .map((item) {
          if (item is! Map<String, Object?>) {
            throw const FormatException(
              'Mother story entry must be an object.',
            );
          }
          return MotherStory.fromJson(item);
        })
        .toList(growable: false);

    final ids = stories.map((story) => story.id).toSet();
    if (ids.length != stories.length) {
      throw const FormatException('Mother story IDs must be unique.');
    }
    return stories;
  }
}