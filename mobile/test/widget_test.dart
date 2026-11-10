import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:mobile/app.dart';
import 'package:mobile/features/companion/view/companion_page.dart';
import 'package:mobile/features/doctor/view/doctor_page.dart';
import 'package:mobile/features/mother/view/mother_page.dart';

void main() {
  testWidgets('fixture redirects to mother and each role route is reachable', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: DampingiApp()));
    await tester.pumpAndSettle();
    expect(find.byType(MotherPage), findsOneWidget);

    await tester.tap(find.text('Open CompanionPage'));
    await tester.pumpAndSettle();
    expect(find.byType(CompanionPage), findsOneWidget);

    await tester.tap(find.text('Open DoctorPage'));
    await tester.pumpAndSettle();
    expect(find.byType(DoctorPage), findsOneWidget);

    await tester.tap(find.text('Open MotherPage'));
    await tester.pumpAndSettle();
    expect(find.byType(MotherPage), findsOneWidget);

    GoRouter.of(tester.element(find.byType(MotherPage))).go('/unknown-route');
    await tester.pumpAndSettle();
    expect(find.text('Page not found'), findsOneWidget);
  });
}
