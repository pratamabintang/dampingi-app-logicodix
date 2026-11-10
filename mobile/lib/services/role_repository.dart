import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_role.dart';
import '../models/user_profile.dart';

const profileFixturePath = 'assets/fixtures/profiles-select-2026-11-09.json';

final roleRepositoryProvider = Provider<RoleRepository>(
  (ref) => RoleRepository(),
);

class RoleRepository {
  RoleRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  Future<UserProfile> loadProfile() async {
    final contents = await _bundle.loadString(profileFixturePath);
    final decoded = jsonDecode(contents);
    if (decoded is! Map<String, dynamic> ||
        decoded['payload'] is! Map<String, dynamic>) {
      throw const FormatException('Profile fixture requires a payload object.');
    }
    return UserProfile.fromJson(decoded['payload'] as Map<String, dynamic>);
  }

  Future<AppRole?> loadStartupRole() async {
    final profile = await loadProfile();
    return profile.deletedAt == null ? profile.role : null;
  }
}
