import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../mother/models/mother_story.dart';

class DoctorPatientStoryPage extends StatefulWidget {
  const DoctorPatientStoryPage({required this.story, super.key});

  final MotherStory story;

  @override
  State<DoctorPatientStoryPage> createState() => _DoctorPatientStoryPageState();
}

class _DoctorPatientStoryPageState extends State<DoctorPatientStoryPage> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final story = widget.story;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scale = (constraints.maxWidth / 390)
                .clamp(0.7, 1.15)
                .toDouble();
            double scaled(double value) => value * scale;
            final width = constraints.maxWidth < 390 * scale
                ? constraints.maxWidth
                : 390 * scale;

            return Center(
              child: SizedBox(
                width: width,
                child: DefaultTextStyle(
                  style: const TextStyle(fontFamily: AppTheme.fontFamily),
                  child: ListView(
                    key: const Key('doctor-patient-story-scroll'),
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
                            key: const Key('doctor-patient-story-back'),
                            onPressed: () => Navigator.of(context).maybePop(),
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
                      _PatientStoryCard(
                        story: story,
                        scale: scaled,
                        isExpanded: _isExpanded,
                        onToggleExpanded: () =>
                            setState(() => _isExpanded = !_isExpanded),
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

class _PatientStoryCard extends StatelessWidget {
  const _PatientStoryCard({
    required this.story,
    required this.scale,
    required this.isExpanded,
    required this.onToggleExpanded,
  });

  final MotherStory story;
  final double Function(double) scale;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: const Key('doctor-patient-story-card'),
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
              key: const Key('doctor-patient-story-date'),
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
          _AiSummary(summary: story.summary, scale: scale),
          SizedBox(height: scale(24)),
          Text(
            story.title,
            key: const Key('doctor-patient-story-title'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xFF252B37),
              fontSize: scale(14),
              fontWeight: FontWeight.w600,
              height: 20 / 14,
            ),
          ),
          SizedBox(height: scale(10)),
          Text(
            story.note,
            key: const Key('doctor-patient-story-preview'),
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
            height: scale(40),
            child: TextButton(
              key: const Key('doctor-patient-story-expand'),
              onPressed: onToggleExpanded,
              style: TextButton.styleFrom(
                backgroundColor: AppTheme.coralLight,
                foregroundColor: AppTheme.coralText,
                padding: EdgeInsets.symmetric(vertical: scale(4)),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
      ),
    );
  }
}

class _AiSummary extends StatelessWidget {
  const _AiSummary({required this.summary, required this.scale});

  final String summary;
  final double Function(double) scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('doctor-patient-story-ai-summary'),
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
            key: const Key('doctor-patient-story-ai-summary-text'),
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
