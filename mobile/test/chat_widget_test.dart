import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/mother/controller/chat_controller.dart';
import 'package:mobile/features/mother/models/chat_models.dart';
import 'package:mobile/features/mother/view/mother_chat_page.dart';

void main() {
  testWidgets(
    'chat has one send loader, a 16px gap, and content-sized bubbles',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = TextEditingController();
      addTearDown(controller.dispose);
      const longMessage =
          'Pesan yang panjang membungkus beberapa baris dan mengisi lebar '
          'maksimum gelembung percakapan.';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ChatConversationPanel(
                chat: const AsyncValue.data(
                  ChatState(
                    isSending: true,
                    messages: [
                      ChatMessage(role: 'user', content: 'Hai'),
                      ChatMessage(role: 'assistant', content: longMessage),
                    ],
                  ),
                ),
                previewMode: false,
                previewMessages: const [],
                previewSummary: '',
                controller: controller,
                scale: 1,
                keyPrefix: 'chat-test',
                onSend: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('chat-test-send')),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(
        tester.getSize(find.byKey(const Key('chat-test-message-gap-0'))).height,
        16,
      );

      final shortBubble = find
          .ancestor(of: find.text('Hai'), matching: find.byType(Container))
          .first;
      final longBubble = find
          .ancestor(
            of: find.text(longMessage),
            matching: find.byType(Container),
          )
          .first;
      expect(
        tester.getSize(shortBubble).width,
        lessThan(tester.getSize(longBubble).width),
      );
    },
  );
}
