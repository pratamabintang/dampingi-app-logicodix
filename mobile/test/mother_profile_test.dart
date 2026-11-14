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

  testWidgets('the live Profile loads sharing controls from connections', (
    tester,
  ) async {
    final api = _ProfileApi();
    await pumpProfile(tester, api: api);

    expect(find.byKey(const Key('mother-profile-connections')), findsOneWidget);
    expect(
      find.byKey(const Key('mother-profile-permissions-card')),
      findsOneWidget,
    );
    expect(api.gets, ['/connections']);
    expect(
      find.byKey(const Key('mother-profile-no-professionals')),
      findsOneWidget,
    );
  });

  testWidgets('professional sharing starts closed and can be enabled', (
    tester,
  ) async {
    final api = _ProfileApi(withProfessional: true);
    await pumpProfile(tester, api: api);

    expect(find.text('dr. Demo'), findsOneWidget);
    expect(
      find.byKey(
        const Key('mother-profile-toggle-connection-1-weekly-summary-off'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mother-profile-toggle-connection-1-epds-off')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mother-profile-toggle-connection-1-journal-off')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(
        const Key('mother-profile-toggle-connection-1-weekly-summary-off'),
      ),
    );
    await tester.pumpAndSettle();

    expect(api.permissionPatch, {'weekly_summary': true});
    expect(
      find.byKey(
        const Key('mother-profile-toggle-connection-1-weekly-summary-on'),
      ),
      findsOneWidget,
    );
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
  _ProfileApi({this.withProfessional = false})
    : super(baseUrl: 'https://backend.example.test');

  final bool withProfessional;
  final gets = <String>[];
  final permissions = <String, dynamic>{
    'connection_id': 'connection-1',
    'weekly_summary': false,
    'epds': false,
    'journal': false,
  };
  Map<String, Object?>? permissionPatch;

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? query,
    String? accessToken,
  }) async {
    gets.add(path);
    if (path == '/connections') {
      return {
        'connections': withProfessional
            ? [
                {
                  'id': 'connection-1',
                  'counterpart': {'name': 'dr. Demo', 'role': 'professional'},
                },
              ]
            : [],
      };
    }
    if (path == '/connections/connection-1/sharing-permissions') {
      return Map<String, dynamic>.from(permissions);
    }
    throw StateError('Unexpected GET path: $path');
  }

  @override
  Future<Map<String, dynamic>> patchJson(
    String path, {
    required Map<String, Object?> body,
    String? accessToken,
  }) async {
    if (path != '/connections/connection-1/sharing-permissions') {
      throw StateError('Unexpected PATCH path: $path');
    }
    permissionPatch = body;
    permissions.addAll(body);
    return Map<String, dynamic>.from(permissions);
  }
}
