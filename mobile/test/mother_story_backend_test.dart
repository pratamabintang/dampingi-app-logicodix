import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/mother/models/mother_story.dart';
import 'package:mobile/features/mother/repositories/daily_entry_repository.dart';
import 'package:mobile/features/mother/repositories/mother_story_repository.dart';
import 'package:mobile/services/backend_api.dart';
import 'package:mobile/features/auth/controller/auth_controller.dart';

import 'support/authenticated_api.dart';

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
        MoodEntry(
          id: 'm-1',
          date: '2026-11-13',
          mood: 5,
          description: 'Bersemangat, Tenang',
        ),
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
    expect(newest.day, '2026-11-13');
    expect(newest.description, 'Bersemangat, Tenang');
    expect(newest.summary, isEmpty);
    expect(stories.last.mood, MotherMood.verySad);
    expect(stories.last.description, isEmpty);
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
    final journals = await DailyEntryRepository(authenticatedApiFor(api))
        .listJournals(startDate: '2026-10-14', endDate: '2026-11-13');

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

  test('calendar week holds 7 days ending on the given day', () async {
    final api = _WeekApi();
    final container = ProviderContainer(
      overrides: [
        backendTokenProvider.overrideWithValue('valid-access-token'),
        backendApiProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);

    final week = await container.read(
      calendarWeekProvider('2026-11-14').future,
    );

    expect(api.queries['/moods'], {
      'start_date': '2026-11-08',
      'end_date': '2026-11-14',
    });
    expect(api.queries['/journals'], {
      'start_date': '2026-11-08',
      'end_date': '2026-11-14',
    });
    expect(week.days, hasLength(7));
    expect(isoDate(week.days.first.date), '2026-11-08');
    expect(isoDate(week.days.last.date), '2026-11-14');
    expect(week.days.last.mood, MotherMood.happy);
    expect(week.stories.single.title, 'Sabtu');
    expect(week.stories.single.mood, MotherMood.happy);
  });
  test('today entry preloads the saved mood, feelings, and journal', () async {
    final api = _TodayApi();
    final container = ProviderContainer(
      overrides: [
        backendTokenProvider.overrideWithValue('valid-access-token'),
        backendApiProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);

    final entry = await container.read(todayEntryProvider.future);

    expect(entry?.mood, 4);
    expect(entry?.feelings, ['Senang', 'Bersyukur']);
    expect(entry?.journalTitle, 'Hari ini');
    expect(entry?.journalContent, 'Cerita tersimpan');
  });

  test('today entry is absent without a live session', () async {
    final container = ProviderContainer(
      overrides: [backendTokenProvider.overrideWithValue(null)],
    );
    addTearDown(container.dispose);

    expect(await container.read(todayEntryProvider.future), isNull);
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

class _WeekApi extends BackendApi {
  _WeekApi() : super(baseUrl: 'https://backend.example.test');

  final queries = <String, Map<String, String>?>{};

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? query,
    String? accessToken,
  }) async {
    queries[path] = query;
    if (path == '/moods') {
      return {
        'moods': [
          {
            'id': 'm-1',
            'user_id': 'mother-1',
            'created_at': '2026-11-14',
            'mood': 4,
            'description': null,
          },
        ],
        'count': 1,
        'offset': 0,
        'limit': 100,
        'total': 1,
      };
    }
    return {
      'journals': [
        {
          'id': 'j-1',
          'user_id': 'mother-1',
          'created_at': '2026-11-14',
          'title': 'Sabtu',
          'content': 'Isi',
        },
      ],
      'count': 1,
      'offset': 0,
      'limit': 100,
      'total': 1,
    };
  }
}

class _TodayApi extends BackendApi {
  _TodayApi() : super(baseUrl: 'https://backend.example.test');

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? query,
    String? accessToken,
  }) async {
    if (path == '/moods') {
      return {
        'moods': [
          {
            'id': 'm-1',
            'user_id': 'mother-1',
            'created_at': '2026-11-14',
            'mood': 4,
            'description': 'Senang, Bersyukur',
          },
        ],
        'count': 1,
        'offset': 0,
        'limit': 100,
        'total': 1,
      };
    }
    return {
      'journals': [
        {
          'id': 'j-1',
          'user_id': 'mother-1',
          'created_at': '2026-11-14',
          'title': 'Hari ini',
          'content': 'Cerita tersimpan',
        },
      ],
      'count': 1,
      'offset': 0,
      'limit': 100,
      'total': 1,
    };
  }
}
