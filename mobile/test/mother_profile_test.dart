import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/auth/controller/auth_controller.dart';
import 'package:mobile/features/mother/view/mother_profile_page.dart';
import 'package:mobile/services/backend_api.dart';

void main() {
  for (final live in [true, false]) {
    testWidgets(
      '${live ? 'live' : 'preview'} profile shows connection management',
      (tester) async {
        tester.view.physicalSize = const Size(390, 1237);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final api = _ProfileApi();
        addTearDown(api.close);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              backendApiProvider.overrideWithValue(api),
              backendTokenProvider.overrideWith(
                (ref) => live ? 'valid-access-token' : null,
              ),
            ],
            child: MaterialApp(
              theme: ThemeData(splashFactory: InkRipple.splashFactory),
              home: const MotherProfilePage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('mother-profile-information-card')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('mother-profile-connections')),
          findsOneWidget,
        );
        expect(find.text('Kelola Koneksi'), findsOneWidget);
        expect(
          find.byKey(const Key('mother-profile-permissions-card')),
          findsNothing,
        );
        expect(api.gets, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
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
    throw StateError('Unexpected GET: $path');
  }
}
