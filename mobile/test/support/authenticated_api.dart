import 'package:mobile/features/auth/models/login_models.dart';
import 'package:mobile/services/authenticated_api.dart';
import 'package:mobile/services/backend_api.dart';

/// A client that skips Session bookkeeping, for tests that exercise a
/// repository directly against a fake transport.
AuthenticatedApi authenticatedApiFor(
  BackendApi transport, {
  String? token = 'valid-access-token',
  LoginResponse? session,
}) {
  return AuthenticatedApi(
    transport: transport,
    refresher: SessionRefresher(transport),
    currentToken: () => token,
    currentSession: () => session,
    onRefreshed: (_) async {},
    onExpired: () async {},
  );
}
