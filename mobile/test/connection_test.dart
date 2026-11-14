import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/connections/repositories/connection_repository.dart';
import 'package:mobile/services/backend_api.dart';

const _liveCode = {
  'id': 'code-1',
  'code': 'KDMN-PRTG',
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

  test('listing live Invite codes asks for them and creates nothing', () async {
    final api = _ConnectionsApi(liveCodes: [_liveCode]);
    final codes = await ConnectionRepository(api)
        .listInviteCodes(accessToken: 'valid-access-token');

    expect(api.gets, ['/connections/invite-codes']);
    expect(api.posts, isEmpty);
    expect(codes.single.code, 'KDMN-PRTG');
    expect(codes.single.targetRole, 'companion');
    expect(codes.single.targetRoleLabel, 'Pendamping');
    expect(codes.single.expiresAt, '2026-11-14T15:00:00+00:00');
  });

  test('an empty Invite code list is an empty list, not a failure', () async {
    final api = _ConnectionsApi();
    final codes = await ConnectionRepository(api)
        .listInviteCodes(accessToken: 'valid-access-token');

    expect(codes, isEmpty);
  });

  test('redeeming trims and upper-cases the typed code', () async {
    final api = _ConnectionsApi();
    final person = await ConnectionRepository(api)
        .redeem(accessToken: 'valid-access-token', code: '  kdmn-prtg  ');

    expect(api.posts, ['/connections']);
    expect(api.bodies.single, {'code': 'KDMN-PRTG'});
    expect(person.name, 'Pendamping Seed');
  });

  test(
    'a malformed code still becomes a request, not a local refusal',
    () async {
      final api = _ConnectionsApi();
      await ConnectionRepository(api)
          .redeem(accessToken: 'valid-access-token', code: 'ab');

      expect(api.posts, ['/connections']);
      expect(api.bodies.single, {'code': 'AB'});
    },
  );

  test('issuing sends the chosen target Role and nothing else', () async {
    final api = _ConnectionsApi();
    final code = await ConnectionRepository(api).issueInviteCode(
      accessToken: 'valid-access-token',
      targetRole: 'professional',
    );

    expect(api.posts, ['/connections/invite-codes']);
    expect(api.bodies.single, {'target_role': 'professional'});
    expect(api.tokens, ['valid-access-token']);
    expect(code.targetRole, 'professional');
    expect(code.code, 'KDNK-SHTP');
  });

  test('a Companion and a Professional both issue for a Mother', () async {
    for (final token in const [
      'companion-access-token',
      'professional-access-token',
    ]) {
      final api = _ConnectionsApi();
      final code = await ConnectionRepository(api)
          .issueInviteCode(accessToken: token, targetRole: 'mother');

      expect(api.posts, ['/connections/invite-codes']);
      expect(api.bodies.single, {'target_role': 'mother'});
      expect(api.tokens, [token]);
      expect(code.targetRole, 'mother');
      expect(code.targetRoleLabel, 'Ibu');
    }
  });

  test(
    'a Companion or Professional refusal keeps the backend wording',
    () async {
      const details = {
        409: 'You are already connected to a mother',
        404: 'Invite code is not valid',
        503: 'Could not allocate an invite code; please try again',
      };
      final messages = <String>{};

      for (final token in const [
        'companion-access-token',
        'professional-access-token',
      ]) {
        for (final entry in details.entries) {
          final api = _ConnectionsApi()
            ..postError = BackendApiException(
              statusCode: entry.key,
              message: entry.value,
            );
          try {
            await ConnectionRepository(api)
                .issueInviteCode(accessToken: token, targetRole: 'mother');
            fail('Penerbitan ${entry.key} seharusnya ditolak.');
          } on Exception catch (error) {
            messages.add(connectionFailureMessage(error));
          }
        }
      }

      expect(messages, details.values.toSet());
    },
  );

  test('revoking addresses the code the caller chose', () async {
    final api = _ConnectionsApi();
    await ConnectionRepository(api)
        .revokeInviteCode(accessToken: 'valid-access-token', id: 'code-7');

    expect(api.deletes, ['/connections/invite-codes/code-7']);
    expect(api.tokens, ['valid-access-token']);
  });

  test('ending addresses the Connection the caller chose', () async {
    final api = _ConnectionsApi();
    await ConnectionRepository(api)
        .endConnection(accessToken: 'valid-access-token', id: 'conn-7');

    expect(api.deletes, ['/connections/conn-7']);
    expect(api.tokens, ['valid-access-token']);
  });

  test('every redeem refusal keeps its own outcome', () async {
    const details = {
      400: 'Invite code is malformed: expected XXXX-XXXX',
      403: 'This invite code is for a companion',
      404: 'Invite code is not valid',
      409: 'You are already connected to a mother',
      429: 'Too many requests. Please try again later.',
      503: 'The service is temporarily unavailable. Please try again later.',
    };
    final messages = <String>{};

    for (final entry in details.entries) {
      final api = _ConnectionsApi()
        ..postError = BackendApiException(
          statusCode: entry.key,
          message: entry.value,
        );
      try {
        await ConnectionRepository(api)
            .redeem(accessToken: 'valid-access-token', code: 'KDMN-PRTG');
        fail('Penukaran ${entry.key} seharusnya ditolak.');
      } on Exception catch (error) {
        messages.add(connectionFailureMessage(error));
      }
    }

    expect(messages, details.values.toSet());
    expect(messages.length, 6);
  });

  test('a redeem refusal that is a lost session says so locally', () async {
    final api = _ConnectionsApi()
      ..postError = const BackendApiException(
        statusCode: 401,
        message: 'Not authenticated',
      );
    try {
      await ConnectionRepository(api)
          .redeem(accessToken: 'valid-access-token', code: 'KDMN-PRTG');
      fail('Penukaran tanpa sesi seharusnya ditolak.');
    } on Exception catch (error) {
      expect(
        connectionFailureMessage(error),
        'Sesi login telah berakhir. Silakan masuk kembali.',
      );
    }
  });

  test('the limit, not-found and upstream refusals read differently', () async {
    Future<String> messageFor(int statusCode, String detail) async {
      final api = _ConnectionsApi()
        ..postError = BackendApiException(
          statusCode: statusCode,
          message: detail,
        );
      try {
        await ConnectionRepository(api).issueInviteCode(
          accessToken: 'valid-access-token',
          targetRole: 'professional',
        );
      } on Exception catch (error) {
        return connectionFailureMessage(error);
      }
      fail('Penerbitan seharusnya ditolak.');
    }

    final limit = await messageFor(
      409,
      'This mother already has a professional',
    );
    final missing = await messageFor(404, 'Invite code is not valid');
    final upstream = await messageFor(
      503,
      'Could not allocate an invite code; please try again',
    );

    expect(limit, 'This mother already has a professional');
    expect(missing, 'Invite code is not valid');
    expect(upstream, 'Could not allocate an invite code; please try again');
    expect({limit, missing, upstream}.length, 3);
  });
}

/// Jawaban backend yang sengaja hanya membawa amplopnya: klien tidak boleh
/// bergantung pada medan paginasi yang tidak dipakainya.
class _ConnectionsApi extends BackendApi {
  _ConnectionsApi({this.liveCodes = const []})
    : super(baseUrl: 'https://backend.example.test');

  final List<Map<String, dynamic>> liveCodes;
  Object? postError;
  final gets = <String>[];
  final posts = <String>[];
  final deletes = <String>[];
  final bodies = <Map<String, Object?>>[];
  final tokens = <String?>[];

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
    tokens.add(accessToken);
    if (path == '/connections/invite-codes') {
      return {'invite_codes': liveCodes};
    }
    return {
      'connections': [_connection],
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
    tokens.add(accessToken);
    final failure = postError;
    if (failure != null) throw failure;
    if (path == '/connections/invite-codes') {
      final target = body['target_role'];
      return {
        'id': 'code-new',
        'code': target == 'professional' ? 'KDNK-SHTP' : 'KDMN-PRTG',
        'target_role': target,
        'expires_at': '2026-11-14T15:00:00+00:00',
      };
    }
    return {..._connection};
  }

  @override
  Future<Map<String, dynamic>> deleteJson(
    String path, {
    String? accessToken,
  }) async {
    deletes.add(path);
    tokens.add(accessToken);
    return {};
  }
}
