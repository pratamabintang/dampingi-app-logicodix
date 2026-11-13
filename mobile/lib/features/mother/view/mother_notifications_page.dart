import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';

class MotherNotificationsPage extends StatelessWidget {
  const MotherNotificationsPage({super.key});

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
            final width = math.min(constraints.maxWidth, 390 * scale);
            double scaled(double value) => value * scale;

            return Center(
              child: SizedBox(
                width: width,
                child: ListView(
                  key: const Key('mother-notifications-scroll'),
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
                          key: const Key('mother-notifications-back'),
                          onPressed: () {
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.go('/mother');
                            }
                          },
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints.tightFor(
                            width: scaled(24),
                            height: scaled(24),
                          ),
                          icon: SvgPicture.asset(
                            'assets/images/mother_profile/notification-back.svg',
                            width: 24,
                            height: 24,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: scaled(36)),
                    Text(
                      'Notifikasi anda',
                      key: const Key('mother-notifications-title'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        color: AppTheme.ink,
                        fontSize: scaled(24),
                        fontWeight: FontWeight.w600,
                        height: 32 / 24,
                      ),
                    ),
                    SizedBox(height: scaled(36)),
                    _NotificationCard(
                      id: 'companion-invitation',
                      title: 'Sdr. Enzokulin Mengundang anda',
                      message: 'Anda diundang untuk didampingi Sdr. Enzokulin',
                      isUnread: true,
                      scale: scale,
                    ),
                    SizedBox(height: scaled(10)),
                    _NotificationCard(
                      id: 'professional-invitation',
                      title: 'Dr. Aisyah Salsabila Mengundang anda',
                      message: 'Anda diundang untuk didampingi Dr. Aisyah',
                      scale: scale,
                    ),
                    SizedBox(height: scaled(10)),
                    _NotificationCard(
                      id: 'wellness-tip',
                      title: 'Lakukan gerakan yoga ini supaya segar',
                      message: 'lorem ipsum dolor sit amet',
                      scale: scale,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.id,
    required this.title,
    required this.message,
    required this.scale,
    this.isUnread = false,
  });

  final String id;
  final String title;
  final String message;
  final double scale;
  final bool isUnread;

  @override
  Widget build(BuildContext context) {
    final titleColor = isUnread ? AppTheme.coralText : const Color(0xFF252B37);
    final messageColor = isUnread ? AppTheme.coralText : AppTheme.muted;

    return Container(
      key: Key('mother-notification-$id'),
      padding: EdgeInsets.all(20 * scale),
      decoration: BoxDecoration(
        color: isUnread ? AppTheme.selectedSurface : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(32 * scale),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    color: titleColor,
                    fontSize: 14 * scale,
                    fontWeight: FontWeight.w600,
                    height: 20 / 14,
                  ),
                ),
                SizedBox(height: 10 * scale),
                Text(
                  message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    color: messageColor,
                    fontSize: 16 * scale,
                    height: 24 / 16,
                  ),
                ),
              ],
            ),
          ),
          if (isUnread) ...[
            SizedBox(width: 16 * scale),
            SvgPicture.asset(
              'assets/images/mother_profile/notification-unread.svg',
              width: 16,
              height: 16,
            ),
          ],
        ],
      ),
    );
  }
}
