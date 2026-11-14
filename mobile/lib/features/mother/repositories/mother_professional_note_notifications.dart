import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/controller/auth_controller.dart';
import '../../doctor/repositories/doctor_professional_note_repository.dart';

final motherProfessionalNotesProvider =
    FutureProvider.autoDispose<List<DoctorProfessionalNote>>((ref) async {
      if (ref.watch(backendTokenProvider) == null) {
        throw StateError('Professional notes require a backend session.');
      }
      return ref
          .watch(doctorProfessionalNoteRepositoryProvider)
          .listVisibleNotes();
    });

final seenMotherProfessionalNoteKeysProvider =
    NotifierProvider<SeenMotherProfessionalNoteKeys, Set<String>>(
      SeenMotherProfessionalNoteKeys.new,
    );

class SeenMotherProfessionalNoteKeys extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void markSeen(String key) {
    state = {...state, key};
  }
}

String motherProfessionalNoteKey(DoctorProfessionalNote note) =>
    '${note.id}:${note.updatedAt}';
