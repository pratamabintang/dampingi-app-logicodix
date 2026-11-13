import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty.dart';
import '../../../core/widgets/app_submit_button.dart';
import '../../../core/theme/app_theme.dart';
import '../models/mother_story.dart';
import 'mother_page.dart';

class MotherStoryDetailPage extends StatefulWidget {
  const MotherStoryDetailPage({this.story, super.key});

  final MotherStory? story;

  @override
  State<MotherStoryDetailPage> createState() => _MotherStoryDetailPageState();
}

class _MotherStoryDetailPageState extends State<MotherStoryDetailPage> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final story = widget.story;
    if (story == null) return _buildMissingStory(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scale = (constraints.maxWidth / 390)
                .clamp(0.7, 1.15)
                .toDouble();
            double scaled(double value) => value * scale;

            return Center(
              child: SizedBox(
                width: constraints.maxWidth < 390 * scale
                    ? constraints.maxWidth
                    : 390 * scale,
                child: DefaultTextStyle(
                  style: const TextStyle(fontFamily: AppTheme.fontFamily),
                  child: ListView(
                    key: const Key('mother-story-detail-scroll'),
                    padding: EdgeInsets.fromLTRB(
                      scaled(24),
                      scaled(20),
                      scaled(24),
                      scaled(34),
                    ),
                    children: [
                      SizedBox(
                        height: scaled(24),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            key: const Key('mother-story-detail-back'),
                            onPressed: () {
                              if (context.canPop()) {
                                context.pop();
                              } else {
                                context.go('/mother/calendar');
                              }
                            },
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints.tightFor(
                              width: scaled(24),
                              height: scaled(24),
                            ),
                            icon: SvgPicture.asset(
                              'assets/images/mother_calendar/story-back.svg',
                              width: 24,
                              height: 24,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: scaled(36)),
                      _StoryCard(
                        scale: scaled,
                        story: story,
                        isExpanded: _isExpanded,
                        onToggleExpanded: () {
                          setState(() => _isExpanded = !_isExpanded);
                        },
                      ),
                      SizedBox(height: scaled(36)),
                      SizedBox(
                        height: scaled(48),
                        child: AppSubmitButton(
                          key: const Key('mother-story-open-chat'),
                          label: 'Buka di chat AI',
                          onPressed: () => context.go('/mother/chat'),
                          textStyle: TextStyle(
                            fontSize: scaled(16),
                            fontWeight: FontWeight.w600,
                            height: 24 / 16,
                          ),
                          buttonStyle: FilledButton.styleFrom(
                            backgroundColor: AppTheme.coral,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: scaled(20),
                              vertical: scaled(12),
                            ),
                            elevation: 1,
                            shadowColor: const Color(0x0D101828),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(scaled(8)),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: scaled(10)),
                      SizedBox(
                        height: scaled(48),
                        child: AppSubmitButton(
                          key: const Key('mother-story-edit-mood'),
                          label: 'Ubah catatan mood',
                          onPressed: () => showMotherMoodEntry(context),
                          textStyle: TextStyle(
                            fontSize: scaled(16),
                            fontWeight: FontWeight.w600,
                            height: 24 / 16,
                          ),
                          buttonStyle: FilledButton.styleFrom(
                            backgroundColor: AppTheme.coralLight,
                            foregroundColor: AppTheme.coralText,
                            padding: EdgeInsets.symmetric(
                              horizontal: scaled(20),
                              vertical: scaled(12),
                            ),
                            elevation: 1,
                            shadowColor: const Color(0x0D101828),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(scaled(8)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMissingStory(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                key: const Key('mother-story-detail-back'),
                onPressed: () => _goBack(context),
                icon: SvgPicture.asset(
                  'assets/images/mother_calendar/story-back.svg',
                  width: 24,
                  height: 24,
                ),
              ),
              const Expanded(
                child: Center(
                  child: AppEmpty(
                    key: Key('mother-story-detail-missing'),
                    title: 'Catatan tidak tersedia',
                    message: 'Catatan ini tidak dapat ditemukan.',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/mother');
    }
  }
}

class _StoryCard extends StatelessWidget {
  const _StoryCard({
    required this.scale,
    required this.story,
    required this.isExpanded,
    required this.onToggleExpanded,
  });

  final double Function(double) scale;
  final MotherStory story;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: const Key('mother-story-detail-card'),
      padding: EdgeInsets.all(scale(20)),
      borderRadius: scale(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: scale(24),
            width: double.infinity,
            child: Text(
              story.date,
              key: const Key('mother-story-detail-date'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.muted,
                fontSize: scale(16),
                height: 24 / 16,
              ),
            ),
          ),
          SizedBox(height: scale(24)),
          Row(
            children: [
              SizedBox(
                key: const Key('mother-story-detail-mood-icon'),
                width: scale(54),
                height: scale(53),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: story.mood.color,
                    borderRadius: BorderRadius.circular(scale(12)),
                  ),
                  child: Center(
                    child: SvgPicture.asset(
                      story.mood == MotherMood.verySad
                          ? 'assets/images/mother_calendar/story-mood-very-sad.svg'
                          : 'assets/images/mother_home/${story.faceAsset ?? story.mood.asset}',
                      width: scale(38),
                      height: scale(story.mood.faceHeight),
                    ),
                  ),
                ),
              ),
              SizedBox(width: scale(16)),
              Expanded(
                child: Text(
                  story.moodLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.ink,
                    fontSize: scale(16),
                    fontWeight: FontWeight.w600,
                    height: 24 / 16,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: scale(24)),
          if (story.summary.isNotEmpty) ...[
            _AiSummary(scale: scale, summary: story.summary),
            SizedBox(height: scale(24)),
          ],
          _StoryText(
            scale: scale,
            title: story.title,
            story: story.note,
            isExpanded: isExpanded,
            onToggleExpanded: onToggleExpanded,
          ),
        ],
      ),
    );
  }
}

class _AiSummary extends StatelessWidget {
  const _AiSummary({required this.scale, required this.summary});

  final double Function(double) scale;
  final String summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('mother-story-ai-summary'),
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: scale(18), vertical: scale(16)),
      decoration: BoxDecoration(
        color: AppTheme.selectedSurface,
        border: Border.all(color: AppTheme.coral),
        borderRadius: BorderRadius.circular(scale(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ringkasan AI',
            style: TextStyle(
              color: AppTheme.coralText,
              fontSize: scale(14),
              fontWeight: FontWeight.w600,
              height: 20 / 14,
            ),
          ),
          SizedBox(height: scale(10)),
          Text(
            summary,
            key: const Key('mother-story-ai-summary-text'),
            style: TextStyle(
              color: AppTheme.coralText,
              fontSize: scale(14),
              height: 20 / 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryText extends StatelessWidget {
  const _StoryText({
    required this.scale,
    required this.title,
    required this.story,
    required this.isExpanded,
    required this.onToggleExpanded,
  });

  final double Function(double) scale;
  final String title;
  final String story;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: const Color(0xFF252B37),
            fontSize: scale(14),
            fontWeight: FontWeight.w600,
            height: 20 / 14,
          ),
        ),
        SizedBox(height: scale(10)),
        Text(
          story,
          key: const Key('mother-story-detail-text'),
          maxLines: isExpanded ? null : 1,
          overflow: isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
          style: TextStyle(
            color: AppTheme.muted,
            fontSize: scale(16),
            height: 24 / 16,
          ),
        ),
        SizedBox(height: scale(10)),
        SizedBox(
          width: double.infinity,
          height: scale(32),
          child: TextButton(
            key: const Key('mother-story-toggle-text'),
            onPressed: onToggleExpanded,
            style: TextButton.styleFrom(
              backgroundColor: AppTheme.coralLight,
              foregroundColor: AppTheme.coralText,
              padding: EdgeInsets.symmetric(vertical: scale(4)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(scale(8)),
              ),
            ),
            child: Text(
              isExpanded ? 'Lihat lebih sedikit' : 'Lihat lebih banyak',
              style: TextStyle(
                fontSize: scale(16),
                fontWeight: FontWeight.w600,
                height: 24 / 16,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
