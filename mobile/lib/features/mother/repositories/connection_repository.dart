import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/backend_api.dart';
import 'mother_story_repository.dart';

final connectionRepositoryProvider = Provider<ConnectionRepository>(
  (ref) => ConnectionRepository(ref.watch(backendApiProvider)),
);

/// Orang yang terhubung dengan ibu. null = mode preview.
final motherConnectionsProvider =
    FutureProvider.autoDispose<List<ConnectionPerson>?>((ref) async {
      final token = ref.watch(backendTokenProvider);
      if (token == null) return null;
      return ref
          .watch(connectionRepositoryProvider)
          .listConnections(accessToken: token);
    });

/// Kode pendampingan ibu untuk pendamping (berlaku 1 jam). null = mode preview.
final motherCompanionCodeProvider = FutureProvider.autoDispose<InviteCode?>((
  ref,
) async {
  final token = ref.watch(backendTokenProvider);
  if (token == null) return null;
  return ref
      .watch(connectionRepositoryProvider)
      .companionCode(accessToken: token);
});

/// Satu orang yang terhubung (pendamping, tenaga kesehatan, atau ibu).
class ConnectionPerson {
  const ConnectionPerson({
    required this.id,
    required this.name,
    required this.role,
  });

  final String id;
  final String name;
  final String role;

  String get roleLabel => switch (role) {
    'companion' => 'Pendamping',
    'professional' => 'Tenaga kesehatan',
    'mother' => 'Ibu',
    _ => role,
  };

  factory ConnectionPerson.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final counterpart = json['counterpart'];
    if (id is! String ||
        counterpart is! Map<String, dynamic> ||
        counterpart['name'] is! String ||
        counterpart['role'] is! String) {
      throw const FormatException('Connection has an invalid shape.');
    }
    return ConnectionPerson(
      id: id,
      name: counterpart['name'] as String,
      role: counterpart['role'] as String,
    );
  }
}

/// Kode undangan sekali pakai.
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

class ConnectionRepository {
  ConnectionRepository(this._api);

  final BackendApi _api;

  Future<List<ConnectionPerson>> listConnections({
    required String accessToken,
  }) async {
    final items = (await _api.getJson(
      '/connections',
      accessToken: accessToken,
    ))['connections'];
    if (items is! List) {
      throw const FormatException('Connection list has an invalid shape.');
    }
    return [
      for (final item in items)
        ConnectionPerson.fromJson(item as Map<String, dynamic>),
    ];
  }

  /// Pakai kode pendamping yang masih berlaku; kalau tidak ada, buat yang baru.
  Future<InviteCode> companionCode({required String accessToken}) async {
    final items = (await _api.getJson(
      '/connections/invite-codes',
      accessToken: accessToken,
    ))['invite_codes'];
    if (items is! List) {
      throw const FormatException('Invite code list has an invalid shape.');
    }
    for (final item in items) {
      final code = InviteCode.fromJson(item as Map<String, dynamic>);
      if (code.targetRole == 'companion') return code;
    }
    return InviteCode.fromJson(
      await _api.postJson(
        '/connections/invite-codes',
        body: {'target_role': 'companion'},
        accessToken: accessToken,
      ),
    );
  }

  /// Menukar kode dari pendamping/tenaga kesehatan; langsung terhubung.
  Future<ConnectionPerson> redeem({
    required String accessToken,
    required String code,
  }) async {
    return ConnectionPerson.fromJson(
      await _api.postJson(
        '/connections',
        body: {'code': code},
        accessToken: accessToken,
      ),
    );
  }
}
