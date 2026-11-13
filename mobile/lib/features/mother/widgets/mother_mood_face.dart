import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/mother_story.dart';

class MotherMoodFace extends StatelessWidget {
  const MotherMoodFace({
    super.key,
    required this.mood,
    this.scale = 1,
    this.large = false,
    this.expressionKey,
  });

  final MotherMood? mood;
  final double scale;
  final bool large;
  final Key? expressionKey;

  @override
  Widget build(BuildContext context) {
    final size = large ? 100.0 : 54.0;
    final height = large ? 98.0 : 53.0;
    final radius = large ? 22.2 : 12.0;

    return SizedBox(
      width: size * scale,
      height: height * scale,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: mood?.color ?? const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(radius * scale),
        ),
        child: mood == null
            ? _UnsetMoodEyes(scale: scale)
            : large
            ? Center(
                child: SvgPicture.asset(
                  'assets/images/mother_home/${mood!.asset}',
                  key: expressionKey,
                  width: 70.3 * scale,
                  height: 42.5 * scale,
                ),
              )
            : Padding(
                padding: EdgeInsets.only(
                  left: _faceLeft(mood!) * scale,
                  top: 18 * scale,
                ),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SvgPicture.asset(
                    'assets/images/mother_home/${mood!.asset}',
                    key: expressionKey,
                    width: 38 * scale,
                    height: mood!.faceHeight * scale,
                  ),
                ),
              ),
      ),
    );
  }

  double _faceLeft(MotherMood mood) => switch (mood) {
    MotherMood.verySad => 8,
    MotherMood.sad => 8.5,
    MotherMood.neutral => 8,
    MotherMood.happy => 8.5,
    MotherMood.veryHappy => 9,
  };
}

class _UnsetMoodEyes extends StatelessWidget {
  const _UnsetMoodEyes({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 8 * scale,
          top: 18 * scale,
          child: Row(
            children: [
              Image.asset(
                'assets/images/mother_home/mood-unset-eye-left.png',
                key: const Key('mother-mood-unset-eye-left'),
                width: 17 * scale,
                height: 10.85 * scale,
                fit: BoxFit.fill,
              ),
              SizedBox(width: 4 * scale),
              Image.asset(
                'assets/images/mother_home/mood-unset-eye-right.png',
                key: const Key('mother-mood-unset-eye-right'),
                width: 17 * scale,
                height: 10.85 * scale,
                fit: BoxFit.fill,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
