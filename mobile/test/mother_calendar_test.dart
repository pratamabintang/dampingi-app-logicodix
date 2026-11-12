import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/mother/view/mother_calendar_page.dart';

void main() {
  testWidgets('calendar shows weekly overview and selected-day design', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: MotherCalendarPage())),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('1-7 Agu 2026'), findsOneWidget);
    expect(
      find.byKey(const Key('mother-calendar-epds-summary')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mother-calendar-story-face-0')),
      findsOneWidget,
    );
    final mondayExpression = tester.getSize(
      find.byKey(const Key('mother-calendar-expression-Sen')),
    );
    expect(mondayExpression.width, closeTo(32.3235, 0.001));
    expect(mondayExpression.height, closeTo(16.6992, 0.001));
    final thursdayExpression = tester.getSize(
      find.byKey(const Key('mother-calendar-expression-Kam')),
    );
    expect(thursdayExpression.width, closeTo(31.6192, 0.001));
    expect(thursdayExpression.height, closeTo(9.1278, 0.001));
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
      find.byKey(const Key('mother-calendar-story-face-0')),
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
      find.byKey(const Key('mother-calendar-story-face-5')),
      findsOneWidget,
    );
    final unselectedDay = tester.widget<Container>(
      find.byKey(const Key('mother-calendar-day-Sab')),
    );
    expect((unselectedDay.decoration! as BoxDecoration).border, isNull);
  });

  testWidgets('week arrows update the date range and show an empty state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: MotherCalendarPage())),
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
    expect(tester.takeException(), isNull);
  });
}
