import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/connections/repositories/connection_repository.dart';
import 'package:mobile/features/doctor/repositories/doctor_patient_summary_repository.dart';
import 'package:mobile/features/doctor/view/doctor_patient_summary_page.dart';
import 'package:mobile/features/mother/repositories/mother_story_repository.dart';
import 'package:mobile/services/backend_api.dart';

void main() {
  Future<void> pumpSummary(
    WidgetTester tester, {
    required _TestSummaryRepository repository,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backendTokenProvider.overrideWith((ref) => 'professional-token'),
          activeConnectionsProvider.overrideWith(
            (ref) async => const [
              ConnectionPerson(
                id: 'connection-1',
                name: 'Ibu dari database',
                role: 'mother',
              ),
            ],
          ),
          doctorPatientSummaryRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: DoctorPatientSummaryPage(
            bottomNavigation: const SizedBox(height: 60),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('hides every summary category without consent', (tester) async {
    final response = _summaryResponse(
      weeklySummary: false,
      epds: false,
      journal: false,
    );
    final repository = _TestSummaryRepository(response);
    await pumpSummary(tester, repository: repository);

    expect(find.text('Ibu dari database'), findsOneWidget);
    expect(repository.connectionId, 'connection-1');
    expect(DateTime.parse(repository.periodStart!).weekday, DateTime.monday);
    expect(
      find.text('Ibu belum membagikan ringkasan mingguan.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('doctor-patient-summary-epds-content')),
      findsOneWidget,
    );
    expect(
      find.textContaining('Ibu belum membagikan hasil EPDS.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('doctor-patient-summary-journal-private')),
      findsOneWidget,
    );
    expect(find.text('Catatan rahasia'), findsNothing);
    expect(find.text('Isi jurnal rahasia'), findsNothing);
    expect(find.textContaining('Skor EPDS: 9'), findsNothing);
  });

  testWidgets('shows only categories returned with consent', (tester) async {
    final response = _summaryResponse(
      weeklySummary: true,
      epds: true,
      journal: true,
    );
    final repository = _TestSummaryRepository(response);
    await pumpSummary(tester, repository: repository);

    expect(find.text('Ibu belum membagikan ringkasan mingguan.'), findsNothing);
    expect(find.textContaining('Skor EPDS: 9'), findsOneWidget);
    final scrollable = find
        .descendant(
          of: find.byKey(const Key('doctor-patient-summary-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('Catatan rahasia'),
      120,
      scrollable: scrollable,
    );
    expect(find.text('Catatan rahasia'), findsOneWidget);
    expect(find.text('Isi jurnal rahasia'), findsOneWidget);
  });
}

class _TestSummaryRepository extends DoctorPatientSummaryRepository {
  _TestSummaryRepository(Map<String, dynamic> response)
    : _summary = DoctorPatientSummary.fromJson(response),
      super(BackendApi(baseUrl: 'https://backend.example.test'));

  final DoctorPatientSummary _summary;
  String? connectionId;
  String? periodStart;

  @override
  Future<DoctorPatientSummary> getSummary({
    required String accessToken,
    required String connectionId,
    required String periodStart,
  }) async {
    this.connectionId = connectionId;
    this.periodStart = periodStart;
    return _summary;
  }
}

Map<String, dynamic> _summaryResponse({
  required bool weeklySummary,
  required bool epds,
  required bool journal,
}) => {
  'mother_name': 'Ibu dari database',
  'period_start': '2026-11-09',
  'period_end': '2026-11-15',
  'permissions': {
    'connection_id': 'connection-1',
    'weekly_summary': weeklySummary,
    'epds': epds,
    'journal': journal,
  },
  'moods': [
    {'date': '2026-11-10', 'mood': 5},
  ],
  'journals': [
    {
      'id': 'journal-1',
      'created_at': '2026-11-11',
      'title': 'Catatan rahasia',
      'content': 'Isi jurnal rahasia',
    },
  ],
  'epds': [
    {
      'date': '2026-11-12',
      'total_score': 9,
      'follow_up_required': false,
      'immediate_review_required': false,
      'disclaimer': 'Data demo, bukan diagnosis klinis.',
    },
  ],
};
