import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/companion/repositories/companion_history_repository.dart';
import 'package:mobile/features/mother/repositories/mother_alert_repository.dart';
import 'package:mobile/services/backend_api.dart';

import 'support/authenticated_api.dart';

Map<String, dynamic> observation(String day) => {
  'id': 'obs-$day',
  'mother_id': 'mother-A',
  'day': day,
  'status': 'completed',
  'questions': [
    {
      'id': 'question-server-7',
      'prompt': 'Pertanyaan yang disimpan server',
      'options': [
        {'id': 'choice-B', 'label': 'Label B'},
        {'id': 'choice-A', 'label': 'Label A'},
      ],
    },
  ],
  'answers': [
    {'question_id': 'question-server-7', 'option_id': 'choice-A'},
  ],
};

void main() {
  test('observasi memakai ID jawaban tersimpan, bukan indeks pilihan UI', () {
    final record = CompanionObservation.fromJson(observation('2026-11-14'));
    expect(record.answers.single.answer, 'Label A');
    expect(record.answers.single.question, 'Pertanyaan yang disimpan server');
  });

  test('jawaban yang tidak ditemukan tidak diubah jadi jawaban positif', () {
    final json = observation('2026-11-14');
    json['answers'] = [
      {'question_id': 'question-server-7', 'option_id': 'hilang'},
    ];
    expect(() => CompanionObservation.fromJson(json), throwsFormatException);
  });

  test('minggu Senin-Minggu, seluruh halaman, token akun sendiri', () async {
    final api = _Api();
    addTearDown(api.close);
    final repo = CompanionHistoryRepository(
      authenticatedApiFor(api, token: 'token-C'),
    );
    final week = await repo.week('2026-11-09');
    expect(week.observations.map((e) => e.day), ['2026-11-15', '2026-11-09']);
    expect(week.journals.single.title, 'Catatan milik pendamping');
    final journalQuery = api.calls.first.$2;
    expect(journalQuery?['start_date'], '2026-11-09');
    expect(journalQuery?['end_date'], '2026-11-15');
    expect(api.calls.where((c) => c.$1 == '/observations').length, 2);
    expect(api.tokens.every((t) => t == 'token-C'), isTrue);
    expect(
      api.calls.every((c) => !(c.$2 ?? {}).containsKey('mother_id')),
      isTrue,
    );
  });

  test(
    'edit menarget ID catatan terpilih dan tidak mengubah tanggal',
    () async {
      final api = _Api();
      addTearDown(api.close);
      await CompanionHistoryRepository(authenticatedApiFor(api)).save(
        id: 'journal-lama',
        day: '2026-11-09',
        title: ' Ubah ',
        content: ' Isi ',
      );
      expect(api.writes.single.$1, 'PATCH');
      expect(api.writes.single.$2, '/journals/journal-lama');
      expect(api.writes.single.$3, {
        'title': 'Ubah',
        'content': 'Isi',
      });
    },
  );

  test(
    'catatan baru memakai hari yang dipilih dan identitas dari token',
    () async {
      final api = _Api();
      addTearDown(api.close);
      await CompanionHistoryRepository(authenticatedApiFor(api))
          .save(day: '2026-11-14', title: 'Judul', content: 'Isi');
      expect(api.writes.single.$1, 'POST');
      expect(api.writes.single.$2, '/journals');
      expect(api.writes.single.$3, {
        'title': 'Judul',
        'content': 'Isi',
        'created_at': '2026-11-14',
      });
    },
  );

  test('409 tidak diam-diam menimpa catatan lain', () async {
    final api = _Api(conflict: true);
    addTearDown(api.close);
    await expectLater(
      CompanionHistoryRepository(authenticatedApiFor(api))
          .save(day: '2026-11-14', title: 'Judul', content: 'Isi'),
      throwsA(isA<BackendApiException>()),
    );
    expect(api.writes.length, 1);
    expect(api.calls, isEmpty);
  });

  test(
    'alerts membaca items, memakai ID ibu dan memuat halaman berikutnya',
    () async {
      final api = _Api();
      addTearDown(api.close);
      final result = await MotherAlertRepository(authenticatedApiFor(api))
          .list(motherId: 'mother-A');
      expect(result.map((e) => e.id), ['alert-2', 'alert-1']);
      expect(
        api.calls.map((c) => c.$1),
        everyElement('/v1/mothers/mother-A/alerts'),
      );
      expect(api.calls.last.$2?['offset'], '1');
    },
  );

  test('API gagal tidak dipresentasikan sebagai daftar kosong', () async {
    final api = _Api(fail: true);
    addTearDown(api.close);
    await expectLater(
      MotherAlertRepository(authenticatedApiFor(api))
          .list(motherId: 'mother-A'),
      throwsA(isA<ApiNetworkException>()),
    );
  });
}

class _Api extends BackendApi {
  _Api({this.conflict = false, this.fail = false})
    : super(baseUrl: 'https://fake.test');
  final bool conflict;
  final bool fail;
  final calls = <(String, Map<String, String>?)>[];
  final tokens = <String?>[];
  final writes = <(String, String, Map<String, Object?>)>[];

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? query,
    String? accessToken,
  }) async {
    calls.add((path, query));
    tokens.add(accessToken);
    if (fail) throw const ApiNetworkException('Jaringan mati');
    if (path == '/journals')
      return {
        'journals': [
          {
            'id': 'journal-1',
            'created_at': '2026-11-14',
            'title': 'Catatan milik pendamping',
            'content': 'Pengamatan saya',
          },
        ],
        'total': 1,
      };
    final first = query?['offset'] == '0';
    if (path == '/observations')
      return {
        'observations': first
            ? [observation('2026-11-08'), observation('2026-11-09')]
            : [observation('2026-11-15'), observation('2026-11-16')],
        'total': 4,
      };
    return {
      'items': [
        {
          'id': first ? 'alert-1' : 'alert-2',
          'created_at': first ? '2026-11-13T01:00:00Z' : '2026-11-14T01:00:00Z',
          'evaluation_mode': 'demo_only',
        },
      ],
      'total': 2,
    };
  }

  @override
  Future<Map<String, dynamic>> postJson(
    String path, {
    required Map<String, Object?> body,
    String? accessToken,
  }) async {
    writes.add(('POST', path, body));
    if (conflict)
      throw const BackendApiException(statusCode: 409, message: 'Sudah ada');
    return {};
  }

  @override
  Future<Map<String, dynamic>> patchJson(
    String path, {
    required Map<String, Object?> body,
    String? accessToken,
  }) async {
    writes.add(('PATCH', path, body));
    return {};
  }
}
