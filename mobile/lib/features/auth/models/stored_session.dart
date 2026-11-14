import '../../../models/app_role.dart';
import 'login_models.dart';

/// A Session as remembered on the device.
///
/// The Profile snapshot is enough to route the user after a restart; Role is
/// fixed at Profile creation (ADR-0005), so the snapshot cannot go stale in a
/// way that changes authorization.
class StoredSession {
  const StoredSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final AuthUser user;

  AppRole? get role => user.role;

  bool get isExpired => !expiresAt.isAfter(DateTime.now().toUtc());

  StoredSession copyWith({
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    AuthUser? user,
  }) {
    return StoredSession(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresAt: expiresAt ?? this.expiresAt,
      user: user ?? this.user,
    );
  }

  Map<String, Object?> toJson() => {
    'access_token': accessToken,
    'refresh_token': refreshToken,
    'expires_at': expiresAt.toUtc().toIso8601String(),
    'user': user.toJson(),
  };

  factory StoredSession.fromJson(Map<String, dynamic> json) {
    final accessToken = json['access_token'];
    final refreshToken = json['refresh_token'];
    final expiresAt = json['expires_at'];
    final user = json['user'];
    if (accessToken is! String ||
        accessToken.isEmpty ||
        refreshToken is! String ||
        refreshToken.isEmpty ||
        expiresAt is! String ||
        user is! Map<String, dynamic>) {
      throw const FormatException('Stored session is incomplete.');
    }
    final parsedExpiry = DateTime.tryParse(expiresAt);
    if (parsedExpiry == null) {
      throw const FormatException('Stored session expiry is malformed.');
    }
    final parsedUser = AuthUser.fromJson(user);
    if (parsedUser.role == null) {
      throw const FormatException('Stored session has no Role.');
    }
    return StoredSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: parsedExpiry.toUtc(),
      user: parsedUser,
    );
  }
}
