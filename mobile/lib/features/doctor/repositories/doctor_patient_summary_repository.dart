import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/authenticated_api.dart';
import '../../auth/controller/auth_controller.dart';
import '../../connections/repositories/connection_repository.dart';
import '../../mother/repositories/daily_entry_repository.dart';

final doctorPatientSummaryRepositoryProvider =
    Provider<DoctorPatientSummaryRepository>(
      (ref) =>
          DoctorPatientSummaryRepository(ref.watch(authenticatedApiProvider)),
    );

final doctorPatientSummaryProvider = FutureProvider.autoDispose
    .family<DoctorPatientSummary, ({String connectionId, String periodStart})>((
      ref,
      request,
    ) async {
      final token = ref.watch(backendTokenProvider);
      if (token == null) {
        throw StateError('Patient summary requires a backend session.');
      }
      return ref
          .watch(doctorPatientSummaryRepositoryProvider)
          .getSummary(
            connectionId: request.connectionId,
            periodStart: request.periodStart,
          );
    });

class DoctorPatientSummary {
  const DoctorPatientSummary({
    required this.motherName,
    required this.periodStart,
    required this.periodEnd,
    required this.permissions,
    required this.moods,
    required this.journals,
    required this.epds,
  });

  final String motherName;
  final String periodStart;
  final String periodEnd;
  final ProfessionalSharingPermissions permissions;
  final List<PatientMoodEntry> moods;
  final List<JournalEntry> journals;
  final List<PatientEPDSAssessment> epds;

  factory DoctorPatientSummary.fromJson(Map<String, dynamic> json) {
    final motherName = json['mother_name'];
    final periodStart = json['period_start'];
    final periodEnd = json['period_end'];
    final permissions = json['permissions'];
    final moods = json['moods'];
    final journals = json['journals'];
    final epds = json['epds'];
    if (motherName is! String ||
        periodStart is! String ||
        periodEnd is! String ||
        permissions is! Map<String, dynamic> ||
        moods is! List ||
        journals is! List ||
        epds is! List) {
      throw const FormatException('Patient summary has an invalid shape.');
    }
    return DoctorPatientSummary(
      motherName: motherName,
      periodStart: periodStart,
      periodEnd: periodEnd,
      permissions: ProfessionalSharingPermissions.fromJson(permissions),
      moods: [
        for (final item in moods)
          if (item is Map<String, dynamic>)
            PatientMoodEntry.fromJson(item)
          else
            throw const FormatException('Patient mood has an invalid shape.'),
      ],
      journals: [
        for (final item in journals)
          if (item is Map<String, dynamic>)
            JournalEntry.fromJson(item)
          else
            throw const FormatException(
              'Patient journal has an invalid shape.',
            ),
      ],
      epds: [
        for (final item in epds)
          if (item is Map<String, dynamic>)
            PatientEPDSAssessment.fromJson(item)
          else
            throw const FormatException('Patient EPDS has an invalid shape.'),
      ],
    );
  }
}

class PatientMoodEntry {
  const PatientMoodEntry({required this.date, required this.mood});

  final String date;
  final int mood;

  factory PatientMoodEntry.fromJson(Map<String, dynamic> json) {
    final date = json['date'];
    final mood = json['mood'];
    if (date is! String || mood is! int || mood < 1 || mood > 5) {
      throw const FormatException('Patient mood has an invalid shape.');
    }
    return PatientMoodEntry(date: date, mood: mood);
  }
}

class PatientEPDSAssessment {
  const PatientEPDSAssessment({
    required this.date,
    required this.totalScore,
    required this.followUpRequired,
    required this.immediateReviewRequired,
    required this.disclaimer,
  });

  final String date;
  final int totalScore;
  final bool followUpRequired;
  final bool immediateReviewRequired;
  final String disclaimer;

  factory PatientEPDSAssessment.fromJson(Map<String, dynamic> json) {
    final date = json['date'];
    final totalScore = json['total_score'];
    final followUpRequired = json['follow_up_required'];
    final immediateReviewRequired = json['immediate_review_required'];
    final disclaimer = json['disclaimer'];
    if (date is! String ||
        totalScore is! int ||
        totalScore < 0 ||
        totalScore > 30 ||
        followUpRequired is! bool ||
        immediateReviewRequired is! bool ||
        disclaimer is! String) {
      throw const FormatException('Patient EPDS has an invalid shape.');
    }
    return PatientEPDSAssessment(
      date: date,
      totalScore: totalScore,
      followUpRequired: followUpRequired,
      immediateReviewRequired: immediateReviewRequired,
      disclaimer: disclaimer,
    );
  }
}

class DoctorPatientSummaryRepository {
  const DoctorPatientSummaryRepository(this._api);

  final AuthenticatedApi _api;

  Future<DoctorPatientSummary> getSummary({
    required String connectionId,
    required String periodStart,
  }) async {
    final json = await _api.getJson(
      '/connections/$connectionId/patient-summary',
      query: {'period_start': periodStart},
    );
    return DoctorPatientSummary.fromJson(json);
  }
}
