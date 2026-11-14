import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/authenticated_api.dart';
import '../../../services/backend_api.dart';
import '../../connections/repositories/connection_repository.dart';
import '../../auth/controller/auth_controller.dart';
import '../../mother/repositories/mother_story_repository.dart';

final observationRepositoryProvider = Provider<ObservationRepository>(
  (ref) => ObservationRepository(ref.watch(authenticatedApiProvider)),
);

/// Pertanyaan observasi harian pendamping. Backend menyimpan teks pertanyaan
/// dan pilihannya bersama jawaban, jadi riwayat tetap terbaca walau teks ini
/// diubah nanti.
const observationPrompt = 'Bagaimana anda menggambarkan perasaan Ibu hari ini?';
const observationOptions = [
  'Tampak sedih atau murung',
  'Tampak lelah atau cemas',
  'Tampak biasa saja',
  'Tampak senang dan tenang',
];

/// Ibu yang sedang didampingi. null = belum terhubung atau mode preview.
final companionMotherProvider = FutureProvider.autoDispose<ConnectionPerson?>((
  ref,
) async {
  final connections = await ref.watch(activeConnectionsProvider.future);
  if (connections == null) return null;
  for (final person in connections) {
    if (person.role == 'mother') return person;
  }
  return null;
});

/// Apakah observasi hari ini sudah diisi. null = mode preview.
final todayObservationDoneProvider = FutureProvider.autoDispose<bool?>((
  ref,
) async {
  final token = ref.watch(backendTokenProvider);
  if (token == null) return null;
  final mother = await ref.watch(companionMotherProvider.future);
  if (mother == null) return false;
  return ref
      .watch(observationRepositoryProvider)
      .hasCompletedFor(connectionId: mother.id, day: DateTime.now());
});

class ObservationRepository {
  ObservationRepository(this._api);

  final AuthenticatedApi _api;

  /// Ada observasi selesai untuk hari ini di koneksi ini?
  Future<bool> hasCompletedFor({
    required String connectionId,
    required DateTime day,
  }) async {
    final body = await _api.getJson(
      '/observations',
      query: {
        'connection_id': connectionId,
        'day': isoDate(day),
        'status': 'completed',
      },
    );
    final total = body['total'];
    if (total is! int) {
      throw const FormatException('Observation list has an invalid shape.');
    }
    return total > 0;
  }

  /// Backend memakai dua langkah: buat draf (server memberi ID pertanyaan dan
  /// pilihan), lalu kirim jawaban + tanggal untuk menyelesaikannya.
  Future<void> submit({
    required String motherId,
    required int selectedOption,
    required DateTime day,
  }) async {
    final draft = await _api.postJson(
      '/observations',
      body: {
        'mother_id': motherId,
        'questions': [
          {
            'prompt': observationPrompt,
            'options': [
              for (final label in observationOptions) {'label': label},
            ],
          },
        ],
      },
    );

    final id = draft['id'];
    final questions = draft['questions'];
    if (id is! String || questions is! List || questions.isEmpty) {
      throw const FormatException('Observation draft has an invalid shape.');
    }
    final question = questions.first;
    final questionId = question is Map<String, dynamic> ? question['id'] : null;
    final options = question is Map<String, dynamic>
        ? question['options']
        : null;
    if (questionId is! String ||
        options is! List ||
        selectedOption < 0 ||
        selectedOption >= options.length) {
      throw const FormatException('Observation question has an invalid shape.');
    }
    final option = options[selectedOption];
    final optionId = option is Map<String, dynamic> ? option['id'] : null;
    if (optionId is! String) {
      throw const FormatException('Observation option has an invalid shape.');
    }

    await _api.patchJson(
      '/observations/$id',
      body: {
        'answers': [
          {'question_id': questionId, 'option_id': optionId},
        ],
        'day': isoDate(day),
      },
    );
  }
}

String observationFailureMessage(Object error) => switch (error) {
  BackendApiException(statusCode: 409) =>
    'Observasi untuk hari ini sudah diisi.',
  BackendApiException(statusCode: 404) =>
    'Anda belum terhubung dengan Ibu. Masukkan kode undangan dulu.',
  FormatException() => 'Respons server tidak sesuai. Coba lagi.',
  _ => connectionFailureMessage(error),
};
