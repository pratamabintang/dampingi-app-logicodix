import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/doctor/repositories/doctor_professional_note_repository.dart';
import 'package:mobile/services/backend_api.dart';

void main() {
  test(
    'uses professional note endpoints and connection-scoped list query',
    () async {
      final api = _NoteApi();
      final repository = DoctorProfessionalNoteRepository(api);

      final notes = await repository.listNotes(
        accessToken: 'token',
        connectionId: 'connection-1',
      );
      final created = await repository.createNote(
        accessToken: 'token',
        connectionId: 'connection-1',
        content: 'New guidance',
      );
      final updated = await repository.updateNote(
        accessToken: 'token',
        noteId: 'note-1',
        content: 'Updated guidance',
      );
      await repository.deleteNote(accessToken: 'token', noteId: 'note-1');

      expect(notes.single.id, 'note-1');
      expect(created.content, 'New guidance');
      expect(updated.content, 'Updated guidance');
      expect(api.requests.map((request) => '${request.$1} ${request.$2}'), [
        'GET /professional-notes',
        'POST /professional-notes',
        'PATCH /professional-notes/note-1',
        'DELETE /professional-notes/note-1',
      ]);
      expect(api.requests[0].$3, {'connection_id': 'connection-1'});
      expect(api.requests[1].$4, {
        'connection_id': 'connection-1',
        'content': 'New guidance',
      });
      expect(api.requests[2].$4, {'content': 'Updated guidance'});
    },
  );
}

class _NoteApi extends BackendApi {
  _NoteApi() : super(baseUrl: 'https://backend.example.test');

  final requests =
      <(String, String, Map<String, String>?, Map<String, Object?>?)>[];

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? query,
    String? accessToken,
  }) async {
    requests.add(('GET', path, query, null));
    return {
      'notes': [_noteJson('Original guidance')],
      'count': 1,
      'offset': 0,
      'limit': 1,
      'total': 1,
    };
  }

  @override
  Future<Map<String, dynamic>> postJson(
    String path, {
    required Map<String, Object?> body,
    String? accessToken,
  }) async {
    requests.add(('POST', path, null, body));
    return _noteJson(body['content'] as String);
  }

  @override
  Future<Map<String, dynamic>> patchJson(
    String path, {
    required Map<String, Object?> body,
    String? accessToken,
  }) async {
    requests.add(('PATCH', path, null, body));
    return _noteJson(body['content'] as String);
  }

  @override
  Future<Map<String, dynamic>> deleteJson(
    String path, {
    String? accessToken,
  }) async {
    requests.add(('DELETE', path, null, null));
    return {};
  }
}

Map<String, dynamic> _noteJson(String content) => {
  'id': 'note-1',
  'connection_id': 'connection-1',
  'professional_id': 'professional-1',
  'mother_id': 'mother-1',
  'content': content,
  'created_at': '2026-11-14T10:00:00Z',
  'updated_at': '2026-11-14T10:00:00Z',
};
