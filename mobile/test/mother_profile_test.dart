import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/mother/repositories/mother_story_repository.dart';
import 'package:mobile/features/mother/view/mother_profile_page.dart';
import 'package:mobile/services/backend_api.dart';

void main() {
  Future<void> pumpProfile(
    WidgetTester tester, {
    required BackendApi api,
    String? token = 'valid-access-token',
  }) async {
    tester.view.physicalSize = const Size(390, 1237);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backendApiProvider.overrideWithValue(api),
          backendTokenProvider.overrideWith((ref) => token),
        ],
        child: MaterialApp(
          // Test environment ships no shaders, so the Android ink-sparkle
          // splash cannot render; the ripple keeps tap behaviour identical.
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: const MotherProfilePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the live Profile leaves Koneksi to its own screen', (
    tester,
  ) async {
    final api = _ProfileApi();
    await pumpProfile(tester, api: api);

    expect(find.byKey(const Key('mother-profile-connections')), findsOneWidget);
    expect(
      find.byKey(const Key('mother-profile-invite-summary')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('mother-profile-connection-summary')),
      findsNothing,
    );
    expect(find.byKey(const Key('mother-profile-sharing-note')), findsNothing);
    expect(find.textContaining('Terhubung dengan'), findsNothing);
    expect(find.textContaining('Kode Undangan'), findsNothing);
    expect(
      find.byKey(const Key('mother-profile-permissions-card')),
      findsNothing,
    );
    expect(api.gets, isEmpty);
  });

  testWidgets('preview keeps the permission toggles and fetches nothing', (
    tester,
  ) async {
    final api = _ProfileApi();
    await pumpProfile(tester, api: api, token: null);

    expect(
      find.byKey(const Key('mother-profile-permissions-card')),
      findsOneWidget,
    );
    expect(
      find.text(
        'Pratinjau: pilih data yang boleh dilihat orang yang terhubung',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mother-profile-invite-summary')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('mother-profile-connection-summary')),
      findsNothing,
    );
    expect(api.gets, isEmpty);
  });
}

class _ProfileApi extends BackendApi {
  _ProfileApi() : super(baseUrl: 'https://backend.example.test');

  final gets = <String>[];

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? query,
    String? accessToken,
  }) async {
    gets.add(path);
    return {};
  }
}
