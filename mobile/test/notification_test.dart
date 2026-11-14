import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:mobile/features/mother/view/mother_notifications_page.dart';
import 'package:mobile/features/mother/repositories/mother_alert_repository.dart';
import 'package:mobile/features/auth/controller/auth_controller.dart';

void main() {
  Future<void> pumpPage(
    WidgetTester tester,
    Widget page, {
    String? token,
    List<MotherAlert> alerts = const [],
  }) async {
    tester.view.physicalSize = const Size(390, 891);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, state) => page),
        GoRoute(
          path: '/mother/connections',
          builder: (_, state) =>
              const Scaffold(body: Text('Layar Koneksi tujuan')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backendTokenProvider.overrideWith((ref) => token),
          motherAlertsProvider.overrideWith((ref) async => alerts),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('live ibu kosong jika API mengembalikan kosong', (tester) async {
    await pumpPage(tester, const MotherNotificationsPage(), token: 'token');
    expect(find.byKey(const Key('mother-notifications-empty')), findsOneWidget);
    expect(find.text('Kode Undangan dari Sdr. Enzokulin'), findsNothing);
    await tester.tap(find.byKey(const Key('mother-notifications-connections')));
    await tester.pumpAndSettle();
    expect(find.text('Layar Koneksi tujuan'), findsOneWidget);
  });

  testWidgets('live ibu menampilkan alert dari provider', (tester) async {
    await pumpPage(
      tester,
      const MotherNotificationsPage(),
      token: 'token',
      alerts: [MotherAlert(id: 'a1', createdAt: DateTime.utc(2026, 11, 14))],
    );
    expect(find.byKey(const ValueKey('mother-alert-a1')), findsOneWidget);
    expect(find.text('Pembaruan simulasi demo'), findsOneWidget);
    expect(find.byKey(const Key('mother-notifications-empty')), findsNothing);
  });

  testWidgets('preview Tukar menuju Koneksi', (tester) async {
    await pumpPage(tester, const MotherNotificationsPage());
    expect(find.text('Kode Undangan dari Sdr. Enzokulin'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('mother-notification-companion-code')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('mother-notification-confirm-redeem')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Layar Koneksi tujuan'), findsOneWidget);
    expect(find.text('Tukar kode belum tersedia.'), findsNothing);
  });
}
