import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/connections/preview_invite_codes.dart';
import 'package:mobile/features/connections/view/koneksi_page.dart';
import 'package:mobile/features/mother/repositories/mother_story_repository.dart';
import 'package:mobile/models/app_role.dart';
import 'package:mobile/services/backend_api.dart';

const _companionCode = {
  'id': 'code-1',
  'code': 'KDMN-PRTG',
  'target_role': 'companion',
  'expires_at': '2026-11-14T15:00:00+00:00',
};

const _professionalCode = {
  'id': 'code-2',
  'code': 'KDNK-SHTP',
  'target_role': 'professional',
  'expires_at': '2026-11-14T15:30:00+00:00',
};

const _companionConnection = {
  'id': 'conn-1',
  'connected_at': '2026-11-14T10:00:00+00:00',
  'counterpart': {'name': 'Pendamping Seed', 'role': 'companion'},
};

const _professionalConnection = {
  'id': 'conn-2',
  'connected_at': '2026-11-14T10:00:00+00:00',
  'counterpart': {'name': 'Dr. Seed', 'role': 'professional'},
};

const _motherConnection = {
  'id': 'conn-3',
  'connected_at': '2026-11-14T10:00:00+00:00',
  'counterpart': {'name': 'Ibu Seed', 'role': 'mother'},
};

void main() {
  Future<void> pumpKoneksi(
    WidgetTester tester, {
    required _KoneksiApi api,
    String? token = 'valid-access-token',
    AppRole role = AppRole.mother,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
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
          home: KoneksiPage(role: role),
        ),
      ),
    );
  }

  Future<void> reveal(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      120,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('koneksi-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a Mother sees her Companion and Professional told apart', (
    tester,
  ) async {
    final api = _KoneksiApi(
      connections: [_companionConnection, _professionalConnection],
    );
    await pumpKoneksi(tester, api: api);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('koneksi-connection-conn-1')), findsOneWidget);
    expect(find.text('Pendamping Seed'), findsOneWidget);
    expect(find.text('Dr. Seed'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('koneksi-connection-role-conn-1')))
          .data,
      'Pendamping',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('koneksi-connection-role-conn-2')))
          .data,
      'Tenaga kesehatan',
    );
    expect(find.byKey(const Key('koneksi-connections-empty')), findsNothing);
    expect(find.textContaining('@'), findsNothing);
    expect(find.byKey(const Key('koneksi-sharing-note')), findsOneWidget);
  });

  testWidgets('a Companion sees the Mother connected to them', (tester) async {
    final api = _KoneksiApi(connections: [_motherConnection]);
    await pumpKoneksi(tester, api: api, role: AppRole.companion);
    await tester.pumpAndSettle();

    expect(find.text('Ibu Seed'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('koneksi-connection-role-conn-3')))
          .data,
      'Ibu',
    );
    expect(find.byKey(const Key('koneksi-connections-empty')), findsNothing);
    expect(find.byKey(const Key('koneksi-sharing-note')), findsNothing);
  });

  testWidgets('a Professional sees the Mothers connected to them', (
    tester,
  ) async {
    final api = _KoneksiApi(connections: [_motherConnection]);
    await pumpKoneksi(tester, api: api, role: AppRole.professional);
    await tester.pumpAndSettle();

    expect(find.text('Ibu Seed'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('koneksi-connection-role-conn-3')))
          .data,
      'Ibu',
    );
    expect(find.byKey(const Key('koneksi-connections-empty')), findsNothing);
    expect(find.byKey(const Key('koneksi-sharing-note')), findsNothing);
  });

  testWidgets('no Connections and no codes are two different empty states', (
    tester,
  ) async {
    final api = _KoneksiApi();
    await pumpKoneksi(tester, api: api);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('koneksi-connections-empty')), findsOneWidget);
    expect(find.text('Belum ada Koneksi'), findsOneWidget);
    expect(find.byKey(const Key('koneksi-empty')), findsOneWidget);
    expect(find.text('Belum ada Kode Undangan'), findsOneWidget);
  });

  testWidgets('ending a Connection removes it after confirming', (
    tester,
  ) async {
    final api = _KoneksiApi(connections: [_companionConnection]);
    await pumpKoneksi(tester, api: api);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('koneksi-end-conn-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('koneksi-end-dialog')), findsOneWidget);

    await tester.tap(find.byKey(const Key('koneksi-end-confirm')));
    await tester.pumpAndSettle();

    expect(api.deletes, ['/connections/conn-1']);
    expect(find.byKey(const Key('koneksi-connection-conn-1')), findsNothing);
    expect(find.byKey(const Key('koneksi-connections-empty')), findsOneWidget);
    expect(api.connectionReads, greaterThan(1));
  });

  testWidgets('shows the live Invite codes with their target Role and expiry', (
    tester,
  ) async {
    final api = _KoneksiApi(codes: [_companionCode, _professionalCode]);
    await pumpKoneksi(tester, api: api);
    await tester.pumpAndSettle();

    expect(find.text('Koneksi'), findsOneWidget);
    expect(find.byKey(const Key('koneksi-code-code-1')), findsOneWidget);
    expect(find.text('KDMN-PRTG'), findsOneWidget);
    await reveal(tester, find.byKey(const Key('koneksi-code-code-2')));
    expect(find.text('Untuk Pendamping'), findsOneWidget);
    expect(find.text('Untuk Tenaga kesehatan'), findsOneWidget);
    expect(find.textContaining('Berlaku sampai'), findsNWidgets(2));
  });

  testWidgets('opening the screen only reads: it creates no Invite code', (
    tester,
  ) async {
    final api = _KoneksiApi(codes: [_companionCode]);
    await pumpKoneksi(tester, api: api);
    await tester.pumpAndSettle();

    expect(api.posts, isEmpty);
    expect(api.gets, contains('/connections/invite-codes'));
    expect(api.tokens, everyElement('valid-access-token'));
  });

  testWidgets('a live list that is empty names the reason', (tester) async {
    final api = _KoneksiApi();
    await pumpKoneksi(tester, api: api);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('koneksi-empty')), findsOneWidget);
    expect(find.text('Belum ada Kode Undangan'), findsOneWidget);
    expect(find.textContaining('kedaluwarsa'), findsOneWidget);
    expect(find.byKey(const Key('koneksi-error')), findsNothing);
  });

  testWidgets('a failed read looks different from an empty list', (
    tester,
  ) async {
    final api = _KoneksiApi(
      error: const ApiNetworkException('Jaringan putus.'),
    );
    await pumpKoneksi(tester, api: api);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('koneksi-error')), findsOneWidget);
    expect(find.text('Jaringan putus.'), findsWidgets);
    expect(find.byKey(const Key('koneksi-empty')), findsNothing);
    expect(find.text('Belum ada Kode Undangan'), findsNothing);
  });

  testWidgets('a retry asks the backend again', (tester) async {
    final api = _KoneksiApi(
      error: const ApiNetworkException('Jaringan putus.'),
    );
    await pumpKoneksi(tester, api: api);
    await tester.pumpAndSettle();

    api.error = null;
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('koneksi-error')),
        matching: find.text('Coba lagi'),
      ),
    );
    await tester.pumpAndSettle();

    expect(api.gets.length, greaterThan(1));
    expect(find.byKey(const Key('koneksi-error')), findsNothing);
    expect(find.byKey(const Key('koneksi-empty')), findsOneWidget);
  });

  testWidgets('shows a loading state while the list is on its way', (
    tester,
  ) async {
    final gate = Completer<void>();
    final api = _KoneksiApi(codes: [_companionCode], gate: gate);
    await pumpKoneksi(tester, api: api);
    await tester.pump();

    expect(find.byKey(const Key('koneksi-loading')), findsOneWidget);
    expect(find.byKey(const Key('koneksi-empty')), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('KDMN-PRTG'), findsOneWidget);
  });

  testWidgets('pull to refresh asks the backend again', (tester) async {
    final api = _KoneksiApi(codes: [_companionCode]);
    await pumpKoneksi(tester, api: api);
    await tester.pumpAndSettle();

    await tester.fling(
      find.byKey(const Key('koneksi-scroll')),
      const Offset(0, 300),
      1000,
    );
    await tester.pumpAndSettle();

    expect(api.codeReads, greaterThan(1));
  });

  testWidgets('copies a live code to the clipboard in one action', (
    tester,
  ) async {
    final clipboard = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    final api = _KoneksiApi(codes: [_companionCode]);
    await pumpKoneksi(tester, api: api);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('koneksi-copy-code-1')));
    await tester.pumpAndSettle();

    expect(clipboard, ['KDMN-PRTG']);
    expect(find.text('Kode Undangan disalin.'), findsOneWidget);
  });

  testWidgets('preview mode shows contract-valid codes without a backend', (
    tester,
  ) async {
    final api = _KoneksiApi();
    await pumpKoneksi(tester, api: api, token: null);
    await tester.pumpAndSettle();
    await reveal(tester, find.text(previewInviteCodeForProfessional));

    expect(find.text(previewInviteCodeForCompanion), findsOneWidget);
    expect(find.text(previewInviteCodeForProfessional), findsOneWidget);
    expect(api.gets, isEmpty);
    expect(api.posts, isEmpty);
  });

  testWidgets('issuing needs an explicit tap, then sends the chosen Role', (
    tester,
  ) async {
    final api = _KoneksiApi(codes: [_companionCode]);
    await pumpKoneksi(tester, api: api);
    await tester.pumpAndSettle();

    expect(api.posts, isEmpty);

    await tester.tap(find.byKey(const Key('koneksi-issue')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('koneksi-issue-dialog')), findsOneWidget);
    expect(
      find.byKey(const Key('koneksi-issue-target-companion')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('koneksi-issue-target-professional')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('koneksi-issue-target-professional')),
    );
    await tester.pumpAndSettle();

    expect(api.posts, ['/connections/invite-codes']);
    expect(api.bodies.single, {'target_role': 'professional'});
    expect(api.codeReads, greaterThan(1));
    await reveal(tester, find.text('KDNK-SHT2'));
    expect(find.text('KDNK-SHT2'), findsOneWidget);
  });

  testWidgets('the Professional option is disabled while the Mother has one', (
    tester,
  ) async {
    final api = _KoneksiApi(
      codes: [_companionCode],
      connections: [_professionalConnection],
    );
    await pumpKoneksi(tester, api: api);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('koneksi-issue')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('koneksi-issue-block-professional')),
      findsOneWidget,
    );
    expect(
      find.text('Anda sudah terhubung dengan tenaga kesehatan.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('koneksi-issue-target-professional')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('koneksi-issue-target-companion')),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('the Professional option comes back once the limit is gone', (
    tester,
  ) async {
    final api = _KoneksiApi(
      codes: [_companionCode],
      connections: [_professionalConnection],
    );
    await pumpKoneksi(tester, api: api);
    await tester.pumpAndSettle();

    api.connections = const [];

    await tester.fling(
      find.byKey(const Key('koneksi-scroll')),
      const Offset(0, 300),
      1000,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('koneksi-issue')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('koneksi-issue-block-professional')),
      findsNothing,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('koneksi-issue-target-professional')),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('a Companion with an active Mother cannot issue at all', (
    tester,
  ) async {
    final api = _KoneksiApi(connections: [_motherConnection]);
    await pumpKoneksi(tester, api: api, role: AppRole.companion);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('koneksi-issue-blocked')), findsOneWidget);
    expect(
      find.text('Anda sudah terhubung dengan seorang Ibu.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('koneksi-issue')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('a Companion without a Mother issues for a Mother directly', (
    tester,
  ) async {
    final api = _KoneksiApi();
    await pumpKoneksi(tester, api: api, role: AppRole.companion);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('koneksi-issue-blocked')), findsNothing);

    await tester.tap(find.byKey(const Key('koneksi-issue')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('koneksi-issue-dialog')), findsNothing);
    expect(api.posts, ['/connections/invite-codes']);
    expect(api.bodies.single, {'target_role': 'mother'});
    expect(find.text('Untuk Ibu'), findsOneWidget);
  });

  testWidgets('a Companion gets issuance back once the Mother is gone', (
    tester,
  ) async {
    final api = _KoneksiApi(connections: [_motherConnection]);
    await pumpKoneksi(tester, api: api, role: AppRole.companion);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('koneksi-issue-blocked')), findsOneWidget);

    api.connections = const [];
    await tester.fling(
      find.byKey(const Key('koneksi-scroll')),
      const Offset(0, 300),
      1000,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('koneksi-issue-blocked')), findsNothing);

    await tester.tap(find.byKey(const Key('koneksi-issue')));
    await tester.pumpAndSettle();
    expect(api.bodies.single, {'target_role': 'mother'});
  });

  testWidgets('a Professional is never blocked, even with an active Mother', (
    tester,
  ) async {
    final api = _KoneksiApi(connections: [_motherConnection]);
    await pumpKoneksi(tester, api: api, role: AppRole.professional);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('koneksi-issue-blocked')), findsNothing);

    await tester.tap(find.byKey(const Key('koneksi-issue')));
    await tester.pumpAndSettle();

    expect(api.posts, ['/connections/invite-codes']);
    expect(api.bodies.single, {'target_role': 'mother'});
  });

  testWidgets("a revoke refusal shows the backend's own wording", (
    tester,
  ) async {
    final api = _KoneksiApi(codes: [_companionCode])
      ..deleteError = const BackendApiException(
        statusCode: 404,
        message: 'Invite code is not valid',
      );
    await pumpKoneksi(tester, api: api);
    await tester.pumpAndSettle();

    await reveal(tester, find.byKey(const Key('koneksi-revoke-code-1')));
    await tester.tap(find.byKey(const Key('koneksi-revoke-code-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('koneksi-revoke-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('Invite code is not valid'), findsOneWidget);
    expect(find.byKey(const Key('koneksi-code-code-1')), findsOneWidget);
  });

  testWidgets('revoking removes the code after confirming', (tester) async {
    final api = _KoneksiApi(codes: [_companionCode, _professionalCode]);
    await pumpKoneksi(tester, api: api);
    await tester.pumpAndSettle();

    await reveal(tester, find.byKey(const Key('koneksi-revoke-code-1')));
    await tester.tap(find.byKey(const Key('koneksi-revoke-code-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('koneksi-revoke-dialog')), findsOneWidget);

    await tester.tap(find.byKey(const Key('koneksi-revoke-confirm')));
    await tester.pumpAndSettle();

    expect(api.deletes, ['/connections/invite-codes/code-1']);
    expect(find.byKey(const Key('koneksi-code-code-1')), findsNothing);
    expect(find.byKey(const Key('koneksi-code-code-2')), findsOneWidget);
    expect(api.codeReads, greaterThan(1));
  });

  testWidgets("an issue refusal shows the backend's own wording", (
    tester,
  ) async {
    final api = _KoneksiApi(codes: [_companionCode])
      ..postError = const BackendApiException(
        statusCode: 409,
        message: 'This mother already has a professional',
      );
    await pumpKoneksi(tester, api: api);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('koneksi-issue')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('koneksi-issue-target-professional')),
    );
    await tester.pumpAndSettle();

    expect(find.text('This mother already has a professional'), findsOneWidget);
  });

  testWidgets('preview issue and revoke make no backend calls', (tester) async {
    final api = _KoneksiApi();
    await pumpKoneksi(tester, api: api, token: null);
    await tester.pumpAndSettle();
    await reveal(
      tester,
      find.byKey(const Key('koneksi-revoke-preview-code-companion')),
    );

    expect(find.text(previewInviteCodeForCompanion), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('koneksi-revoke-preview-code-companion')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('koneksi-revoke-confirm')));
    await tester.pumpAndSettle();

    expect(find.text(previewInviteCodeForCompanion), findsNothing);
    await reveal(tester, find.text(previewInviteCodeForProfessional));
    expect(find.text(previewInviteCodeForProfessional), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('koneksi-issue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('koneksi-issue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('koneksi-issue-target-companion')));
    await tester.pumpAndSettle();

    await reveal(tester, find.text(previewInviteCodeForCompanion));
    expect(find.text(previewInviteCodeForCompanion), findsOneWidget);
    expect(api.gets, isEmpty);
    expect(api.posts, isEmpty);
    expect(api.deletes, isEmpty);
  });

  testWidgets('redeeming a code shows the new Connection without leaving', (
    tester,
  ) async {
    final api = _KoneksiApi(codes: [_companionCode]);
    await pumpKoneksi(tester, api: api);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('koneksi-redeem-field')),
        matching: find.byType(EditableText),
      ),
      '  kdmn-prtg  ',
    );
    await tester.tap(find.byKey(const Key('koneksi-redeem')));
    await tester.pumpAndSettle();

    expect(api.posts, ['/connections']);
    expect(api.bodies.single, {'code': 'KDMN-PRTG'});
    expect(
      find.byKey(const Key('koneksi-connection-conn-redeemed')),
      findsOneWidget,
    );
    expect(find.text('Ibu Seed'), findsOneWidget);
    expect(find.byKey(const Key('koneksi-title')), findsOneWidget);
    expect(api.connectionReads, greaterThan(1));
  });

  for (final refusal in const [
    (400, 'Invite code is malformed: expected XXXX-XXXX'),
    (403, 'This invite code is for a companion'),
    (404, 'Invite code is not valid'),
    (409, 'You are already connected to a mother'),
    (429, 'Too many requests. Please try again later.'),
    (503, 'The service is temporarily unavailable. Please try again later.'),
  ]) {
    testWidgets(
      'a redeem refusal ${refusal.$1} shows the backend wording untouched',
      (tester) async {
        final api = _KoneksiApi(codes: [_companionCode])
          ..redeemError = BackendApiException(
            statusCode: refusal.$1,
            message: refusal.$2,
          );
        await pumpKoneksi(tester, api: api);
        await tester.pumpAndSettle();

        await tester.enterText(
          find.descendant(
            of: find.byKey(const Key('koneksi-redeem-field')),
            matching: find.byType(EditableText),
          ),
          'KDMN-PRTG',
        );
        await tester.tap(find.byKey(const Key('koneksi-redeem')));
        await tester.pumpAndSettle();

        expect(find.text(refusal.$2), findsOneWidget);
        expect(find.byKey(const Key('koneksi-code-code-1')), findsOneWidget);
        expect(
          find.byKey(const Key('koneksi-connections-empty')),
          findsOneWidget,
        );
      },
    );
  }

  testWidgets('preview redeem connects locally without a backend', (
    tester,
  ) async {
    final api = _KoneksiApi();
    await pumpKoneksi(tester, api: api, token: null);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('koneksi-redeem-field')),
        matching: find.byType(EditableText),
      ),
      previewInviteCodeForMother,
    );
    await tester.tap(find.byKey(const Key('koneksi-redeem')));
    await tester.pumpAndSettle();

    expect(find.text('Kode berhasil ditukar.'), findsOneWidget);
    expect(
      find.byKey(const Key('koneksi-connection-preview-connection-mother')),
      findsOneWidget,
    );
    expect(api.posts, isEmpty);
  });

  testWidgets('preview codes name the Role the caller can actually pair', (
    tester,
  ) async {
    final api = _KoneksiApi();
    await pumpKoneksi(tester, api: api, token: null, role: AppRole.companion);
    await tester.pumpAndSettle();
    await reveal(tester, find.text(previewInviteCodeForMother));

    expect(find.text(previewInviteCodeForMother), findsOneWidget);
    expect(find.text(previewInviteCodeForCompanion), findsNothing);
    expect(find.text(previewInviteCodeForProfessional), findsNothing);
    expect(find.text('Untuk Ibu'), findsOneWidget);
  });

  testWidgets('preview respects the Companion guard after redeeming', (
    tester,
  ) async {
    final api = _KoneksiApi();
    await pumpKoneksi(tester, api: api, token: null, role: AppRole.companion);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('koneksi-redeem-field')),
        matching: find.byType(EditableText),
      ),
      previewInviteCodeForCompanion,
    );
    await tester.tap(find.byKey(const Key('koneksi-redeem')));
    await tester.pumpAndSettle();

    await reveal(tester, find.byKey(const Key('koneksi-issue-blocked')));
    expect(
      find.text('Anda sudah terhubung dengan seorang Ibu.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('koneksi-issue')))
          .onPressed,
      isNull,
    );
  });

  test('an expiry is shown as a local absolute time', () {
    expect(
      formatInviteExpiry(DateTime(2026, 11, 14, 22, 5).toIso8601String()),
      '14 Nov 2026, 22.05',
    );
    expect(
      formatInviteExpiry(DateTime(2026, 1, 3, 9, 0).toIso8601String()),
      '3 Jan 2026, 09.00',
    );
  });
}

class _KoneksiApi extends BackendApi {
  _KoneksiApi({
    List<Map<String, dynamic>> codes = const [],
    List<Map<String, dynamic>> connections = const [],
    this.error,
    this.gate,
  }) : codes = [...codes],
       connections = [...connections],
       super(baseUrl: 'https://backend.example.test');

  final List<Map<String, dynamic>> codes;
  List<Map<String, dynamic>> connections;
  Object? error;
  Object? postError;
  Object? redeemError;
  Object? deleteError;
  final Completer<void>? gate;
  final gets = <String>[];
  final posts = <String>[];
  final deletes = <String>[];
  final bodies = <Map<String, Object?>>[];
  final tokens = <String?>[];

  int get codeReads =>
      gets.where((path) => path == '/connections/invite-codes').length;

  int get connectionReads =>
      gets.where((path) => path == '/connections').length;

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? query,
    String? accessToken,
  }) async {
    gets.add(path);
    tokens.add(accessToken);
    final waiting = gate;
    if (waiting != null) await waiting.future;
    final failure = error;
    if (failure != null) throw failure;
    if (path == '/connections/invite-codes') {
      return {'invite_codes': codes};
    }
    return {'connections': connections};
  }

  @override
  Future<Map<String, dynamic>> postJson(
    String path, {
    required Map<String, Object?> body,
    String? accessToken,
  }) async {
    posts.add(path);
    bodies.add(body);
    tokens.add(accessToken);
    if (path == '/connections') {
      final failure = redeemError;
      if (failure != null) throw failure;
      final redeemed = {
        'id': 'conn-redeemed',
        'connected_at': '2026-11-14T11:00:00+00:00',
        'counterpart': {'name': 'Ibu Seed', 'role': 'mother'},
      };
      connections = [redeemed, ...connections];
      return redeemed;
    }
    final failure = postError;
    if (failure != null) throw failure;
    final target = body['target_role'];
    final issued = {
      'id': 'code-issued-$target',
      'code': target == 'professional' ? 'KDNK-SHT2' : 'KDMN-PRT2',
      'target_role': target,
      'expires_at': '2026-11-14T16:00:00+00:00',
    };
    codes.add(issued);
    return issued;
  }

  @override
  Future<Map<String, dynamic>> deleteJson(
    String path, {
    String? accessToken,
  }) async {
    deletes.add(path);
    tokens.add(accessToken);
    final failure = deleteError;
    if (failure != null) throw failure;
    final id = path.split('/').last;
    if (path.startsWith('/connections/invite-codes/')) {
      codes.removeWhere((code) => code['id'] == id);
    } else {
      connections.removeWhere((connection) => connection['id'] == id);
    }
    return {};
  }
}
