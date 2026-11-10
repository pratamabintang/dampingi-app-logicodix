String? validateName(String? value) {
  if (value == null || value.trim().isEmpty) return 'Nama wajib diisi.';
  return null;
}

String? validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return 'Email wajib diisi.';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
    return 'Masukkan alamat email yang valid.';
  }
  return null;
}

String? validatePassword(String? value) {
  if (value == null || value.isEmpty) return 'Kata sandi wajib diisi.';
  return null;
}

String? validatePasswordConfirmation(String? value, String password) {
  if (value == null || value.isEmpty) {
    return 'Konfirmasi kata sandi wajib diisi.';
  }
  if (value != password) return 'Konfirmasi kata sandi tidak cocok.';
  return null;
}
