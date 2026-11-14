import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/companion/view/companion_extra_pages.dart';
import 'package:mobile/features/mother/repositories/mother_story_repository.dart';
import 'package:mobile/features/mother/view/mother_notifications_page.dart';

void main() {
  Future<void> pumpNotifications(
    WidgetTester tester,
    Widget page, {
    String? token,
  }) async {
    tester.view.physicalSize = const Size(390, 891);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [backendTokenProvider.overrideWith((ref) => token)],
        child: MaterialApp(
          // Test environment ships no shaders, so the Android ink-sparkle
          // splash cannot render; the ripple keeps tap behaviour identical.
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: page,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a live Mother is told there is nothing, not shown mock people', (
    tester,
  ) async {
    await pumpNotifications(
      tester,
      const MotherNotificationsPage(),
      token: 'real-access-token',
    );

    expect(find.byKey(const Key('mother-notifications-empty')), findsOneWidget);
    expect(find.text('Notifikasi anda'), findsOneWidget);
    expect(
      find.byKey(const Key('mother-notification-companion-code')),
      findsNothing,
    );
    expect(find.textContaining('Mengundang'), findsNothing);
    expect(find.textContaining('samsidan@gmail.com'), findsNothing);
  });

  testWidgets(
    'a live Companion is told there is nothing, not shown mock cards',
    (tester) async {
      await pumpNotifications(
        tester,
        const CompanionNotificationsPage(),
        token: 'real-access-token',
      );

      expect(
        find.byKey(const Key('companion-notifications-empty')),
        findsOneWidget,
      );
      expect(find.text('Ibu membagikan catatan baru'), findsNothing);
    },
  );

  testWidgets('preview keeps the design mock, worded as a redemption', (
    tester,
  ) async {
    await pumpNotifications(tester, const MotherNotificationsPage());

    expect(find.byKey(const Key('mother-notifications-empty')), findsNothing);
    expect(find.text('Kode Undangan dari Sdr. Enzokulin'), findsOneWidget);
    expect(
      find.text('Kode Undangan dari Dr. Aisyah Salsabila'),
      findsOneWidget,
    );
    expect(find.textContaining('Mengundang'), findsNothing);
    expect(find.textContaining('diundang'), findsNothing);
    expect(find.textContaining('pendampingan'), findsNothing);

    await tester.tap(
      find.byKey(const Key('mother-notification-companion-code')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('mother-notification-confirm-redeem')),
      findsOneWidget,
    );
    expect(find.text('Tukar'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('mother-notification-confirm-redeem')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tukar kode belum tersedia.'), findsOneWidget);
  });

  testWidgets('preview keeps the Companion design mock', (tester) async {
    await pumpNotifications(tester, const CompanionNotificationsPage());

    expect(
      find.byKey(const Key('companion-notifications-empty')),
      findsNothing,
    );
    expect(find.text('Ibu membagikan catatan baru'), findsOneWidget);
    expect(find.text('Tips dukungan baru tersedia'), findsOneWidget);
  });
}
