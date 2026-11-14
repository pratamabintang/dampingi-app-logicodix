import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/authenticated_api.dart';
import '../../auth/controller/auth_controller.dart';

final doctorProfessionalNoteRepositoryProvider =
    Provider<DoctorProfessionalNoteRepository>(
      (ref) =>
          DoctorProfessionalNoteRepository(ref.watch(authenticatedApiProvider)),
    );

final doctorProfessionalNotesProvider = FutureProvider.autoDispose
    .family<List<DoctorProfessionalNote>, String>((ref, connectionId) async {
      final token = ref.watch(backendTokenProvider);
      if (token == null) {
        throw StateError('Professional notes require a backend session.');
      }
      return ref
          .watch(doctorProfessionalNoteRepositoryProvider)
          .listNotes(connectionId: connectionId);
    });

class DoctorProfessionalNote {
  const DoctorProfessionalNote({
    required this.id,
    required this.connectionId,
    required this.professionalId,
    required this.motherId,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String connectionId;
  final String professionalId;
  final String motherId;
  final String content;
  final String createdAt;
  final String updatedAt;

  factory DoctorProfessionalNote.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final connectionId = json['connection_id'];
    final professionalId = json['professional_id'];
    final motherId = json['mother_id'];
    final content = json['content'];
    final createdAt = json['created_at'];
    final updatedAt = json['updated_at'];
    if (id is! String ||
        connectionId is! String ||
        professionalId is! String ||
        motherId is! String ||
        content is! String ||
        createdAt is! String ||
        updatedAt is! String) {
      throw const FormatException('Professional note has an invalid shape.');
    }
    return DoctorProfessionalNote(
      id: id,
      connectionId: connectionId,
      professionalId: professionalId,
      motherId: motherId,
      content: content,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class DoctorProfessionalNoteRepository {
  const DoctorProfessionalNoteRepository(this._api);

  final AuthenticatedApi _api;

  Future<List<DoctorProfessionalNote>> listNotes({
    required String connectionId,
  }) async {
    final notes = (await _api.getJson(
      '/professional-notes',
      query: {'connection_id': connectionId},
    ))['notes'];
    if (notes is! List) {
      throw const FormatException(
        'Professional note list has an invalid shape.',
      );
    }
    return [
      for (final item in notes)
        if (item is Map<String, dynamic>)
          DoctorProfessionalNote.fromJson(item)
        else
          throw const FormatException(
            'Professional note has an invalid shape.',
          ),
    ];
  }

  Future<DoctorProfessionalNote> createNote({
    required String connectionId,
    required String content,
  }) async {
    return DoctorProfessionalNote.fromJson(
      await _api.postJson(
        '/professional-notes',
        body: {'connection_id': connectionId, 'content': content},
      ),
    );
  }

  Future<DoctorProfessionalNote> updateNote({
    required String noteId,
    required String content,
  }) async {
    return DoctorProfessionalNote.fromJson(
      await _api.patchJson(
        '/professional-notes/$noteId',
        body: {'content': content},
      ),
    );
  }

  Future<void> deleteNote({required String noteId}) async {
    await _api.deleteJson('/professional-notes/$noteId');
  }
}
