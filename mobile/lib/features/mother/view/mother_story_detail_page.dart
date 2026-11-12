import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import 'mother_page.dart';

class MotherStoryDetailPage extends StatefulWidget {
  const MotherStoryDetailPage({super.key});

  @override
  State<MotherStoryDetailPage> createState() => _MotherStoryDetailPageState();
}

class _MotherStoryDetailPageState extends State<MotherStoryDetailPage> {
  static const _story =
      'Senang karena ada suami yang bantu aku untuk ke belakang, kok bisa '
      'suami bantu aku ke belakang padahal suami lagi di luar kota.';

  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
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
                  style: const TextStyle(fontFamily: 'Mona Sans'),
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
                        story: _story,
                        isExpanded: _isExpanded,
                        onToggleExpanded: () {
                          setState(() => _isExpanded = !_isExpanded);
                        },
                      ),
                      SizedBox(height: scaled(36)),
                      SizedBox(
                        height: scaled(48),
                        child: FilledButton(
                          key: const Key('mother-story-open-chat'),
                          onPressed: () => context.go('/mother/chat'),
                          style: FilledButton.styleFrom(
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
                          child: Text(
                            'Buka di chat AI',
                            style: TextStyle(
                              fontSize: scaled(16),
                              fontWeight: FontWeight.w600,
                              height: 24 / 16,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: scaled(10)),
                      SizedBox(
                        height: scaled(48),
                        child: FilledButton(
                          key: const Key('mother-story-edit-mood'),
                          onPressed: () => showMotherMoodEntry(context),
                          style: FilledButton.styleFrom(
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
                          child: Text(
                            'Ubah catatan mood',
                            style: TextStyle(
                              fontSize: scaled(16),
                              fontWeight: FontWeight.w600,
                              height: 24 / 16,
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
}

class _StoryCard extends StatelessWidget {
  const _StoryCard({
    required this.scale,
    required this.story,
    required this.isExpanded,
    required this.onToggleExpanded,
  });

  final double Function(double) scale;
  final String story;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('mother-story-detail-card'),
      width: double.infinity,
      padding: EdgeInsets.all(scale(20)),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFFAFAFA)),
        borderRadius: BorderRadius.circular(scale(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: scale(24),
            width: double.infinity,
            child: Text(
              'Senin, 12 Agustus 2026',
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
                    color: const Color(0xFFB093C4),
                    borderRadius: BorderRadius.circular(scale(12)),
                  ),
                  child: Padding(
                    padding: EdgeInsets.only(left: scale(8), top: scale(18)),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Transform.scale(
                        scale: scale(1),
                        alignment: Alignment.topLeft,
                        child: SvgPicture.asset(
                          'assets/images/mother_calendar/story-mood-very-sad.svg',
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: scale(16)),
              Expanded(
                child: Text(
                  'Anda merasa sangat sedih',
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
          _AiSummary(scale: scale, story: story),
          SizedBox(height: scale(24)),
          _StoryText(
            scale: scale,
            story: story,
            isExpanded: isExpanded,
            onToggleExpanded: onToggleExpanded,
          ),
        ],
      ),
    );
  }
}

class _AiSummary extends StatelessWidget {
  const _AiSummary({required this.scale, required this.story});

  final double Function(double) scale;
  final String story;

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
            story,
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
    required this.story,
    required this.isExpanded,
    required this.onToggleExpanded,
  });

  final double Function(double) scale;
  final String story;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hal Kecil yang berarti',
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
