import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/mother/repositories/connection_repository.dart';
import 'package:mobile/services/backend_api.dart';

const _companionCode = {
  'id': 'code-1',
  'code': 'ABC123',
  'target_role': 'companion',
  'expires_at': '2026-11-14T15:00:00+00:00',
};

void main() {
  test('lists connected people with an Indonesian role label', () async {
    final api = _ConnectionsApi();
    final people = await ConnectionRepository(api)
        .listConnections(accessToken: 'valid-access-token');

    expect(api.gets, ['/connections']);
    expect(people.single.name, 'Pendamping Seed');
    expect(people.single.roleLabel, 'Pendamping');
  });

  test('reuses a live companion code instead of issuing another', () async {
    final api = _ConnectionsApi(liveCodes: [_companionCode]);
    final code = await ConnectionRepository(api)
        .companionCode(accessToken: 'valid-access-token');

    expect(code.code, 'ABC123');
    expect(api.posts, isEmpty);
  });

  test('issues a companion code when none is live', () async {
    final api = _ConnectionsApi();
    final code = await ConnectionRepository(api)
        .companionCode(accessToken: 'valid-access-token');

    expect(api.posts, ['/connections/invite-codes']);
    expect(api.bodies.single, {'target_role': 'companion'});
    expect(code.targetRole, 'companion');
  });

  test('redeeming a code sends it to the backend', () async {
    final api = _ConnectionsApi();
    final person = await ConnectionRepository(api)
        .redeem(accessToken: 'valid-access-token', code: 'XYZ789');

    expect(api.posts, ['/connections']);
    expect(api.bodies.single, {'code': 'XYZ789'});
    expect(person.name, 'Pendamping Seed');
  });
}

class _ConnectionsApi extends BackendApi {
  _ConnectionsApi({this.liveCodes = const []})
    : super(baseUrl: 'https://backend.example.test');

  final List<Map<String, dynamic>> liveCodes;
  final gets = <String>[];
  final posts = <String>[];
  final bodies = <Map<String, Object?>>[];

  static const _connection = {
    'id': 'conn-1',
    'connected_at': '2026-11-14T10:00:00+00:00',
    'counterpart': {'name': 'Pendamping Seed', 'role': 'companion'},
  };

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? query,
    String? accessToken,
  }) async {
    gets.add(path);
    if (path == '/connections/invite-codes') {
      return {
        'invite_codes': liveCodes,
        'count': liveCodes.length,
        'offset': 0,
        'limit': 100,
        'total': liveCodes.length,
      };
    }
    return {
      'connections': [_connection],
      'count': 1,
      'offset': 0,
      'limit': 100,
      'total': 1,
    };
  }

  @override
  Future<Map<String, dynamic>> postJson(
    String path, {
    required Map<String, Object?> body,
    String? accessToken,
  }) async {
    posts.add(path);
    bodies.add(body);
    if (path == '/connections/invite-codes') return {..._companionCode};
    return {..._connection};
  }
}
