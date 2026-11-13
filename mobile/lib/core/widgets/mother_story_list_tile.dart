import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../features/mother/models/mother_story.dart';
import '../theme/app_theme.dart';

class MotherStoryListTile extends StatelessWidget {
  const MotherStoryListTile({
    required this.story,
    required this.scale,
    required this.keyPrefix,
    required this.onTap,
    this.arrowAsset = 'assets/images/mother_home/arrow-right.svg',
    this.snippetFontSize = 14,
    this.centerFace = false,
    super.key,
  });

  final MotherStory story;
  final double scale;
  final String keyPrefix;
  final VoidCallback onTap;
  final String arrowAsset;
  final double snippetFontSize;
  final bool centerFace;

  @override
  Widget build(BuildContext context) {
    final arrowSize = (24 * scale).clamp(16.0, 24.0);
    return Semantics(
      button: true,
      label: 'Buka catatan ${story.title}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('$keyPrefix-row'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(16 * scale),
          child: Row(
            children: [
              SizedBox(
                key: Key('$keyPrefix-tile'),
                width: 83 * scale,
                height: 83 * scale,
                child: Stack(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppTheme.pink2,
                        borderRadius: BorderRadius.circular(32 * scale),
                      ),
                      child: const SizedBox.expand(),
                    ),
                    Positioned(
                      left: 15 * scale,
                      top: 15 * scale,
                      child: SizedBox(
                        width: 54 * scale,
                        height: 53 * scale,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: story.mood.color,
                            borderRadius: BorderRadius.circular(12 * scale),
                          ),
                          child: centerFace
                              ? Center(child: _face(scale, keyPrefix))
                              : Padding(
                                  padding: EdgeInsets.only(
                                    left: 8 * scale,
                                    top: 18 * scale,
                                  ),
                                  child: Align(
                                    alignment: Alignment.topLeft,
                                    child: _face(scale, keyPrefix),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 16 * scale),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      key: Key('$keyPrefix-title'),
                      story.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFF252B37),
                        fontSize: 14 * scale,
                        fontWeight: FontWeight.w600,
                        height: 20 / 14,
                      ),
                    ),
                    SizedBox(height: 10 * scale),
                    Text(
                      key: Key('$keyPrefix-snippet'),
                      story.note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.muted,
                        fontSize: snippetFontSize * scale,
                        height: 24 / snippetFontSize,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: (arrowSize >= 24 ? 16 : 8) * scale),
              SvgPicture.asset(
                arrowAsset,
                key: Key('$keyPrefix-arrow'),
                width: arrowSize,
                height: arrowSize,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _face(double scale, String prefix) => SvgPicture.asset(
    'assets/images/mother_home/${story.faceAsset ?? story.mood.asset}',
    key: Key('$prefix-face'),
    width: 38 * scale,
    height: story.mood.faceHeight * scale,
  );
}
