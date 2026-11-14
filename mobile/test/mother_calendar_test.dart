import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/mother/models/mother_story.dart';
import 'package:mobile/features/mother/repositories/mother_story_repository.dart';
import 'package:mobile/features/mother/view/mother_calendar_page.dart';
import 'package:mobile/features/mother/view/mother_meditation_pages.dart';
import 'package:mobile/features/mother/view/mother_story_detail_page.dart';
import 'package:mobile/services/backend_api.dart';
import 'package:mobile/features/auth/controller/auth_controller.dart';

import 'mother_story_test_data.dart';

final _testStory = MotherStory(
  id: 'very-sad',
  weekdayIndex: 0,
  date: 'Senin, 12 Agustus 2026',
  mood: MotherMood.verySad,
  moodLabel: 'Anda merasa sangat sedih',
  title: 'Hal Kecil yang berarti',
  note:
      'Senang karena ada suami yang bantu aku untuk ke belakang, kok bisa '
      'suami bantu aku ke belakang padahal suami lagi di luar kota.',
  summary:
      'Senang karena ada suami yang bantu aku untuk ke belakang, kok bisa '
      'suami bantu aku ke belakang padahal suami lagi di luar kota.',
  description: 'Kesepian, Lelah',
  day: isoDate(DateTime.now()),
);

void main() {
  test(
    'mother story fixture has unique IDs and complete detail data',
    () async {
      final stories = await MotherStoryRepository().loadStories();
      expect(stories, hasLength(6));
      expect(stories.map((story) => story.id).toSet(), hasLength(6));
      expect(
        stories.map((story) => story.summary).toSet().length,
        greaterThan(1),
      );
    },
  );

  testWidgets('calendar shows weekly overview and selected-day design', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _withStoryFixture(const MaterialApp(home: MotherCalendarPage())),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('1-7 Agu 2026'), findsOneWidget);
    expect(
      find.byKey(const Key('mother-calendar-epds-summary')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mother-calendar-story-0-tile')),
      findsOneWidget,
    );
    final happyFaceSize = tester.getSize(
      find.byKey(const Key('mother-calendar-story-2-face')),
    );
    final secondHappyFaceSize = tester.getSize(
      find.byKey(const Key('mother-calendar-story-3-face')),
    );
    expect(happyFaceSize, secondHappyFaceSize);
    expect(happyFaceSize.height, MotherMood.happy.faceHeight);
    final mondayExpression = tester.getSize(
      find.byKey(const Key('mother-calendar-expression-Sen')),
    );
    expect(mondayExpression.width, closeTo(32.3235, 0.001));
    expect(mondayExpression.height, closeTo(16.6992, 0.001));
    final tuesdayExpression = tester.getSize(
      find.byKey(const Key('mother-calendar-expression-Sel')),
    );
    expect(tuesdayExpression.width, closeTo(31.6212, 0.001));
    expect(tuesdayExpression.height, closeTo(15.0165, 0.001));
    final thursdayExpression = tester.getSize(
      find.byKey(const Key('mother-calendar-expression-Kam')),
    );
    expect(thursdayExpression.width, closeTo(31.6192, 0.001));
    expect(thursdayExpression.height, closeTo(9.1278, 0.001));
    final fridayExpression = tester.getSize(
      find.byKey(const Key('mother-calendar-expression-Jum')),
    );
    expect(fridayExpression.width, closeTo(31.6752, 0.001));
    expect(fridayExpression.height, closeTo(15.0167, 0.001));
    final saturdayExpression = tester.getSize(
      find.byKey(const Key('mother-calendar-expression-Sab')),
    );
    expect(saturdayExpression.width, closeTo(32.3745, 0.001));
    expect(saturdayExpression.height, closeTo(15.0168, 0.001));
    final sundayExpression = tester.getSize(
      find.byKey(const Key('mother-calendar-expression-Min')),
    );
    expect(sundayExpression.width, closeTo(31.6714, 0.001));
    expect(sundayExpression.height, closeTo(19.3495, 0.001));

    await tester.tap(find.byKey(const Key('mother-calendar-day-Sab')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mother-calendar-epds-summary')), findsNothing);
    expect(find.text('Cerita terakhirmu'), findsOneWidget);
    expect(
      find.byKey(const Key('mother-calendar-story-0-tile')),
      findsOneWidget,
    );
    final selectedDay = tester.widget<Container>(
      find.byKey(const Key('mother-calendar-day-Sab')),
    );
    expect(
      (selectedDay.decoration! as BoxDecoration).border!.top.color,
      AppTheme.coralText,
    );

    await tester.tap(find.byKey(const Key('mother-calendar-day-Sab')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('mother-calendar-epds-summary')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mother-calendar-story-0-tile')),
      findsOneWidget,
    );
    final unselectedDay = tester.widget<Container>(
      find.byKey(const Key('mother-calendar-day-Sab')),
    );
    expect((unselectedDay.decoration! as BoxDecoration).border, isNull);
  });

  testWidgets('calendar brand keeps the standard logo size on narrow screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _withStoryFixture(const MaterialApp(home: MotherCalendarPage())),
    );

    final brand = tester.widget<Text>(find.text('Dampingi'));
    expect(brand.style?.fontSize, 24);
  });

  testWidgets('calendar brand position matches the activity suggestions page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _withStoryFixture(const MaterialApp(home: MotherCalendarPage())),
    );
    await tester.pumpAndSettle();
    final calendarLogoRect = tester.getRect(find.text('Dampingi'));

    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        child: const MaterialApp(home: MotherMeditationListPage()),
      ),
    );
    await tester.pumpAndSettle();
    final activitiesLogoRect = tester.getRect(find.text('Dampingi'));

    expect(calendarLogoRect, activitiesLogoRect);
  });

  testWidgets('story detail matches the Figma content and expands the note', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: MotherStoryDetailPage(story: _testStory)),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Senin, 12 Agustus 2026'), findsOneWidget);
    expect(find.text('Anda merasa sangat sedih'), findsOneWidget);
    expect(find.text('Kesepian, Lelah'), findsOneWidget);
    expect(find.text('Ringkasan AI'), findsOneWidget);
    expect(find.text('Hal Kecil yang berarti'), findsOneWidget);
    expect(find.text('Buka di chat AI'), findsOneWidget);
    expect(find.text('Ubah catatan mood'), findsOneWidget);

    final storyText = tester.widget<Text>(
      find.byKey(const Key('mother-story-detail-text')),
    );
    expect(storyText.maxLines, 1);
    await tester.tap(find.byKey(const Key('mother-story-toggle-text')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Text>(find.byKey(const Key('mother-story-detail-text')))
          .maxLines,
      isNull,
    );
    expect(find.text('Lihat lebih sedikit'), findsOneWidget);

    final editMoodButton = find.byKey(const Key('mother-story-edit-mood'));
    await tester.scrollUntilVisible(
      editMoodButton,
      120,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('mother-story-detail-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(editMoodButton);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mother-mood-entry-dialog')), findsOneWidget);
    await tester.tap(find.byKey(const Key('mother-mood-dialog-continue')));
    await tester.pumpAndSettle();
    expect(find.text('Lelah'), findsOneWidget);
    await tester.tap(find.byKey(const Key('mother-mood-dialog-continue')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('mother-journal-title')))
          .controller
          ?.text,
      _testStory.title,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('mother-journal-story')))
          .controller
          ?.text,
      _testStory.note,
    );
    await tester.tap(find.byKey(const Key('mother-mood-dialog-close')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('story detail hides the expand toggle for a short note', (
    tester,
  ) async {
    const shortStory = MotherStory(
      id: 'short',
      weekdayIndex: 0,
      date: 'Senin, 12 Agustus 2026',
      mood: MotherMood.neutral,
      moodLabel: 'Anda merasa biasa saja',
      title: 'Singkat',
      note: 'Hari yang tenang.',
      summary: '',
    );
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: MotherStoryDetailPage(story: shortStory)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hari yang tenang.'), findsOneWidget);
    expect(find.byKey(const Key('mother-story-toggle-text')), findsNothing);
    expect(find.text('Lihat lebih banyak'), findsNothing);
  });

  testWidgets('live calendar shows the stories of the last seven days', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backendTokenProvider.overrideWithValue('valid-access-token'),
          backendApiProvider.overrideWithValue(_LiveWeekApi()),
        ],
        child: const MaterialApp(home: MotherCalendarPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const Key('mother-calendar-story-0-row')),
      findsOneWidget,
    );
    expect(find.text('Sabtu'), findsOneWidget);
    expect(
      find.byKey(const Key('mother-calendar-empty-stories')),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('mother-calendar-day-Rab')));
    await tester.pumpAndSettle();
    expect(find.text('Cerita hari Rabu.'), findsOneWidget);
  });

  testWidgets('a past story hides the edit-mood button', (tester) async {
    const pastStory = MotherStory(
      id: 'past',
      weekdayIndex: 2,
      date: 'Rabu, 12 Agustus 2026',
      mood: MotherMood.neutral,
      moodLabel: 'Anda merasa biasa saja',
      title: 'Kemarin',
      note: 'Catatan hari yang sudah berlalu.',
      summary: '',
      day: '2026-08-12',
    );
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: MotherStoryDetailPage(story: pastStory)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mother-story-edit-mood')), findsNothing);
    expect(find.text('Ubah catatan mood'), findsNothing);
    expect(find.text('Buka di chat AI'), findsOneWidget);
  });

  testWidgets('story detail shows an explicit missing-note state', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: MotherStoryDetailPage())),
    );
    expect(find.text('Catatan tidak tersedia'), findsOneWidget);
    expect(find.byKey(const Key('mother-story-detail-card')), findsNothing);
  });

  testWidgets('week arrows update the date range and show an empty state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _withStoryFixture(const MaterialApp(home: MotherCalendarPage())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mother-calendar-next-week')));
    await tester.pumpAndSettle();

    expect(find.text('8-14 Agu 2026'), findsOneWidget);
    expect(find.byKey(const Key('mother-calendar-epds-summary')), findsNothing);
    expect(
      find.byKey(const Key('mother-calendar-empty-stories')),
      findsOneWidget,
    );
    final unsetMoodDay = tester.widget<Container>(
      find.byKey(const Key('mother-calendar-day-Sen')),
    );
    final unsetMoodDecoration = unsetMoodDay.decoration! as BoxDecoration;
    expect(unsetMoodDecoration.color, AppTheme.unselectedSurface);
    expect(unsetMoodDecoration.borderRadius, BorderRadius.circular(12));
    expect(
      find.byKey(const Key('mother-calendar-expression-Sen')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}

Widget _withStoryFixture(Widget child) => ProviderScope(
  overrides: [
    motherStoriesProvider.overrideWith((ref) async => motherStoryTestData),
  ],
  child: child,
);

class _LiveWeekApi extends BackendApi {
  _LiveWeekApi() : super(baseUrl: 'https://backend.example.test');

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
          'content': 'Cerita minggu ini.',
        },
        {
          'id': 'j-2',
          'user_id': 'mother-1',
          'created_at': '2026-11-11',
          'title': 'Rabu',
          'content': 'Cerita hari Rabu.',
        },
      ],
      'count': 1,
      'offset': 0,
      'limit': 100,
      'total': 1,
    };
  }
}
