enum AppRole {
  mother('mother', 'MotherPage', '/mother'),
  companion('companion', 'CompanionPage', '/companion'),
  professional('professional', 'DoctorPage', '/doctor');

  const AppRole(this.value, this.pageName, this.location);

  final String value;
  final String pageName;
  final String location;

  static AppRole fromJson(Object? value) {
    return AppRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => throw FormatException('Unknown role: $value'),
    );
  }
}
