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

const _dayNames = [
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
  'Minggu',
];

const _monthNames = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

/// "Jumat, 13 November 2026"
String formatStoryDate(DateTime day) =>
    '${_dayNames[day.weekday - 1]}, ${day.day} ${_monthNames[day.month - 1]} ${day.year}';

/// "2026-11-03", format tanggal yang diminta backend.
String isoDate(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

/// Mood beberapa hari terakhir untuk kartu "Mood hari ini".
final recentMoodsProvider = FutureProvider<List<MoodEntry>?>((ref) async {
  final token = ref
      .watch(authControllerProvider)
      .asData
      ?.value
      .session
      ?.accessToken;
  if (token == null || token.startsWith('mock-')) return null;

  final today = DateTime.now();
  return ref
      .watch(dailyEntryRepositoryProvider)
      .listMoods(
        accessToken: token,
        startDate: isoDate(today.subtract(const Duration(days: 6))),
        endDate: isoDate(today),
      );
});

/// Satu kotak di kartu mood. `mood` null = hari itu belum dicatat.
class MoodDay {
  const MoodDay({
    required this.date,
    required this.label,
    required this.isToday,
    this.mood,
  });

  final DateTime date;
  final String label;
  final bool isToday;
  final MotherMood? mood;
}

/// Hari-hari di sekitar `today`: `before` hari sebelumnya, hari ini di tengah,
/// lalu `after` hari sesudahnya (belum dicatat, karena belum terjadi).
List<MoodDay> recentMoodDays(
  List<MoodEntry> moods,
  DateTime today, {
  int before = 2,
  int after = 2,
}) {
  final byDate = {for (final mood in moods) mood.date: mood.mood};
  return [
    for (var offset = -before; offset <= after; offset++)
      _moodDay(
        DateTime(today.year, today.month, today.day + offset),
        byDate,
        isToday: offset == 0,
      ),
  ];
}

MoodDay _moodDay(
  DateTime day,
  Map<String, int> byDate, {
  required bool isToday,
}) {
  final value = byDate[isoDate(day)];
  return MoodDay(
    date: day,
    label: isToday ? 'Hari ini' : _dayShortNames[day.weekday - 1],
    isToday: isToday,
    mood: value == null ? null : MotherMood.values[value - 1],
  );
}

const _dayShortNames = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

const _moodTitles = [
  'Sangat Sedih',
  'Sedih',
  'Biasa Saja',
  'Senang',
  'Sangat Bahagia',
];

/// Nama mood, sama dengan pilihan di dialog "Catat mood".
String moodTitle(MotherMood mood) => _moodTitles[mood.index];

/// Token login sungguhan, atau null untuk mode preview (belum login / token `mock-`).
final backendTokenProvider = Provider<String?>((ref) {
  final token = ref
      .watch(authControllerProvider)
      .asData
      ?.value
      .session
      ?.accessToken;
  if (token == null || token.startsWith('mock-')) return null;
  return token;
});

/// Satu minggu di kalender: 7 kotak mood dan cerita (jurnal) minggu itu.
class CalendarWeek {
  const CalendarWeek({required this.days, required this.stories});

  final List<MoodDay> days;
  final List<MotherStory> stories;
}

/// Minggu kalender yang berakhir di `endDate` (YYYY-MM-DD), 7 hari ke belakang.
final calendarWeekProvider = FutureProvider.family<CalendarWeek, String>((
  ref,
  endDate,
) async {
  final token = ref.watch(backendTokenProvider);
  if (token == null) {
    throw StateError('Kalender dari backend hanya untuk login sungguhan.');
  }
  final end = DateTime.parse(endDate);
  final startDate = isoDate(DateTime(end.year, end.month, end.day - 6));
  final repository = ref.watch(dailyEntryRepositoryProvider);
  final moods = await repository.listMoods(
    accessToken: token,
    startDate: startDate,
    endDate: endDate,
  );
  final journals = await repository.listJournals(
    accessToken: token,
    startDate: startDate,
    endDate: endDate,
  );
  return CalendarWeek(
    days: recentMoodDays(moods, end, before: 6, after: 0),
    stories: storiesFromEntries(journals: journals, moods: moods),
  );
});

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
