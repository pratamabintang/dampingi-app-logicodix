import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/connections/repositories/connection_repository.dart';
import 'package:mobile/features/doctor/view/doctor_profile_page.dart';
import 'package:mobile/features/mother/repositories/mother_story_repository.dart';

void main() {
  testWidgets('live profile displays an issued invitation code', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backendTokenProvider.overrideWith((ref) => 'professional-token'),
          liveInviteCodesProvider.overrideWith(
            (ref) async => [
              InviteCode(
                id: 'invite-1',
                code: 'PRO123',
                targetRole: 'mother',
                expiresAt: '2026-11-20T10:00:00Z',
              ),
            ],
          ),
        ],
        child: MaterialApp(
          home: DoctorProfilePage(bottomNavigation: const SizedBox(height: 60)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PRO123'), findsOneWidget);
    expect(find.text('AIS128'), findsNothing);
  });
}
