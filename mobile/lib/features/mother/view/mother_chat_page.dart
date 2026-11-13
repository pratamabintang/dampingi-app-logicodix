import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_brand_header.dart';
import '../../auth/controller/auth_controller.dart';
import '../controller/chat_controller.dart';
import '../models/chat_models.dart';
import 'mother_navigation.dart';

class MotherChatPage extends ConsumerStatefulWidget {
  const MotherChatPage({super.key});

  @override
  ConsumerState<MotherChatPage> createState() => _MotherChatPageState();
}

class _MotherChatPageState extends ConsumerState<MotherChatPage> {
  final _messageController = TextEditingController();

  static const _figmaPreviewMessages = [
    ChatMessage(role: 'user', content: 'Hai gpt, aku hamil'),
    ChatMessage(
      role: 'assistant',
      content: 'Wow kamu hamil ya semoga lahiranya lancar nanti',
    ),
  ];

  static const _figmaPreviewSummary =
      'Senang karena ada suami yang bantu aku untuk ke belakang, kok bisa '
      'suami bantu aku ke belakang padahal suami lagi di luar kota.';

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _messageController.text;
    final sent = await ref.read(chatControllerProvider.notifier).send(text);
    if (sent && mounted) {
      _messageController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatControllerProvider);
    final previewMode =
        ref
            .watch(authControllerProvider)
            .asData
            ?.value
            .session
            ?.accessToken
            .startsWith('mock-') ??
        false;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scale = (constraints.maxWidth / 390)
                .clamp(0.7, 1.15)
                .toDouble();
            double scaled(double value) => value * scale;
            final contentWidth = constraints.maxWidth < 390 * scale
                ? constraints.maxWidth
                : 390 * scale;

            return Center(
              child: SizedBox(
                width: contentWidth,
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        scaled(24),
                        scaled(20),
                        scaled(24),
                        0,
                      ),
                      child: const AppBrandHeader(),
                    ),
                    SizedBox(height: scaled(36)),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: scaled(24)),
                        child: Column(
                          children: [
                            Expanded(
                              child: chat.when(
                                loading: () => const SizedBox.shrink(),
                                error: (error, stackTrace) => Center(
                                  child: Text(
                                    'Percakapan belum dapat dibuka.',
                                    style: TextStyle(
                                      color: AppTheme.gray500,
                                      fontSize: scaled(16),
                                    ),
                                  ),
                                ),
                                data: (value) {
                                  final showDesignPreview =
                                      previewMode && value.messages.isEmpty;
                                  return _ConversationList(
                                    messages: showDesignPreview
                                        ? _figmaPreviewMessages
                                        : value.messages,
                                    summary: showDesignPreview
                                        ? _figmaPreviewSummary
                                        : null,
                                    contextUsed: value.contextUsed,
                                    urgent: value.urgent,
                                    isSending: value.isSending,
                                    scale: scale,
                                  );
                                },
                              ),
                            ),
                            if (chat.asData?.value.errorMessage
                                case final error?)
                              _ChatErrorBanner(message: error, scale: scale),
                            SizedBox(
                              key: const Key('mother-chat-composer'),
                              height: scaled(53),
                              child: _MessageComposer(
                                controller: _messageController,
                                scale: scale,
                                isSending:
                                    chat.asData?.value.isSending ?? false,
                                onSend: _send,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: scaled(24)),
                    MotherNavigationBar(
                      selectedTab: MotherNavigationTab.recommendations,
                      onHomeTap: () => context.go('/mother'),
                      onCalendarTap: () => context.go('/mother/calendar'),
                      onChatTap: () => context.go('/mother/chat'),
                      onMeditationTap: () => context.go('/mother/meditation'),
                      onProfileTap: () => context.go('/mother/profile'),
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

class _ConversationList extends StatelessWidget {
  const _ConversationList({
    required this.messages,
    required this.summary,
    required this.contextUsed,
    required this.urgent,
    required this.isSending,
    required this.scale,
  });

  final List<ChatMessage> messages;
  final String? summary;
  final List<String> contextUsed;
  final bool urgent;
  final bool isSending;
  final double scale;

  @override
  Widget build(BuildContext context) {
    double scaled(double value) => value * scale;
    final entries = [
      if (summary != null) _ChatSummaryCard(summary: summary!),
      if (urgent)
        const _ChatNotice(
          text: 'Percakapan ini menandai kondisi darurat. Hubungi layanan darurat setempat atau orang tepercaya sekarang.',
          urgent: true,
        ),
      if (contextUsed.contains('mood_7d'))
        const _ChatNotice(
          text: 'Konteks suasana hati 7 hari digunakan dalam respons ini.',
        ),
      if (isSending) const _TypingIndicator(),
      ...messages.reversed.map((message) => _MessageBubble(message: message)),
    ];

    return ListView.separated(
      key: const Key('mother-chat-messages'),
      reverse: true,
      padding: EdgeInsets.only(bottom: scaled(10)),
      itemCount: entries.length,
      separatorBuilder: (context, index) => SizedBox(height: scaled(10)),
      itemBuilder: (context, index) => entries[index],
    );
  }
}

class _ChatSummaryCard extends StatelessWidget {
  const _ChatSummaryCard({required this.summary});

  final String summary;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: 0.85,
        child: Container(
          key: const Key('mother-chat-summary'),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAFA),
            border: Border.all(color: const Color(0xFFF5F5F5)),
            borderRadius: BorderRadius.circular(32),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ringkasan Percakapan',
                style: TextStyle(
                  color: AppTheme.gray500,
                  fontSize: 16,
                  height: 24 / 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                summary,
                style: const TextStyle(
                  color: AppTheme.gray500,
                  fontSize: 16,
                  height: 24 / 16,
                  fontWeight: FontWeight.w400,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: 0.85,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isUser ? AppTheme.pink2 : const Color(0xFFFAFAFA),
            border: Border.all(
              color: isUser ? AppTheme.coralLight : const Color(0xFFF5F5F5),
            ),
            borderRadius: BorderRadius.circular(32),
          ),
          child: Text(
            message.content,
            style: TextStyle(
              color: isUser ? AppTheme.coralText : AppTheme.gray500,
              fontSize: 16,
              height: 24 / 16,
              fontWeight: FontWeight.w400,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppTheme.coral,
          ),
        ),
      ),
    );
  }
}

class _ChatNotice extends StatelessWidget {
  const _ChatNotice({required this.text, this.urgent = false});

  final String text;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: urgent ? const Color(0xFFFFF1F0) : AppTheme.pink2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: urgent ? AppTheme.coralText : AppTheme.coralLight,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: urgent ? const Color(0xFFB42318) : AppTheme.gray500,
          fontSize: 13,
          height: 18 / 13,
        ),
      ),
    );
  }
}

class _ChatErrorBanner extends StatelessWidget {
  const _ChatErrorBanner({required this.message, required this.scale});

  final String message;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8 * scale),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          message,
          style: TextStyle(
            color: const Color(0xFFB42318),
            fontSize: 13 * scale,
            height: 18 / 13,
          ),
        ),
      ),
    );
  }
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.scale,
    required this.isSending,
    required this.onSend,
  });

  final TextEditingController controller;
  final double scale;
  final bool isSending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    double scaled(double value) => value * scale;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(scaled(8)),
        boxShadow: AppTheme.inputShadow,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: scaled(14),
        vertical: scaled(7.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: scaled(36),
              child: TextField(
                key: const Key('mother-chat-input'),
                controller: controller,
                maxLength: 2000,
                maxLines: 1,
                textAlignVertical: TextAlignVertical.center,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: const InputDecoration(
                  hintText: 'Apakah saya depresi?',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  isCollapsed: true,
                  contentPadding: EdgeInsets.zero,
                  counterText: '',
                ),
                style: TextStyle(
                  color: AppTheme.body,
                  fontSize: scaled(16),
                  height: 24 / 16,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
            ),
          ),
          SizedBox(width: scaled(8)),
          Material(
            color: isSending ? AppTheme.muted : AppTheme.coral,
            borderRadius: BorderRadius.circular(scaled(8)),
            child: InkWell(
              key: const Key('mother-chat-send'),
              onTap: isSending ? null : onSend,
              borderRadius: BorderRadius.circular(scaled(8)),
              child: SizedBox(
                width: scaled(36),
                height: scaled(36),
                child: Center(
                  child: isSending
                      ? SizedBox(
                          width: scaled(18),
                          height: scaled(18),
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : SvgPicture.asset(
                          'assets/images/chat/send.svg',
                          width: scaled(20),
                          height: scaled(20),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
