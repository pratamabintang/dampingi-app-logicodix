/// Satu butir EPDS: pertanyaan dan 4 pilihan jawaban.
class EpdsQuestion {
  const EpdsQuestion(this.text, this.options);

  final String text;
  final List<String> options;
}

/// Edinburgh Postnatal Depression Scale (EPDS).
/// Cox, J. L., Holden, J. M., & Sagovsky, R. (1987). Detection of postnatal
/// depression: Development of the 10-item Edinburgh Postnatal Depression Scale.
/// British Journal of Psychiatry, 150, 782–786.
///
/// Urutan pilihan HARUS sama dengan EPDS asli: backend menghitung skor dari
/// indeksnya (Q1, Q2, Q4 langsung 0..3; butir lain dibalik 3..0).
const epdsQuestions = <EpdsQuestion>[
  EpdsQuestion('Saya dapat tertawa dan melihat sisi lucu dari berbagai hal', [
    'Sama seperti biasanya',
    'Tidak terlalu sering sekarang',
    'Jelas tidak sesering dulu',
    'Sama sekali tidak',
  ]),
  EpdsQuestion('Saya menanti-nanti sesuatu dengan senang hati', [
    'Sama seperti biasanya',
    'Agak kurang dibanding biasanya',
    'Jelas kurang dibanding biasanya',
    'Hampir tidak sama sekali',
  ]),
  EpdsQuestion(
    'Saya menyalahkan diri sendiri secara berlebihan ketika ada hal yang '
    'tidak berjalan baik',
    [
      'Ya, hampir setiap saat',
      'Ya, kadang-kadang',
      'Tidak terlalu sering',
      'Tidak, tidak pernah',
    ],
  ),
  EpdsQuestion('Saya merasa cemas atau khawatir tanpa alasan yang jelas', [
    'Tidak, sama sekali tidak',
    'Hampir tidak pernah',
    'Ya, kadang-kadang',
    'Ya, sangat sering',
  ]),
  EpdsQuestion('Saya merasa takut atau panik tanpa alasan yang jelas', [
    'Ya, cukup sering',
    'Ya, kadang-kadang',
    'Tidak, jarang',
    'Tidak, sama sekali tidak',
  ]),
  EpdsQuestion('Banyak hal terasa terlalu berat untuk saya hadapi', [
    'Ya, hampir selalu tidak sanggup',
    'Ya, kadang tidak sanggup seperti biasanya',
    'Tidak, biasanya masih sanggup',
    'Tidak, sanggup seperti biasanya',
  ]),
  EpdsQuestion('Saya merasa sangat tidak bahagia sampai sulit tidur', [
    'Ya, hampir setiap saat',
    'Ya, kadang-kadang',
    'Tidak terlalu sering',
    'Tidak, sama sekali tidak',
  ]),
  EpdsQuestion('Saya merasa sedih atau sengsara', [
    'Ya, hampir setiap saat',
    'Ya, cukup sering',
    'Tidak terlalu sering',
    'Tidak, sama sekali tidak',
  ]),
  EpdsQuestion('Saya merasa sangat tidak bahagia sampai menangis', [
    'Ya, hampir setiap saat',
    'Ya, cukup sering',
    'Hanya sesekali',
    'Tidak, tidak pernah',
  ]),
  EpdsQuestion('Pikiran untuk menyakiti diri sendiri pernah muncul', [
    'Ya, cukup sering',
    'Kadang-kadang',
    'Hampir tidak pernah',
    'Tidak pernah',
  ]),
];

/// Indeks pilihan "Tidak pernah" di pertanyaan 10. Selain ini = perlu perhatian segera.
const epdsSafeItem10Index = 3;
