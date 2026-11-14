import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/auth/models/login_models.dart';
import 'package:mobile/features/auth/models/stored_session.dart';
import 'package:mobile/features/auth/repositories/session_store.dart';
import 'package:mobile/models/app_role.dart';

StoredSession _session({
  String accessToken = 'ACCESS',
  String refreshToken = 'REFRESH',
}) {
  return StoredSession(
    accessToken: accessToken,
    refreshToken: refreshToken,
    expiresAt: DateTime.utc(2026, 12, 14, 10),
    user: const AuthUser(
      id: 'user-1',
      email: 'ibu@gmail.com',
      name: 'Ibu',
      role: AppRole.mother,
    ),
  );
}

void main() {
  late Map<String, String> data;
  late SecureSessionStore store;

  setUp(() {
    data = {};
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      data,
    );
    store = const SecureSessionStore(FlutterSecureStorage());
  });

  test('a written Session reads back whole', () async {
    await store.writeSession(_session());

    final read = await store.readSession();

    expect(read, isNotNull);
    expect(read!.accessToken, 'ACCESS');
    expect(read.refreshToken, 'REFRESH');
    expect(read.expiresAt, DateTime.utc(2026, 12, 14, 10));
    expect(read.user.id, 'user-1');
    expect(read.user.email, 'ibu@gmail.com');
    expect(read.role, AppRole.mother);
  });

  test('writing a new Session replaces the old one', () async {
    await store.writeSession(_session(accessToken: 'FIRST'));
    await store.writeSession(_session(accessToken: 'SECOND'));

    final read = await store.readSession();

    expect(read!.accessToken, 'SECOND');
    expect(data.keys, hasLength(1));
  });

  test('clearing the Session leaves nothing to read', () async {
    await store.writeSession(_session());

    await store.clearSession();

    expect(await store.readSession(), isNull);
  });

  test('a corrupt Session reads as no Session', () async {
    await store.writeSession(_session());
    data.updateAll((_, __) => '{"access_token": "half');

    expect(await store.readSession(), isNull);
  });

  test('a Session without a Role reads as no Session', () async {
    await store.writeSession(_session());
    data.updateAll(
      (_, __) =>
          '{"access_token":"A","refresh_token":"R",'
          '"expires_at":"2026-12-14T10:00:00Z",'
          '"user":{"id":"u","email":"i@gmail.com"}}',
    );

    expect(await store.readSession(), isNull);
  });

  test('the remembered email survives independently of the Session', () async {
    await store.writeEmail('ibu@gmail.com');
    await store.writeSession(_session());

    await store.clearSession();

    expect(await store.readEmail(), 'ibu@gmail.com');
  });

  test('clearing the remembered email leaves nothing to prefill', () async {
    await store.writeEmail('ibu@gmail.com');

    await store.clearEmail();

    expect(await store.readEmail(), isNull);
  });
}
