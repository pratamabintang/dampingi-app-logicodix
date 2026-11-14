import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/core/utils/greeting.dart';

void main() {
  test('greetingForHour picks greeting per time of day', () {
    expect(greetingForHour(0), 'Selamat Malam');
    expect(greetingForHour(3), 'Selamat Malam');
    expect(greetingForHour(4), 'Selamat Pagi');
    expect(greetingForHour(10), 'Selamat Pagi');
    expect(greetingForHour(11), 'Selamat Siang');
    expect(greetingForHour(14), 'Selamat Siang');
    expect(greetingForHour(15), 'Selamat Sore');
    expect(greetingForHour(17), 'Selamat Sore');
    expect(greetingForHour(18), 'Selamat Malam');
    expect(greetingForHour(23), 'Selamat Malam');
  });

  test('timeGreeting uses the given time', () {
    expect(timeGreeting(DateTime(2026, 1, 1, 9)), 'Selamat Pagi');
    expect(timeGreeting(DateTime(2026, 1, 1, 20)), 'Selamat Malam');
  });
}
