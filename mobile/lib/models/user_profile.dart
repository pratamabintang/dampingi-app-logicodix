import 'app_role.dart';

class UserProfile {
  const UserProfile({
    required this.userId,
    required this.name,
    required this.deletedAt,
    required this.role,
  });

  final String userId;
  final String name;
  final String? deletedAt;
  final AppRole role;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final userId = json['user_id'];
    final name = json['name'];
    final deletedAtValue = json['deleted_at'];
    if (userId is! String || name is! String) {
      throw const FormatException('Profile requires user_id and name.');
    }
    if (deletedAtValue != null && deletedAtValue is! String) {
      throw const FormatException(
        'Profile deleted_at must be a string or null.',
      );
    }

    return UserProfile(
      userId: userId,
      name: name,
      deletedAt: deletedAtValue is String ? deletedAtValue : null,
      role: AppRole.fromJson(json['role']),
    );
  }

  Map<String, Object?> toJson() => {
    'user_id': userId,
    'name': name,
    'deleted_at': deletedAt,
    'role': role.value,
  };
}
