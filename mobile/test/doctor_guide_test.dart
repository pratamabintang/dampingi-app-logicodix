import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/connections/repositories/connection_repository.dart';
import 'package:mobile/features/doctor/repositories/doctor_professional_note_repository.dart';
import 'package:mobile/features/doctor/view/doctor_guide_page.dart';
import 'package:mobile/services/backend_api.dart';

import 'support/authenticated_api.dart';

import 'package:mobile/features/auth/controller/auth_controller.dart';

void main() {
  Future<void> pumpGuide(
    WidgetTester tester, {
    required _TestNoteRepository repository,
    required List<ConnectionPerson> connections,
  }) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backendTokenProvider.overrideWith((ref) => 'professional-token'),
          activeConnectionsProvider.overrideWith((ref) async => connections),
          doctorProfessionalNoteRepositoryProvider.overrideWithValue(
            repository,
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: DoctorGuidePage(bottomNavigation: const SizedBox(height: 60)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('loads notes for the selected active patient', (tester) async {
    final firstConnection = _connection('connection-1', 'Ibu A');
    final secondConnection = _connection('connection-2', 'Ibu B');
    final repository = _TestNoteRepository({
      'connection-1': [_note('note-1', 'connection-1', 'Arahan untuk Ibu A')],
      'connection-2': [_note('note-2', 'connection-2', 'Arahan untuk Ibu B')],
    });
    await pumpGuide(
      tester,
      repository: repository,
      connections: [firstConnection, secondConnection],
    );

    expect(find.text('Arahan untuk Ibu A'), findsOneWidget);
    expect(find.text('Arahan untuk Ibu B'), findsNothing);
    expect(repository.lastListConnectionId, 'connection-1');

    await tester.tap(find.byKey(const Key('doctor-guide-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ibu B').last);
    await tester.pumpAndSettle();

    expect(find.text('Arahan untuk Ibu B'), findsOneWidget);
    expect(find.text('Arahan untuk Ibu A'), findsNothing);
    expect(repository.lastListConnectionId, 'connection-2');
  });

  testWidgets('shows an empty state without requiring a selected patient', (
    tester,
  ) async {
    final repository = _TestNoteRepository({});
    await pumpGuide(tester, repository: repository, connections: const []);

    expect(find.byKey(const Key('doctor-guide-no-patients')), findsOneWidget);
    expect(find.byKey(const Key('doctor-guide-dropdown')), findsNothing);
    expect(repository.lastListConnectionId, isNull);
  });

  testWidgets('creates, edits, and deletes backend guidance', (tester) async {
    final connection = _connection('connection-1', 'Ibu A');
    final repository = _TestNoteRepository({
      'connection-1': [_note('note-1', 'connection-1', 'Arahan sebelumnya')],
    });
    await pumpGuide(tester, repository: repository, connections: [connection]);

    await tester.ensureVisible(find.byKey(const Key('doctor-guide-create')));
    await tester.tap(find.byKey(const Key('doctor-guide-create')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('doctor-guide-form-input')),
      'Arahan baru untuk pasien',
    );
    await tester.tap(find.byKey(const Key('doctor-guide-form-done')));
    await tester.pumpAndSettle();

    expect(repository.createdConnectionId, 'connection-1');
    expect(find.text('Arahan berhasil diberikan ke pasien!'), findsOneWidget);
    await tester.tap(find.byKey(const Key('doctor-guide-success-done')));
    await tester.pumpAndSettle();
    expect(find.text('Arahan baru untuk pasien'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('doctor-guide-edit')).first,
    );
    await tester.tap(find.byKey(const Key('doctor-guide-edit')).first);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('doctor-guide-form-input')))
          .controller
          ?.text,
      'Arahan baru untuk pasien',
    );
    await tester.enterText(
      find.byKey(const Key('doctor-guide-form-input')),
      'Arahan yang diperbarui',
    );
    await tester.tap(find.byKey(const Key('doctor-guide-form-done')));
    await tester.pumpAndSettle();

    expect(repository.updatedNoteId, 'note-2');
    expect(find.text('Arahan berhasil diperbarui!'), findsOneWidget);
    await tester.tap(find.byKey(const Key('doctor-guide-success-done')));
    await tester.pumpAndSettle();
    expect(find.text('Arahan yang diperbarui'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('doctor-guide-delete')).first,
    );
    await tester.tap(find.byKey(const Key('doctor-guide-delete')).first);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Hapus'),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.deletedNoteId, 'note-2');
    expect(find.text('Arahan berhasil dihapus!'), findsOneWidget);
    await tester.tap(find.byKey(const Key('doctor-guide-success-done')));
    await tester.pumpAndSettle();
    expect(find.text('Arahan sebelumnya'), findsOneWidget);
  });
}

ConnectionPerson _connection(String id, String name) =>
    ConnectionPerson(id: id, name: name, role: 'mother');

DoctorProfessionalNote _note(String id, String connectionId, String content) =>
    DoctorProfessionalNote(
      id: id,
      connectionId: connectionId,
      professionalId: 'professional-1',
      motherId: connectionId,
      content: content,
      createdAt: '2026-11-13T10:00:00Z',
      updatedAt: '2026-11-13T10:00:00Z',
    );

class _TestNoteRepository extends DoctorProfessionalNoteRepository {
  _TestNoteRepository(this._notes)
    : super(
        authenticatedApiFor(
          BackendApi(baseUrl: 'https://backend.example.test'),
        ),
      );

  final Map<String, List<DoctorProfessionalNote>> _notes;
  String? lastListConnectionId;
  String? createdConnectionId;
  String? updatedNoteId;
  String? deletedNoteId;

  @override
  Future<List<DoctorProfessionalNote>> listNotes({
    required String connectionId,
  }) async {
    lastListConnectionId = connectionId;
    return List.of(_notes[connectionId] ?? const []);
  }

  @override
  Future<DoctorProfessionalNote> createNote({
    required String connectionId,
    required String content,
  }) async {
    createdConnectionId = connectionId;
    final note = _note('note-2', connectionId, content);
    _notes.update(
      connectionId,
      (notes) => [note, ...notes],
      ifAbsent: () => [note],
    );
    return note;
  }

  @override
  Future<DoctorProfessionalNote> updateNote({
    required String noteId,
    required String content,
  }) async {
    updatedNoteId = noteId;
    for (final notes in _notes.values) {
      final index = notes.indexWhere((note) => note.id == noteId);
      if (index != -1) {
        final current = notes[index];
        final updated = _note(noteId, current.connectionId, content);
        notes[index] = updated;
        return updated;
      }
    }
    throw StateError('Note $noteId not found.');
  }

  @override
  Future<void> deleteNote({required String noteId}) async {
    deletedNoteId = noteId;
    for (final notes in _notes.values) {
      notes.removeWhere((note) => note.id == noteId);
    }
  }
}
