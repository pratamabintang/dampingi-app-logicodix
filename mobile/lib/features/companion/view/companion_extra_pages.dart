import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_brand_header.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty.dart';
import '../../../core/widgets/app_profile_avatar.dart';
import '../../auth/controller/auth_controller.dart';
import '../../mother/controller/chat_controller.dart';
import '../../mother/models/chat_models.dart';
import '../../mother/view/mother_chat_page.dart';

class CompanionChatPage extends ConsumerStatefulWidget {
  const CompanionChatPage({required this.scale, super.key});

  final double scale;

  @override
  ConsumerState<CompanionChatPage> createState() => _CompanionChatPageState();
}

class _CompanionChatPageState extends ConsumerState<CompanionChatPage> {
  final _messageController = TextEditingController();

  static const _previewMessages = [
    ChatMessage(role: 'user', content: 'Hai gpt, aku hamil'),
    ChatMessage(
      role: 'assistant',
      content: 'Wow kamu hamil ya semoga lahiranya lancar nanti',
    ),
  ];

  static const _previewSummary =
      'Senang karena ada suami yang bantu aku untuk ke belakang, kok bisa '
      'suami bantu aku ke belakang padahal suami lagi di luar kota.';

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final sent = await ref
        .read(chatControllerProvider.notifier)
        .send(_messageController.text);
    if (sent && mounted) _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatControllerProvider);
    final previewMode = ref.watch(backendTokenProvider) == null;
    final scale = widget.scale;

    return Column(
      key: const Key('companion-chat-page'),
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(scale * 24, scale * 20, scale * 24, 0),
          child: const AppBrandHeader(),
        ),
        SizedBox(height: scale * 36),
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: scale * 24),
            child: ChatConversationPanel(
              chat: chat,
              previewMode: previewMode,
              previewMessages: _previewMessages,
              previewSummary: _previewSummary,
              controller: _messageController,
              scale: scale,
              keyPrefix: 'companion-chat',
              onSend: _send,
            ),
          ),
        ),
      ],
    );
  }
}

class CompanionNotificationsPage extends ConsumerStatefulWidget {
  const CompanionNotificationsPage({super.key});

  @override
  ConsumerState<CompanionNotificationsPage> createState() =>
      _CompanionNotificationsPageState();
}

/// Notifikasi pendamping. Sama seperti sisi ibu: layarnya tetap ada karena
/// desainnya masih berlanjut, tetapi saat aplikasi bicara dengan backend ia
/// tidak mengarang kabar. Mock desain hanya muncul di mode preview.
class _CompanionNotificationsPageState
    extends ConsumerState<CompanionNotificationsPage> {
  final Set<String> _openedNotifications = {};

  @override
  Widget build(BuildContext context) {
    final live = ref.watch(backendTokenProvider) != null;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scale = (constraints.maxWidth / 390)
                .clamp(0.7, 1.15)
                .toDouble();
            final width = constraints.maxWidth < 390 * scale
                ? constraints.maxWidth
                : 390 * scale;
            double scaled(double value) => value * scale;

            return Center(
              child: SizedBox(
                width: width,
                child: ListView(
                  key: const Key('companion-notifications-scroll'),
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
                          key: const Key('companion-notifications-back'),
                          onPressed: () {
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.go('/companion');
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
                      key: const Key('companion-notifications-title'),
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
                    if (live)
                      const AppEmpty(
                        key: Key('companion-notifications-empty'),
                        title: 'Belum ada notifikasi',
                        message: 'Belum ada kabar baru untuk Anda.',
                      )
                    else ...[
                      _CompanionNotificationCard(
                        id: 'journal',
                        title: 'Ibu membagikan catatan baru',
                        message: 'Catatan harian terbaru sudah tersedia',
                        scale: scale,
                        isUnread: !_openedNotifications.contains('journal'),
                        onTap: () => _markNotificationOpened('journal'),
                      ),
                      SizedBox(height: scaled(10)),
                      _CompanionNotificationCard(
                        id: 'observation',
                        title: 'Observasi harian telah diperbarui',
                        message: 'Lihat observasi terbaru tentang Ibu',
                        scale: scale,
                        isUnread: !_openedNotifications.contains('observation'),
                        onTap: () => _markNotificationOpened('observation'),
                      ),
                      SizedBox(height: scaled(10)),
                      _CompanionNotificationCard(
                        id: 'support',
                        title: 'Tips dukungan baru tersedia',
                        message: 'Temukan cara sederhana untuk membantu Ibu',
                        scale: scale,
                        isUnread: !_openedNotifications.contains('support'),
                        onTap: () => _markNotificationOpened('support'),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _markNotificationOpened(String id) {
    setState(() => _openedNotifications.add(id));
  }
}

class _CompanionNotificationCard extends StatelessWidget {
  const _CompanionNotificationCard({
    required this.id,
    required this.title,
    required this.message,
    required this.scale,
    required this.isUnread,
    required this.onTap,
  });

  final String id;
  final String title;
  final String message;
  final double scale;
  final bool isUnread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final titleColor = isUnread ? AppTheme.pink6 : AppTheme.white10;
    final messageColor = isUnread ? AppTheme.coralText : AppTheme.muted;

    return Container(
      key: Key('companion-notification-$id'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32 * scale),
      ),
      child: Material(
        color: isUnread ? AppTheme.selectedSurface : const Color(0xFFFAFAFA),
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

class CompanionSupportPage extends StatefulWidget {
  const CompanionSupportPage({
    required this.scale,
    required this.onAction,
    super.key,
  });

  final double scale;
  final ValueChanged<String> onAction;

  @override
  State<CompanionSupportPage> createState() => _CompanionSupportPageState();
}

class _CompanionSupportPageState extends State<CompanionSupportPage> {
  bool _showPrompt = false;

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;
    return ListView(
      key: const Key('companion-support-scroll'),
      padding: EdgeInsets.fromLTRB(
        scale * 24,
        scale * 20,
        scale * 24,
        scale * 24,
      ),
      children: [
        Text(
          'Dampingi',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.coralText,
            fontFamily: AppTheme.fontFamily,
            fontSize: scale * 24,
            fontWeight: FontWeight.w600,
            height: 32 / 24,
          ),
        ),
        SizedBox(height: scale * 48),
        AppCard(
          key: const Key('companion-support-screen'),
          padding: EdgeInsets.all(scale * 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dukungan hari ini',
                style: TextStyle(
                  color: AppTheme.ink,
                  fontFamily: AppTheme.fontFamily,
                  fontSize: scale * 16,
                  fontWeight: FontWeight.w600,
                  height: 24 / 16,
                ),
              ),
              SizedBox(height: scale * 32),
              InkWell(
                key: const Key('companion-support-prompt'),
                onTap: () => setState(() => _showPrompt = !_showPrompt),
                borderRadius: BorderRadius.circular(scale * 12),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: scale * 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mulai dari pertanyaan sederhana',
                        style: TextStyle(
                          color: AppTheme.ink,
                          fontFamily: AppTheme.fontFamily,
                          fontSize: scale * 16,
                          fontWeight: FontWeight.w600,
                          height: 24 / 16,
                        ),
                      ),
                      SizedBox(height: scale * 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              '“Apa yang paling kamu butuhkan hari ini?”',
                              style: TextStyle(
                                color: AppTheme.muted,
                                fontFamily: AppTheme.fontFamily,
                                fontSize: scale * 16,
                                height: 24 / 16,
                              ),
                            ),
                          ),
                          SizedBox(width: scale * 12),
                          Icon(
                            _showPrompt
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: AppTheme.coralText,
                            size: scale * 24,
                          ),
                        ],
                      ),
                      if (_showPrompt) ...[
                        SizedBox(height: scale * 12),
                        Text(
                          'Tanyakan dengan lembut, lalu beri waktu untuk bercerita.',
                          style: TextStyle(
                            color: AppTheme.body,
                            fontFamily: AppTheme.fontFamily,
                            fontSize: scale * 14,
                            height: 20 / 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SizedBox(height: scale * 16),
              Divider(height: scale, color: AppTheme.unselectedSurface),
              SizedBox(height: scale * 16),
              _CompanionSupportSuggestion(
                key: const Key('companion-support-concrete'),
                title: 'Bantu hal yang konkret',
                detail: 'Sepakati pembagian tugas dan...',
                onTap: () => widget.onAction('Bantu hal yang konkret'),
                scale: scale,
              ),
              SizedBox(height: scale * 16),
              Divider(height: scale, color: AppTheme.unselectedSurface),
              SizedBox(height: scale * 16),
              _CompanionSupportSuggestion(
                key: const Key('companion-support-listen'),
                title: 'Hargai ceritanya',
                detail: 'Dengarkan tanpa menghakimi d...',
                onTap: () => widget.onAction('Hargai ceritanya'),
                scale: scale,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompanionSupportSuggestion extends StatelessWidget {
  const _CompanionSupportSuggestion({
    required this.title,
    required this.detail,
    required this.onTap,
    required this.scale,
    super.key,
  });

  final String title;
  final String detail;
  final VoidCallback onTap;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(scale * 12),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: scale * 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: AppTheme.ink,
                      fontFamily: AppTheme.fontFamily,
                      fontSize: scale * 16,
                      fontWeight: FontWeight.w600,
                      height: 24 / 16,
                    ),
                  ),
                  SizedBox(height: scale * 12),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.muted,
                      fontFamily: AppTheme.fontFamily,
                      fontSize: scale * 16,
                      height: 24 / 16,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: scale * 12),
            Icon(
              Icons.chevron_right,
              color: AppTheme.coralText,
              size: scale * 24,
            ),
          ],
        ),
      ),
    );
  }
}

class CompanionProfilePage extends StatelessWidget {
  const CompanionProfilePage({
    required this.scale,
    required this.userName,
    required this.email,
    required this.hasMother,
    required this.onEdit,
    required this.onOpenConnections,
    required this.onLogout,
    this.motherName = '',
    super.key,
  });

  final double scale;
  final String userName;
  final String email;
  final bool hasMother;
  final String motherName;
  final VoidCallback onEdit;
  final VoidCallback onOpenConnections;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final scale = this.scale;
    return ListView(
      key: const Key('companion-profile-scroll'),
      padding: EdgeInsets.fromLTRB(
        scale * 24,
        scale * 20,
        scale * 24,
        scale * 24,
      ),
      children: [
        Text(
          'Dampingi',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.coralText,
            fontFamily: AppTheme.fontFamily,
            fontSize: scale * 24,
            fontWeight: FontWeight.w600,
            height: 32 / 24,
          ),
        ),
        SizedBox(height: scale * 48),
        AppCard(
          key: const Key('companion-profile-card'),
          padding: EdgeInsets.all(scale * 24),
          child: Column(
            children: [
              AppProfileAvatar(
                key: const Key('companion-profile-avatar'),
                assetPath: 'assets/images/companion_profile/profile-avatar.png',
                size: scale * 85,
                semanticLabel: 'Foto profil $userName',
              ),
              SizedBox(height: scale * 16),
              Text(
                userName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.ink,
                  fontFamily: AppTheme.fontFamily,
                  fontSize: scale * 20,
                  fontWeight: FontWeight.w600,
                  height: 30 / 20,
                ),
              ),
              SizedBox(height: scale * 4),
              Text(
                email,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.muted,
                  fontFamily: AppTheme.fontFamily,
                  fontSize: scale * 16,
                  height: 24 / 16,
                ),
              ),
              SizedBox(height: scale * 24),
              _CompanionProfileButton(
                key: const Key('companion-profile-edit'),
                label: 'Ubah Profil',
                scale: scale,
                onPressed: onEdit,
              ),
              SizedBox(height: scale * 10),
              _CompanionProfileButton(
                key: const Key('companion-profile-enter-code'),
                label: 'Masukkan Kode Undangan',
                scale: scale,
                onPressed: onOpenConnections,
                secondary: true,
              ),
            ],
          ),
        ),
        if (hasMother) ...[
          SizedBox(height: scale * 24),
          AppCard(
            key: const Key('companion-profile-mother-card'),
            padding: EdgeInsets.all(scale * 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ibu yang anda dampingi',
                  style: TextStyle(
                    color: AppTheme.ink,
                    fontFamily: AppTheme.fontFamily,
                    fontSize: scale * 16,
                    fontWeight: FontWeight.w600,
                    height: 24 / 16,
                  ),
                ),
                SizedBox(height: scale * 24),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: scale * 12),
                  child: Container(
                    padding: EdgeInsets.all(scale * 8),
                    decoration: BoxDecoration(
                      color: AppTheme.pink1,
                      borderRadius: BorderRadius.circular(scale * 32),
                    ),
                    child: Row(
                      children: [
                        ClipOval(
                          child: Image.asset(
                            'assets/images/mother_home/avatar-a.png',
                            width: scale * 56,
                            height: scale * 56,
                            fit: BoxFit.cover,
                            semanticLabel: 'Foto $motherName',
                          ),
                        ),
                        SizedBox(width: scale * 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                motherName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppTheme.coralText,
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: scale * 16,
                                  fontWeight: FontWeight.w600,
                                  height: 24 / 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        SizedBox(height: scale * 32),
        _CompanionProfileButton(
          key: const Key('companion-profile-logout'),
          label: 'Keluar',
          scale: scale,
          onPressed: onLogout,
        ),
      ],
    );
  }
}

class _CompanionProfileButton extends StatelessWidget {
  const _CompanionProfileButton({
    required this.label,
    required this.scale,
    required this.onPressed,
    this.secondary = false,
    super.key,
  });

  final String label;
  final double scale;
  final VoidCallback onPressed;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: scale * 48,
      child: FilledButton(
        onPressed: onPressed,
        style: AppButtonStyles.forType(
          secondary ? AppButtonType.secondary : AppButtonType.primary,
        ).merge(
          FilledButton.styleFrom(
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(scale * 8),
            ),
            textStyle: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: scale * 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        child: Text(label),
      ),
    );
  }
}
