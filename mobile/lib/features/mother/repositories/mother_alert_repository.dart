import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/authenticated_api.dart';
import '../../auth/controller/auth_controller.dart';

final motherAlertRepositoryProvider = Provider<MotherAlertRepository>(
  (ref) => MotherAlertRepository(ref.watch(authenticatedApiProvider)),
);

final motherAlertsProvider = FutureProvider.autoDispose<List<MotherAlert>>((
  ref,
) {
  final token = ref.watch(backendTokenProvider);
  final id = ref.watch(authControllerProvider).asData?.value.session?.user.id;
  if (token == null) return Future.value(const <MotherAlert>[]);
  if (id == null) throw const FormatException('Identitas ibu belum tersedia.');
  return ref.watch(motherAlertRepositoryProvider).list(motherId: id);
});

class MotherAlert {
  const MotherAlert({required this.id, required this.createdAt});

  final String id;
  final DateTime createdAt;

  factory MotherAlert.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final date = json['created_at'];
    final parsed = date is String ? DateTime.tryParse(date) : null;
    if (id is! String ||
        parsed == null ||
        json['evaluation_mode'] != 'demo_only') {
      throw const FormatException('Format notifikasi tidak sesuai.');
    }
    return MotherAlert(id: id, createdAt: parsed);
  }
}

class MotherAlertRepository {
  MotherAlertRepository(this._api);
  final AuthenticatedApi _api;

  Future<List<MotherAlert>> list({required String motherId}) async {
    final result = <MotherAlert>[];
    var offset = 0;
    while (true) {
      final json = await _api.getJson(
        '/v1/mothers/$motherId/alerts',
        query: {'offset': '$offset', 'limit': '100'},
      );
      final items = json['items'];
      final total = json['total'];
      if (items is! List || total is! int || total < 0) {
        throw const FormatException('Daftar notifikasi tidak sesuai.');
      }
      for (final item in items) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException('Isi notifikasi tidak sesuai.');
        }
        result.add(MotherAlert.fromJson(item));
      }
      offset += items.length;
      if (offset >= total) break;
      if (items.isEmpty) {
        throw const FormatException('Halaman notifikasi tidak lengkap.');
      }
    }
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }
}
