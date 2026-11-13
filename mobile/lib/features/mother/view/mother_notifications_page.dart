import 'dart:ui' show ImageFilter;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_submit_button.dart';

class MotherNotificationsPage extends StatefulWidget {
  const MotherNotificationsPage({super.key});

  @override
  State<MotherNotificationsPage> createState() =>
      _MotherNotificationsPageState();
}

class _MotherNotificationsPageState extends State<MotherNotificationsPage> {
  bool _invitationOpened = false;

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
                      isHighlighted: !_invitationOpened,
                      scale: scale,
                      onTap: _openInvitation,
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

  Future<void> _openInvitation() async {
    setState(() => _invitationOpened = true);
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Tutup konfirmasi undangan',
      barrierColor: Colors.transparent,
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final screenWidth = MediaQuery.sizeOf(dialogContext).width;
        final scaleFactor = (screenWidth / 390).clamp(0.7, 1.15).toDouble();
        double scale(double value) => value * scaleFactor;
        final width = math.min(scale(342), screenWidth - scale(40));

        return Material(
          type: MaterialType.transparency,
          child: Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                onTap: () => Navigator.of(dialogContext).pop(),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
                  child: const ColoredBox(color: Color(0x1A000000)),
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(vertical: scale(24)),
                  child: Transform.translate(
                    offset: Offset(scale(4), scale(-0.5)),
                    child: SizedBox(
                      width: width,
                      child: _InvitationConfirmationDialog(
                        scale: scale,
                        onClose: () => Navigator.of(dialogContext).pop(),
                        onAccept: () {
                          Navigator.of(dialogContext).pop();
                          _showUnavailableNotice(
                            'Persetujuan undangan belum tersedia.',
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 180),
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
    );
  }

  void _showUnavailableNotice(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.id,
    required this.title,
    required this.message,
    required this.scale,
    this.isUnread = false,
    this.isHighlighted = false,
    this.onTap,
  });

  final String id;
  final String title;
  final String message;
  final double scale;
  final bool isUnread;
  final bool isHighlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final titleColor = isHighlighted
        ? AppTheme.coralText
        : const Color(0xFF252B37);
    final messageColor = isHighlighted ? AppTheme.coralText : AppTheme.muted;

    return Container(
      key: Key('mother-notification-$id'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32 * scale),
      ),
      child: Material(
        color: isHighlighted
            ? AppTheme.selectedSurface
            : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(32 * scale),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(32 * scale),
          child: Padding(
            padding: EdgeInsets.all(20 * scale),
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
          ),
        ),
      ),
    );
  }
}

class _InvitationConfirmationDialog extends StatelessWidget {
  const _InvitationConfirmationDialog({
    required this.scale,
    required this.onClose,
    required this.onAccept,
  });

  final double Function(double) scale;
  final VoidCallback onClose;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('mother-notification-confirm-dialog'),
      padding: EdgeInsets.all(scale(20)),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFFAFAFA)),
        borderRadius: BorderRadius.circular(scale(32)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A0A0D12),
            offset: Offset(0, 1),
            blurRadius: 3,
          ),
          BoxShadow(
            color: Color(0x0F0A0D12),
            offset: Offset(0, 1),
            blurRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: scale(24),
              height: scale(24),
              child: IconButton(
                key: const Key('mother-notification-confirm-close'),
                onPressed: onClose,
                tooltip: 'Tutup',
                padding: EdgeInsets.zero,
                constraints: BoxConstraints.tightFor(
                  width: scale(24),
                  height: scale(24),
                ),
                icon: SvgPicture.asset(
                  'assets/images/mother_home/close.svg',
                  width: scale(24),
                  height: scale(24),
                ),
              ),
            ),
          ),
          SizedBox(height: scale(24)),
          Semantics(
            label: 'Apakah anda menyetujui undangan pendampingan dari pengguna ini?',
            child: SizedBox(
              key: const Key('mother-notification-confirm-title'),
              width: double.infinity,
              child: Column(
                children: [
                  _ConfirmationTitleLine(
                    text: 'Apakah anda menyetujui undangan',
                    scale: scale,
                  ),
                  _ConfirmationTitleLine(
                    text: 'pendampingan dari pengguna ini?',
                    scale: scale,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: scale(24)),
          Container(
            key: const Key('mother-notification-inviter-profile'),
            height: scale(72),
            padding: EdgeInsets.all(scale(8)),
            decoration: BoxDecoration(
              color: AppTheme.selectedSurface,
              borderRadius: BorderRadius.circular(scale(24)),
            ),
            child: Row(
              children: [
                ClipOval(
                  child: Image.asset(
                    'assets/images/mother_profile/man-1.png',
                    width: scale(56),
                    height: scale(56),
                    fit: BoxFit.cover,
                  ),
                ),
                SizedBox(width: scale(16)),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tn. Enzokulin Samsidan',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          color: AppTheme.coralText,
                          fontSize: scale(16),
                          fontWeight: FontWeight.w600,
                          height: 24 / 16,
                        ),
                      ),
                      Text(
                        'samsidan@gmail.com',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          color: AppTheme.muted,
                          fontSize: scale(16),
                          height: 24 / 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: scale(24)),
          Column(
            children: [
              _InvitationDialogButton(
                key: const Key('mother-notification-confirm-accept'),
                label: 'Ya',
                scale: scale,
                onPressed: onAccept,
              ),
              SizedBox(height: scale(10)),
              _InvitationDialogButton(
                key: const Key('mother-notification-confirm-cancel'),
                label: 'Kembali',
                scale: scale,
                onPressed: onClose,
                secondary: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConfirmationTitleLine extends StatelessWidget {
  const _ConfirmationTitleLine({required this.text, required this.scale});

  final String text;
  final double Function(double) scale;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: scale(24),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            color: AppTheme.coralText,
            fontSize: scale(16),
            fontWeight: FontWeight.w600,
            height: 24 / 16,
          ),
        ),
      ),
    );
  }
}

class _InvitationDialogButton extends StatelessWidget {
  const _InvitationDialogButton({
    required this.label,
    required this.scale,
    required this.onPressed,
    this.secondary = false,
    super.key,
  });

  final String label;
  final double Function(double) scale;
  final VoidCallback onPressed;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: scale(48),
      child: AppSubmitButton(
        label: label,
        onPressed: onPressed,
        textStyle: TextStyle(
          fontFamily: AppTheme.fontFamily,
          color: secondary ? AppTheme.coralText : Colors.white,
          fontSize: scale(16),
          fontWeight: FontWeight.w600,
          height: 24 / 16,
        ),
        buttonStyle: FilledButton.styleFrom(
          backgroundColor: secondary ? AppTheme.coralLight : AppTheme.coral,
          foregroundColor: secondary ? AppTheme.coralText : Colors.white,
          padding: EdgeInsets.symmetric(
            horizontal: scale(20),
            vertical: scale(12),
          ),
          elevation: 1,
          shadowColor: const Color(0x0D101828),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(scale(8)),
          ),
        ),
      ),
    );
  }
}
