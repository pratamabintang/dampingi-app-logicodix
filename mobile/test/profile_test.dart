import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/auth/repositories/profile_repository.dart';
import 'package:mobile/models/app_role.dart';
import 'package:mobile/services/backend_api.dart';

void main() {
  test('saving the profile sends only the name', () async {
    final api = _ProfileApi();
    final user = await ProfileRepository(api)
        .updateName(accessToken: 'valid-access-token', name: 'Ibu Sari');

    expect(api.calls, ['PATCH /me']);
    expect(api.bodies.single, {'name': 'Ibu Sari'});
    expect(api.tokens.single, 'valid-access-token');
    expect(user.name, 'Ibu Sari');
    expect(user.role, AppRole.mother);
  });

  test('changing the password sends the current and new password', () async {
    final api = _ProfileApi();
    await ProfileRepository(api).changePassword(
      accessToken: 'valid-access-token',
      currentPassword: 'lama12345',
      newPassword: 'baru12345',
    );

    expect(api.calls, ['POST /auth/password']);
    expect(api.bodies.single, {
      'current_password': 'lama12345',
      'new_password': 'baru12345',
    });
  });

  test('a wrong current password surfaces the backend error', () async {
    final api = _ProfileApi(
      passwordError: const BackendApiException(
        statusCode: 400,
        message: 'Current password is incorrect',
      ),
    );

    await expectLater(
      ProfileRepository(api).changePassword(
        accessToken: 'valid-access-token',
        currentPassword: 'salah',
        newPassword: 'baru12345',
      ),
      throwsA(
        isA<BackendApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          400,
        ),
      ),
    );
  });
}

class _ProfileApi extends BackendApi {
  _ProfileApi({this.passwordError})
    : super(baseUrl: 'https://backend.example.test');

  final BackendApiException? passwordError;
  final calls = <String>[];
  final bodies = <Map<String, Object?>>[];
  final tokens = <String?>[];

  @override
  Future<Map<String, dynamic>> patchJson(
    String path, {
    required Map<String, Object?> body,
    String? accessToken,
  }) async {
    calls.add('PATCH $path');
    bodies.add(body);
    tokens.add(accessToken);
    return {
      'id': 'mother-1',
      'email': 'mother@example.test',
      'name': body['name'],
      'role': 'mother',
    };
  }

  @override
  Future<Map<String, dynamic>> postJson(
    String path, {
    required Map<String, Object?> body,
    String? accessToken,
  }) async {
    calls.add('POST $path');
    bodies.add(body);
    tokens.add(accessToken);
    final error = passwordError;
    if (error != null) throw error;
    // 204 No Content dari backend; BackendApi mengubahnya jadi objek kosong.
    return {};
  }
}
