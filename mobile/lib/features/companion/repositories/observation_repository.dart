import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/authenticated_api.dart';
import '../../../services/backend_api.dart';
import '../../connections/repositories/connection_repository.dart';
import '../../auth/controller/auth_controller.dart';
import '../../mother/repositories/mother_story_repository.dart';

final observationRepositoryProvider = Provider<ObservationRepository>(
  (ref) => ObservationRepository(ref.watch(authenticatedApiProvider)),
);

/// Satu pertanyaan observasi pendamping beserta pilihannya.
class ObservationQuestion {
  const ObservationQuestion({required this.prompt, required this.options});

  final String prompt;
  final List<String> options;
}

/// Sepuluh pertanyaan prototipe, hardcode di app: teksnya dan pilihan
/// gandanya menyesuaikan tiap soal. Backend menyimpan teks pertanyaan dan
/// pilihannya bersama jawaban, jadi riwayat tetap terbaca walau teks ini
/// diubah nanti.
const observationQuestions = <ObservationQuestion>[
  ObservationQuestion(
    prompt: 'Bagaimana anda menggambarkan perasaan Ibu hari ini?',
    options: [
      'Tampak sedih atau murung',
      'Tampak cemas atau gelisah',
      'Tampak biasa saja',
      'Tampak tenang dan senang',
    ],
  ),
  ObservationQuestion(
    prompt: 'Bagaimana nafsu makan Ibu hari ini?',
    options: [
      'Hampir tidak makan',
      'Makan lebih sedikit dari biasanya',
      'Makan seperti biasa',
      'Makan dengan lahap',
    ],
  ),
  ObservationQuestion(
    prompt: 'Bagaimana tidur Ibu semalam?',
    options: [
      'Sangat kurang, sering terbangun',
      'Kurang dari biasanya',
      'Cukup seperti biasa',
      'Nyenyak dan cukup',
    ],
  ),
  ObservationQuestion(
    prompt: 'Bagaimana Ibu merawat bayinya hari ini?',
    options: [
      'Tampak menghindar atau kewalahan',
      'Tampak ragu dan butuh dibantu',
      'Bisa merawat dengan bantuan',
      'Merawat dengan tenang dan percaya diri',
    ],
  ),
  ObservationQuestion(
    prompt: 'Seberapa sering Ibu tampak cemas atau khawatir?',
    options: [
      'Sepanjang hari',
      'Beberapa kali',
      'Sesekali',
      'Tidak tampak cemas',
    ],
  ),
  ObservationQuestion(
    prompt: 'Bagaimana Ibu merawat dirinya sendiri hari ini?',
    options: [
      'Tidak sempat sama sekali',
      'Sangat kurang',
      'Cukup terawat',
      'Terawat dengan baik',
    ],
  ),
  ObservationQuestion(
    prompt: 'Bagaimana Ibu bercerita tentang perasaannya?',
    options: [
      'Menutup diri, tidak mau bicara',
      'Sulit mengungkapkan',
      'Mau bicara bila ditanya',
      'Terbuka bercerita',
    ],
  ),
  ObservationQuestion(
    prompt: 'Seberapa lelah Ibu tampak hari ini?',
    options: [
      'Sangat lelah, sulit beraktivitas',
      'Lelah',
      'Sedikit lelah',
      'Segar',
    ],
  ),
  ObservationQuestion(
    prompt: 'Bagaimana Ibu menanggapi dukungan orang di sekitarnya?',
    options: [
      'Menolak atau menghindar',
      'Sulit menerima',
      'Menerima dengan ragu',
      'Terbuka menerima bantuan',
    ],
  ),
  ObservationQuestion(
    prompt: 'Secara keseluruhan, bagaimana kondisi Ibu hari ini?',
    options: [
      'Sangat mengkhawatirkan',
      'Perlu perhatian',
      'Cukup baik',
      'Baik dan stabil',
    ],
  ),
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
  /// pilihan), lalu kirim semua jawaban + tanggal untuk menyelesaikannya.
  ///
  /// Satu pilihan per pertanyaan di [observationQuestions], urut.
  Future<void> submit({
    required String motherId,
    required List<int> selectedOptions,
    required DateTime day,
  }) async {
    final questions = observationQuestions;
    if (selectedOptions.length != questions.length) {
      throw const FormatException('Observation draft has an invalid shape.');
    }

    final draft = await _api.postJson(
      '/observations',
      body: {
        'mother_id': motherId,
        'questions': [
          for (final question in questions)
            {
              'prompt': question.prompt,
              'options': [
                for (final label in question.options) {'label': label},
              ],
            },
        ],
      },
    );

    final id = draft['id'];
    final stored = draft['questions'];
    if (id is! String || stored is! List || stored.length != questions.length) {
      throw const FormatException('Observation draft has an invalid shape.');
    }

    final answers = <Map<String, String>>[];
    for (var index = 0; index < stored.length; index++) {
      final question = stored[index];
      final questionId = question is Map<String, dynamic>
          ? question['id']
          : null;
      final options = question is Map<String, dynamic>
          ? question['options']
          : null;
      final selected = selectedOptions[index];
      if (questionId is! String ||
          options is! List ||
          selected < 0 ||
          selected >= options.length) {
        throw const FormatException(
          'Observation question has an invalid shape.',
        );
      }
      final option = options[selected];
      final optionId = option is Map<String, dynamic> ? option['id'] : null;
      if (optionId is! String) {
        throw const FormatException('Observation option has an invalid shape.');
      }
      answers.add({'question_id': questionId, 'option_id': optionId});
    }

    await _api.patchJson(
      '/observations/$id',
      body: {'answers': answers, 'day': isoDate(day)},
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
