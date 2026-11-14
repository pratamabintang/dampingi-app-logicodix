import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/doctor/repositories/doctor_professional_note_repository.dart';
import 'package:mobile/features/companion/view/companion_extra_pages.dart';
import 'package:mobile/features/mother/repositories/mother_professional_note_notifications.dart';
import 'package:mobile/features/mother/repositories/mother_story_repository.dart';
import 'package:mobile/features/mother/view/mother_page.dart';
import 'package:mobile/features/mother/view/mother_notifications_page.dart';
import 'package:mobile/features/auth/controller/auth_controller.dart';
import 'package:mobile/services/backend_api.dart';

import 'support/authenticated_api.dart';
import 'mother_story_test_data.dart';

void main() {
  Future<void> pumpNotifications(
    WidgetTester tester,
    Widget page, {
    String? token,
    DoctorProfessionalNoteRepository? noteRepository,
  }) async {
    tester.view.physicalSize = const Size(390, 891);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backendTokenProvider.overrideWith((ref) => token),
          if (noteRepository != null)
            doctorProfessionalNoteRepositoryProvider.overrideWithValue(
              noteRepository,
            ),
        ],
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
      noteRepository: _TestProfessionalNoteRepository(const []),
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

  testWidgets('a Mother can open an expert note from notifications', (
    tester,
  ) async {
    const note = DoctorProfessionalNote(
      id: 'note-1',
      connectionId: 'connection-1',
      professionalId: 'professional-1',
      motherId: 'mother-1',
      content: 'Cobalah beristirahat dan minta bantuan orang terdekat.',
      createdAt: '2026-11-14T10:00:00Z',
      updatedAt: '2026-11-14T10:00:00Z',
    );
    await pumpNotifications(
      tester,
      const MotherNotificationsPage(),
      token: 'real-access-token',
      noteRepository: _TestProfessionalNoteRepository([note]),
    );

    final notification = find.byKey(
      const Key('mother-notification-professional-note-note-1'),
    );
    expect(notification, findsOneWidget);
    expect(find.text('Arahan dari tenaga kesehatan'), findsOneWidget);
    expect(
      find.text('Cobalah beristirahat dan minta bantuan orang terdekat.'),
      findsOneWidget,
    );

    await tester.tap(notification);
    await tester.pumpAndSettle();

    final providerContainer = ProviderScope.containerOf(
      tester.element(notification),
      listen: false,
    );
    expect(
      providerContainer
          .read(seenMotherProfessionalNoteKeysProvider)
          .contains(motherProfessionalNoteKey(note)),
      isTrue,
    );
    expect(
      find.byKey(const Key('mother-professional-note-dialog')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mother-professional-note-content')),
      findsOneWidget,
    );
    expect(find.textContaining('14 November 2026'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mother-professional-note-done')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('mother-professional-note-dialog')),
      findsNothing,
    );
  });

  testWidgets('mother home shows and clears the new-notification badge', (
    tester,
  ) async {
    const note = DoctorProfessionalNote(
      id: 'note-1',
      connectionId: 'connection-1',
      professionalId: 'professional-1',
      motherId: 'mother-1',
      content: 'Arahan baru.',
      createdAt: '2026-11-14T10:00:00Z',
      updatedAt: '2026-11-14T10:00:00Z',
    );
    final container = ProviderContainer(
      overrides: [
        backendTokenProvider.overrideWith((ref) => 'real-access-token'),
        motherProfessionalNotesProvider.overrideWith((ref) async => [note]),
        motherStoriesProvider.overrideWith((ref) async => motherStoryTestData),
        recentMoodsProvider.overrideWith((ref) async => const []),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MotherPage(showWeeklyEpds: false)),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('mother-notifications-new-indicator')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('mother-notifications')))
          .tooltip,
      'Notifikasi baru',
    );

    container
        .read(seenMotherProfessionalNoteKeysProvider.notifier)
        .markSeen(motherProfessionalNoteKey(note));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('mother-notifications-new-indicator')),
      findsNothing,
    );
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('mother-notifications')))
          .tooltip,
      'Notifikasi',
    );
  });

  testWidgets('a failed note request is not shown as an empty inbox', (
    tester,
  ) async {
    await pumpNotifications(
      tester,
      const MotherNotificationsPage(),
      token: 'real-access-token',
      noteRepository: _FailingProfessionalNoteRepository(),
    );

    expect(find.byKey(const Key('mother-notifications-error')), findsOneWidget);
    expect(find.byKey(const Key('mother-notifications-empty')), findsNothing);
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

class _TestProfessionalNoteRepository extends DoctorProfessionalNoteRepository {
  _TestProfessionalNoteRepository(this.notes) : super(_testAuthenticatedApi);

  static final _testAuthenticatedApi = authenticatedApiFor(
    BackendApi(baseUrl: 'https://backend.example.test'),
  );

  final List<DoctorProfessionalNote> notes;

  @override
  Future<List<DoctorProfessionalNote>> listVisibleNotes() async => notes;
}

class _FailingProfessionalNoteRepository
    extends _TestProfessionalNoteRepository {
  _FailingProfessionalNoteRepository() : super(const []);

  @override
  Future<List<DoctorProfessionalNote>> listVisibleNotes() {
    throw StateError('Test failure.');
  }
}
