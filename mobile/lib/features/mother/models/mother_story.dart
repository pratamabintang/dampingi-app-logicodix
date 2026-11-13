import 'package:flutter/material.dart';

enum MotherMood { verySad, sad, neutral, happy, veryHappy }

extension MotherMoodPresentation on MotherMood {
  Color get color => switch (this) {
    MotherMood.verySad => const Color(0xFFB093C4),
    MotherMood.sad => const Color(0xFFA2B1EA),
    MotherMood.neutral => const Color(0xFFDDD6CA),
    MotherMood.happy => const Color(0xFFAFEAAB),
    MotherMood.veryHappy => const Color(0xFFFBE567),
  };

  String get asset => switch (this) {
    MotherMood.verySad => 'mood-daily-very-sad.svg',
    MotherMood.sad => 'mood-sad.svg',
    MotherMood.neutral => 'mood-neutral.svg',
    MotherMood.happy => 'mood-daily-happy.svg',
    MotherMood.veryHappy => 'mood-daily-very-happy.svg',
  };

  double get faceHeight => switch (this) {
    MotherMood.verySad => 19.85,
    MotherMood.sad => 17.85,
    MotherMood.neutral => 10.85,
    MotherMood.happy => 17.85,
    MotherMood.veryHappy => 23,
  };
}

class MotherStory {
  const MotherStory({
    required this.id,
    required this.weekdayIndex,
    required this.date,
    required this.mood,
    required this.moodLabel,
    required this.title,
    required this.note,
    required this.summary,
  });

  final String id;
  final int weekdayIndex;
  final String date;
  final MotherMood mood;
  final String moodLabel;
  final String title;
  final String note;
  final String summary;

  factory MotherStory.fromJson(Map<String, Object?> json) {
    final id = _requiredString(json, 'id');
    final weekdayIndex = json['weekdayIndex'];
    if (weekdayIndex is! int || weekdayIndex < 0 || weekdayIndex > 6) {
      throw FormatException('Invalid weekdayIndex for story "$id".');
    }

    final moodName = _requiredString(json, 'mood');
    final mood = MotherMood.values
        .where((value) => value.name == moodName)
        .firstOrNull;
    if (mood == null) {
      throw FormatException('Invalid mood "$moodName" for story "$id".');
    }
    return MotherStory(
      id: id,
      weekdayIndex: weekdayIndex,
      date: _requiredString(json, 'date'),
      mood: mood,
      moodLabel: _requiredString(json, 'moodLabel'),
      title: _requiredString(json, 'title'),
      note: _requiredString(json, 'note'),
      summary: _requiredString(json, 'summary'),
    );
  }
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Missing or invalid "$key" in mother story.');
  }
  return value;
}
