import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/mother/models/mother_story.dart';
import 'package:mobile/features/mother/widgets/mother_mood_face.dart';

void main() {
  testWidgets('reusable mood faces match the Figma daily mood designs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 160);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const moods = [
      (mood: MotherMood.verySad, color: Color(0xFFB093C4), faceHeight: 19.85),
      (mood: MotherMood.sad, color: Color(0xFFA2B1EA), faceHeight: 17.85),
      (mood: MotherMood.neutral, color: Color(0xFFDDD6CA), faceHeight: 10.85),
      (mood: MotherMood.happy, color: Color(0xFFAFEAAB), faceHeight: 17.85),
      (mood: MotherMood.veryHappy, color: Color(0xFFFBE567), faceHeight: 23.0),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final entry in moods)
                MotherMoodFace(
                  key: Key('tile-${entry.mood.name}'),
                  mood: entry.mood,
                  expressionKey: Key('expression-${entry.mood.name}'),
                ),
              const MotherMoodFace(key: Key('tile-unset'), mood: null),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final entry in moods) {
      final tile = find.byKey(Key('tile-${entry.mood.name}'));
      expect(tester.getSize(tile), const Size(54, 53));
      final decoration = tester.widget<DecoratedBox>(
        find.descendant(of: tile, matching: find.byType(DecoratedBox)),
      );
      expect((decoration.decoration as BoxDecoration).color, entry.color);
      expect(
        tester.getSize(find.byKey(Key('expression-${entry.mood.name}'))).width,
        closeTo(38, 0.001),
      );
      expect(
        tester.getSize(find.byKey(Key('expression-${entry.mood.name}'))).height,
        closeTo(entry.faceHeight, 0.001),
      );
    }

    final unsetTile = find.byKey(const Key('tile-unset'));
    expect(tester.getSize(unsetTile), const Size(54, 53));
    final unsetDecoration = tester.widget<DecoratedBox>(
      find.descendant(of: unsetTile, matching: find.byType(DecoratedBox)),
    );
    expect(
      (unsetDecoration.decoration as BoxDecoration).color,
      const Color(0xFFF5F5F5),
    );
    expect(
      (unsetDecoration.decoration as BoxDecoration).borderRadius,
      BorderRadius.circular(12),
    );
    expect(find.byType(SvgPicture), findsNWidgets(5));
    expect(find.byType(Image), findsNWidgets(2));
    final unsetRect = tester.getRect(unsetTile);
    final leftEyeRect = tester.getRect(
      find.byKey(const Key('mother-mood-unset-eye-left')),
    );
    expect(leftEyeRect.left, closeTo(unsetRect.left + 8, 0.001));
    expect(leftEyeRect.top, closeTo(unsetRect.top + 18, 0.001));
    expect(leftEyeRect.width, closeTo(17, 0.001));
    expect(leftEyeRect.height, closeTo(10.85, 0.001));
    final rightEyeRect = tester.getRect(
      find.byKey(const Key('mother-mood-unset-eye-right')),
    );
    expect(rightEyeRect.left, closeTo(unsetRect.left + 29, 0.001));
    expect(rightEyeRect.top, closeTo(unsetRect.top + 18, 0.001));
    expect(rightEyeRect.width, closeTo(17, 0.001));
    expect(rightEyeRect.height, closeTo(10.85, 0.001));
  });
}
