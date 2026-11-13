import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/mother/models/mother_story.dart';
import 'package:mobile/features/mother/repositories/daily_entry_repository.dart';
import 'package:mobile/features/mother/repositories/mother_story_repository.dart';
import 'package:mobile/services/backend_api.dart';

void main() {
  test('joins each journal with the mood of the same day, newest first', () {
    final stories = storiesFromEntries(
      journals: const [
        JournalEntry(
          id: 'j-old',
          date: '2026-11-10',
          title: 'Selasa',
          content: 'Cerita lama',
        ),
        JournalEntry(
          id: 'j-new',
          date: '2026-11-13',
          title: 'Jumat',
          content: 'Cerita baru',
        ),
      ],
      moods: const [
        MoodEntry(id: 'm-1', date: '2026-11-13', mood: 5),
        MoodEntry(id: 'm-2', date: '2026-11-10', mood: 1),
      ],
    );

    expect(stories.map((story) => story.id), ['j-new', 'j-old']);
    final newest = stories.first;
    expect(newest.date, 'Jumat, 13 November 2026');
    expect(newest.weekdayIndex, 4);
    expect(newest.mood, MotherMood.veryHappy);
    expect(newest.moodLabel, 'Anda merasa sangat bahagia');
    expect(newest.title, 'Jumat');
    expect(newest.note, 'Cerita baru');
    expect(newest.summary, isEmpty);
    expect(stories.last.mood, MotherMood.verySad);
  });

  test('a journal without a mood that day is shown as neutral', () {
    final stories = storiesFromEntries(
      journals: const [
        JournalEntry(
          id: 'j-1',
          date: '2026-11-12',
          title: 'Kamis',
          content: 'Isi',
        ),
      ],
      moods: const [],
    );

    expect(stories.single.mood, MotherMood.neutral);
    expect(stories.single.moodLabel, 'Mood belum dicatat');
  });

  test('lists journals for a date range with the access token', () async {
    final api = _JournalsApi();
    final journals = await DailyEntryRepository(api).listJournals(
      accessToken: 'valid-access-token',
      startDate: '2026-10-14',
      endDate: '2026-11-13',
    );

    expect(api.calls, ['GET /journals']);
    expect(api.queries.single, {
      'start_date': '2026-10-14',
      'end_date': '2026-11-13',
    });
    expect(api.tokens.single, 'valid-access-token');
    expect(journals.single.title, 'Hari ini');
    expect(journals.single.date, '2026-11-13');
  });

  test('formats dates the way the backend expects', () {
    expect(isoDate(DateTime(2026, 3, 7)), '2026-03-07');
  });

  test('mood card puts today in the middle', () {
    final days = recentMoodDays(const [
      MoodEntry(id: 'm-1', date: '2026-11-13', mood: 4),
      MoodEntry(id: 'm-2', date: '2026-11-12', mood: 2),
    ], DateTime(2026, 11, 13, 21, 30));

    expect(days.map((day) => day.label), [
      'Rab',
      'Kam',
      'Hari ini',
      'Sab',
      'Min',
    ]);
    expect(days.map((day) => day.isToday), [false, false, true, false, false]);
    expect(days.map((day) => day.mood), [
      null,
      MotherMood.sad,
      MotherMood.happy,
      null,
      null,
    ]);
  });

  test('mood card days cross a month boundary correctly', () {
    final days = recentMoodDays(const [], DateTime(2026, 12, 1));

    expect(isoDate(days.first.date), '2026-11-29');
    expect(isoDate(days.last.date), '2026-12-03');
    expect(days.map((day) => day.label), [
      'Min',
      'Sen',
      'Hari ini',
      'Rab',
      'Kam',
    ]);
  });

  test('mood titles match the mood entry dialog', () {
    expect(moodTitle(MotherMood.verySad), 'Sangat Sedih');
    expect(moodTitle(MotherMood.happy), 'Senang');
  });
}

class _JournalsApi extends BackendApi {
  _JournalsApi() : super(baseUrl: 'https://backend.example.test');

  final calls = <String>[];
  final queries = <Map<String, String>?>[];
  final tokens = <String?>[];

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? query,
    String? accessToken,
  }) async {
    calls.add('GET $path');
    queries.add(query);
    tokens.add(accessToken);
    return {
      'journals': [
        {
          'id': 'j-1',
          'user_id': 'mother-1',
          'created_at': '2026-11-13',
          'title': 'Hari ini',
          'content': 'Lumayan.',
        },
      ],
      'count': 1,
      'offset': 0,
      'limit': 100,
      'total': 1,
    };
  }
}
