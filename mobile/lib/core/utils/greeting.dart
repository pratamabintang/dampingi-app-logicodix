/// Salam sapaan berdasarkan waktu pada perangkat.
///
/// Batas jam:
/// - 04:00 - 10:59 -> "Selamat Pagi"
/// - 11:00 - 14:59 -> "Selamat Siang"
/// - 15:00 - 17:59 -> "Selamat Sore"
/// - 18:00 - 03:59 -> "Selamat Malam"
String greetingForHour(int hour) {
  if (hour >= 4 && hour < 11) return 'Selamat Pagi';
  if (hour >= 11 && hour < 15) return 'Selamat Siang';
  if (hour >= 15 && hour < 18) return 'Selamat Sore';
  return 'Selamat Malam';
}

/// Salam sapaan untuk [now] (default: waktu perangkat saat ini).
String timeGreeting([DateTime? now]) =>
    greetingForHour((now ?? DateTime.now()).hour);
