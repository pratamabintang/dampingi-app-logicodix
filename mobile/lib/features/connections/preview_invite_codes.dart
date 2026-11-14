import 'repositories/connection_repository.dart';

/// Kode undangan contoh untuk mode preview (tanpa backend), satu per Peran
/// target.
///
/// Setiap kode harus lolos kontrak: delapan karakter dari `A–H, J–N, P–Z, 2–9`
/// dalam bentuk `XXXX-XXXX`. Semua layar yang membutuhkan kode contoh
/// mengambilnya dari sini, supaya tidak ada lagi beberapa konstanta berbeda
/// untuk hal yang sama.
const previewInviteCodeForCompanion = 'KDMN-PRTG';
const previewInviteCodeForProfessional = 'KDNK-SHTP';
const previewInviteCodeForMother = 'KDBU-HMKN';

/// Kode undangan contoh untuk satu Peran target.
String previewInviteCodeForRole(String targetRole) => switch (targetRole) {
  'companion' => previewInviteCodeForCompanion,
  'professional' => previewInviteCodeForProfessional,
  'mother' => previewInviteCodeForMother,
  _ => targetRole,
};

/// Satu kode undangan preview yang baru untuk Peran target, dengan masa berlaku
/// dihitung saat dipanggil supaya kode contoh tidak pernah tampak kedaluwarsa.
InviteCode freshPreviewInviteCodeFor(String targetRole) => InviteCode(
  id: 'preview-code-$targetRole',
  code: previewInviteCodeForRole(targetRole),
  targetRole: targetRole,
  expiresAt: DateTime.now()
      .toUtc()
      .add(const Duration(hours: 1))
      .toIso8601String(),
);

/// Kode undangan "hidup" untuk mode preview: satu per Peran target yang bisa
/// diterbitkan pemanggil.
List<InviteCode> previewInviteCodesFor(List<String> targetRoles) => [
  for (final targetRole in targetRoles) freshPreviewInviteCodeFor(targetRole),
];

/// Kode undangan "hidup" untuk mode preview milik Ibu.
List<InviteCode> previewInviteCodes() =>
    previewInviteCodesFor(const ['companion', 'professional']);
