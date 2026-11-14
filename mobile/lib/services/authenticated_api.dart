import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/controller/auth_controller.dart';
import '../features/auth/models/login_models.dart';
import 'backend_api.dart';

/// The Session can no longer be used: refresh was rejected or there is nothing
/// left to refresh. Subclasses [BackendApiException] so every existing failure
/// mapper already treats it as an ended Session.
class SessionExpiredException extends BackendApiException {
  const SessionExpiredException()
    : super(
        statusCode: 401,
        message: 'Sesi telah berakhir. Silakan masuk kembali.',
      );
}

final sessionRefresherProvider = Provider<SessionRefresher>(
  (ref) => SessionRefresher(ref.watch(backendApiProvider)),
);

/// Trades a refresh token for a new Session pair.
///
/// Rejected tokens are an ended Session; network trouble is not, so the
/// caller can keep the stored Session and try again later.
class SessionRefresher {
  const SessionRefresher(this._transport);

  final BackendApi _transport;

  Future<LoginResponse> refresh({
    required String refreshToken,
    required AuthUser user,
  }) async {
    try {
      final json = await _transport.postJson(
        '/auth/refresh',
        body: {'refresh_token': refreshToken},
      );
      return sessionFrom(json, user);
    } on BackendApiException catch (error) {
      if (error.statusCode == 400 || error.statusCode == 401) {
        throw const SessionExpiredException();
      }
      rethrow;
    }
  }

  static LoginResponse sessionFrom(Map<String, dynamic> json, AuthUser user) {
    final accessToken = json['access_token'];
    final refreshToken = json['refresh_token'];
    if (accessToken is! String ||
        accessToken.isEmpty ||
        refreshToken is! String ||
        refreshToken.isEmpty) {
      throw const FormatException('Refresh response is incomplete.');
    }
    final expiresIn = json['expires_in'];
    final seconds = expiresIn is int ? expiresIn : 3600;
    return LoginResponse(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresIn: seconds,
      expiresAt: DateTime.now().toUtc().add(Duration(seconds: seconds)),
      user: user,
    );
  }
}

final authenticatedApiProvider = Provider<AuthenticatedApi>((ref) {
  return AuthenticatedApi(
    transport: ref.watch(backendApiProvider),
    refresher: ref.watch(sessionRefresherProvider),
    currentToken: () => ref.read(backendTokenProvider),
    currentSession: () =>
        ref.read(authControllerProvider).asData?.value.session,
    onRefreshed: (session) => ref
        .read(authControllerProvider.notifier)
        .applyRefreshedSession(session),
    onExpired: () => ref.read(authControllerProvider.notifier).expireSession(),
  );
});

/// One gate for every request that needs a login.
///
/// It injects the latest access token, refreshes shortly before expiry, and on
/// a `401` refreshes once and retries. Concurrent `401`s share one refresh, so
/// a rotating refresh token is never burned twice.
class AuthenticatedApi {
  AuthenticatedApi({
    required BackendApi transport,
    required SessionRefresher refresher,
    required String? Function() currentToken,
    required LoginResponse? Function() currentSession,
    required Future<void> Function(LoginResponse) onRefreshed,
    required Future<void> Function() onExpired,
  }) : _transport = transport,
       _refresher = refresher,
       _currentToken = currentToken,
       _currentSession = currentSession,
       _onRefreshed = onRefreshed,
       _onExpired = onExpired;

  static const _refreshMargin = Duration(seconds: 60);

  final BackendApi _transport;
  final SessionRefresher _refresher;
  final String? Function() _currentToken;
  final LoginResponse? Function() _currentSession;
  final Future<void> Function(LoginResponse) _onRefreshed;
  final Future<void> Function() _onExpired;

  Future<void>? _refreshing;

  Future<Map<String, dynamic>> postJson(
    String path, {
    required Map<String, Object?> body,
  }) {
    return _send('POST', path, body: body);
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? query,
  }) {
    return _send('GET', path, query: query);
  }

  Future<Map<String, dynamic>> patchJson(
    String path, {
    required Map<String, Object?> body,
  }) {
    return _send('PATCH', path, body: body);
  }

  Future<Map<String, dynamic>> deleteJson(String path) {
    return _send('DELETE', path);
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, Object?>? body,
    Map<String, String>? query,
  }) async {
    if (_token() == null) throw const SessionExpiredException();
    await _refreshIfExpiringSoon();
    return _attempt(method, path, body: body, query: query, retryOn401: true);
  }

  Future<Map<String, dynamic>> _attempt(
    String method,
    String path, {
    Map<String, Object?>? body,
    Map<String, String>? query,
    required bool retryOn401,
  }) async {
    final token = _token();
    if (token == null) throw const SessionExpiredException();
    try {
      return await _sendWithToken(
        method,
        path,
        body: body,
        query: query,
        accessToken: token,
      );
    } on BackendApiException catch (error) {
      if (error.statusCode != 401 ||
          !retryOn401 ||
          _session()?.refreshToken == null) {
        rethrow;
      }
      await _refreshOnce();
      return _attempt(
        method,
        path,
        body: body,
        query: query,
        retryOn401: false,
      );
    }
  }

  Future<Map<String, dynamic>> _sendWithToken(
    String method,
    String path, {
    Map<String, Object?>? body,
    Map<String, String>? query,
    required String accessToken,
  }) {
    return switch (method) {
      'POST' => _transport.postJson(
        path,
        body: body ?? const {},
        accessToken: accessToken,
      ),
      'GET' => _transport.getJson(path, query: query, accessToken: accessToken),
      'PATCH' => _transport.patchJson(
        path,
        body: body ?? const {},
        accessToken: accessToken,
      ),
      'DELETE' => _transport.deleteJson(path, accessToken: accessToken),
      _ => throw ArgumentError.value(method, 'method'),
    };
  }

  Future<void> _refreshIfExpiringSoon() async {
    final session = _session();
    final expiresAt = session?.expiresAt;
    if (session == null || expiresAt == null) return;
    if (expiresAt.isAfter(DateTime.now().toUtc().add(_refreshMargin))) return;
    if (session.refreshToken == null) return;
    await _refreshOnce();
  }

  Future<void> _refreshOnce() {
    return _refreshing ??= _doRefresh().whenComplete(() {
      _refreshing = null;
    });
  }

  Future<void> _doRefresh() async {
    final session = _session();
    final refreshToken = session?.refreshToken;
    if (session == null || refreshToken == null) {
      await _onExpired();
      throw const SessionExpiredException();
    }
    try {
      final refreshed = await _refresher.refresh(
        refreshToken: refreshToken,
        user: session.user,
      );
      await _onRefreshed(refreshed);
    } on SessionExpiredException {
      await _onExpired();
      rethrow;
    }
  }

  LoginResponse? _session() => _currentSession();

  String? _token() => _currentToken();
}
