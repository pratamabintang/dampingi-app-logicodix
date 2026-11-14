import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/authenticated_api.dart';
import '../../../services/backend_api.dart';
import '../../auth/controller/auth_controller.dart';

final connectionRepositoryProvider = Provider<ConnectionRepository>(
  (ref) => ConnectionRepository(ref.watch(authenticatedApiProvider)),
);

/// Orang yang terhubung dengan pemanggil sekarang. null = mode preview.
final activeConnectionsProvider =
    FutureProvider.autoDispose<List<ConnectionPerson>?>((ref) async {
      if (ref.watch(backendTokenProvider) == null) return null;
      return ref.watch(connectionRepositoryProvider).listConnections();
    });

final professionalSharingPermissionsProvider = FutureProvider.autoDispose
    .family<ProfessionalSharingPermissions?, String>((ref, connectionId) async {
      if (ref.watch(backendTokenProvider) == null) return null;
      return ref
          .watch(connectionRepositoryProvider)
          .getProfessionalSharingPermissions(connectionId: connectionId);
    });

/// Kode undangan milik pemanggil yang masih berlaku. null = mode preview.
///
/// Membaca daftar tidak pernah membuat kode baru: kode dibuat hanya oleh
/// tindakan eksplisit pemiliknya.
final liveInviteCodesProvider = FutureProvider.autoDispose<List<InviteCode>?>((
  ref,
) async {
  if (ref.watch(backendTokenProvider) == null) return null;
  return ref.watch(connectionRepositoryProvider).listInviteCodes();
});

/// Label Peran dalam bahasa Indonesia. Peran datang sebagai string dari
/// kontrak; hanya tiga nilai yang dikenal.
String connectionRoleLabel(String role) => switch (role) {
  'companion' => 'Pendamping',
  'professional' => 'Tenaga kesehatan',
  'mother' => 'Ibu',
  _ => role,
};

/// Satu orang yang terhubung (pendamping, tenaga kesehatan, atau ibu).
class ConnectionPerson {
  const ConnectionPerson({
    required this.id,
    required this.name,
    required this.role,
    this.userId,
  });

  /// ID Koneksi (dipakai untuk memutus koneksi).
  final String id;
  final String name;
  final String role;

  /// ID akun orang tersebut. Pendamping butuh ID Ibu untuk membuat observasi.
  /// null kalau backend belum mengirimnya.
  final String? userId;

  String get roleLabel => connectionRoleLabel(role);

  factory ConnectionPerson.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final counterpart = json['counterpart'];
    if (id is! String ||
        counterpart is! Map<String, dynamic> ||
        counterpart['name'] is! String ||
        counterpart['role'] is! String) {
      throw const FormatException('Connection has an invalid shape.');
    }
    final userId = counterpart['id'];
    return ConnectionPerson(
      id: id,
      name: counterpart['name'] as String,
      role: counterpart['role'] as String,
      userId: userId is String ? userId : null,
    );
  }
}

/// Kode undangan sekali pakai. Ia menyebut Peran yang harus dipegang
/// penukarnya, bukan orang tertentu.
class InviteCode {
  const InviteCode({
    required this.id,
    required this.code,
    required this.targetRole,
    required this.expiresAt,
  });

  final String id;
  final String code;
  final String targetRole;
  final String expiresAt;

  String get targetRoleLabel => connectionRoleLabel(targetRole);

  factory InviteCode.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final code = json['code'];
    final targetRole = json['target_role'];
    final expiresAt = json['expires_at'];
    if (id is! String ||
        code is! String ||
        targetRole is! String ||
        expiresAt is! String) {
      throw const FormatException('Invite code has an invalid shape.');
    }
    return InviteCode(
      id: id,
      code: code,
      targetRole: targetRole,
      expiresAt: expiresAt,
    );
  }
}

class ProfessionalSharingPermissions {
  const ProfessionalSharingPermissions({
    required this.connectionId,
    required this.weeklySummary,
    required this.epds,
    required this.journal,
  });

  final String connectionId;
  final bool weeklySummary;
  final bool epds;
  final bool journal;

  factory ProfessionalSharingPermissions.fromJson(Map<String, dynamic> json) {
    final connectionId = json['connection_id'];
    final weeklySummary = json['weekly_summary'];
    final epds = json['epds'];
    final journal = json['journal'];
    if (connectionId is! String ||
        weeklySummary is! bool ||
        epds is! bool ||
        journal is! bool) {
      throw const FormatException('Sharing permissions have an invalid shape.');
    }
    return ProfessionalSharingPermissions(
      connectionId: connectionId,
      weeklySummary: weeklySummary,
      epds: epds,
      journal: journal,
    );
  }
}

class ConnectionRepository {
  ConnectionRepository(this._api);

  final AuthenticatedApi _api;

  Future<ProfessionalSharingPermissions> getProfessionalSharingPermissions({
    required String connectionId,
  }) async {
    return ProfessionalSharingPermissions.fromJson(
      await _api.getJson('/connections/$connectionId/sharing-permissions'),
    );
  }

  Future<ProfessionalSharingPermissions> updateProfessionalSharingPermissions({
    required String connectionId,
    required Map<String, Object?> changes,
  }) async {
    return ProfessionalSharingPermissions.fromJson(
      await _api.patchJson(
        '/connections/$connectionId/sharing-permissions',
        body: changes,
      ),
    );
  }

  Future<List<ConnectionPerson>> listConnections() async {
    final items = (await _api.getJson('/connections'))['connections'];
    if (items is! List) {
      throw const FormatException('Connection list has an invalid shape.');
    }
    return [
      for (final item in items)
        ConnectionPerson.fromJson(item as Map<String, dynamic>),
    ];
  }

  /// Kode undangan yang masih berlaku milik pemanggil. Hanya membaca.
  Future<List<InviteCode>> listInviteCodes() async {
    final items = (await _api.getJson(
      '/connections/invite-codes',
    ))['invite_codes'];
    if (items is! List) {
      throw const FormatException('Invite code list has an invalid shape.');
    }
    return [
      for (final item in items)
        InviteCode.fromJson(item as Map<String, dynamic>),
    ];
  }

  /// Menerbitkan kode undangan baru untuk Peran target yang dipilih.
  /// Hanya tindakan eksplisit boleh memanggil ini.
  Future<InviteCode> issueInviteCode({required String targetRole}) async {
    return InviteCode.fromJson(
      await _api.postJson(
        '/connections/invite-codes',
        body: {'target_role': targetRole},
      ),
    );
  }

  /// Mencabut kode undangan milik pemanggil yang masih berlaku.
  Future<void> revokeInviteCode({required String id}) async {
    await _api.deleteJson('/connections/invite-codes/$id');
  }

  /// Mengakhiri Koneksi yang masih aktif. Kedua pihak berhak melakukannya.
  Future<void> endConnection({required String id}) async {
    await _api.deleteJson('/connections/$id');
  }

  /// Menukar kode dari pendamping/tenaga kesehatan/ibu; langsung terhubung.
  ///
  /// Hanya merapikan spasi dan huruf besar. Panjang dan alfabet kode tetap
  /// dinilai backend, supaya pesannya sesuai kontrak.
  Future<ConnectionPerson> redeem({required String code}) async {
    return ConnectionPerson.fromJson(
      await _api.postJson(
        '/connections',
        body: {'code': code.trim().toUpperCase()},
      ),
    );
  }
}

/// Pesan backend dipakai apa adanya; hanya kegagalan yang tidak punya pesan
/// yang diganti dengan kalimat umum.
String connectionFailureMessage(Object error) => switch (error) {
  BackendApiException(statusCode: 401) =>
    'Sesi login telah berakhir. Silakan masuk kembali.',
  BackendApiException(:final message) => message,
  ApiNetworkException(:final message) => message,
  ApiConfigurationException(:final message) => message,
  ApiResponseFormatException(:final message) => message,
  _ => 'Terjadi kesalahan. Coba lagi.',
};
