import '../../../models/app_role.dart';

class LoginRequest {
  const LoginRequest({required this.email, required this.password});

  final String email;
  final String password;

  Map<String, Object?> toJson() => {'email': email, 'password': password};
}

class RegisterRequest {
  const RegisterRequest({
    required this.name,
    required this.email,
    required this.password,
    required this.role,
  });

  final String name;
  final String email;
  final String password;
  final AppRole role;

  Map<String, Object?> toJson() => {
    'name': name,
    'email': email,
    'password': password,
    'role': role.value,
  };
}

class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
  });

  final String id;
  final String email;
  final String? name;
  final AppRole? role;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final email = json['email'];
    final name = json['name'];
    final role = json['role'];
    if (id is! String || email is! String) {
      throw const FormatException('Login user requires id and email.');
    }
    if (name != null && name is! String) {
      throw const FormatException('Login user name must be a string or null.');
    }

    return AuthUser(
      id: id,
      email: email,
      name: name as String?,
      role: role == null ? null : AppRole.fromJson(role),
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'email': email,
    'name': name,
    'role': role?.value,
  };
}

class LoginResponse {
  const LoginResponse({
    required this.accessToken,
    required this.user,
    this.refreshToken,
    this.expiresIn,
    this.expiresAt,
  });

  final String accessToken;
  final AuthUser user;
  final String? refreshToken;
  final int? expiresIn;

  /// Absolute expiry of [accessToken]; null when the server did not say.
  final DateTime? expiresAt;

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    final token = json['access_token'];
    final user = json['user'];
    if (token is! String || token.isEmpty || user is! Map<String, dynamic>) {
      throw const FormatException(
        'Login response requires access_token and user.',
      );
    }
    final refreshToken = json['refresh_token'];
    final expiresIn = json['expires_in'];
    final expiresAt = json['expires_at'];
    return LoginResponse(
      accessToken: token,
      user: AuthUser.fromJson(user),
      refreshToken: refreshToken is String && refreshToken.isNotEmpty
          ? refreshToken
          : null,
      expiresIn: expiresIn is int ? expiresIn : null,
      expiresAt: expiresAt is String
          ? DateTime.tryParse(expiresAt)?.toUtc()
          : null,
    );
  }

  Map<String, Object?> toJson() => {
    'access_token': accessToken,
    'refresh_token': refreshToken,
    'expires_in': expiresIn,
    'expires_at': expiresAt?.toIso8601String(),
    'user': user.toJson(),
  };
}

class AuthState {
  const AuthState({
    required this.selectedRole,
    this.session,
    this.rememberedEmail,
    this.isSubmitting = false,
    this.errorMessage,
  });

  final AppRole? selectedRole;
  final LoginResponse? session;
  final String? rememberedEmail;
  final bool isSubmitting;
  final String? errorMessage;

  AuthState copyWith({
    AppRole? selectedRole,
    LoginResponse? session,
    bool clearSession = false,
    String? rememberedEmail,
    bool clearRememberedEmail = false,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      selectedRole: selectedRole ?? this.selectedRole,
      session: clearSession ? null : session ?? this.session,
      rememberedEmail: clearRememberedEmail
          ? null
          : rememberedEmail ?? this.rememberedEmail,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
