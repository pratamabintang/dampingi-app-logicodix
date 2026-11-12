class ChatMessage {
  const ChatMessage({required this.role, required this.content});

  final String role;
  final String content;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final role = json['role'];
    final content = json['content'];
    if ((role != 'user' && role != 'assistant') ||
        content is! String ||
        content.isEmpty) {
      throw const FormatException('Chat message has an invalid role or content.');
    }
    return ChatMessage(role: role as String, content: content);
  }
}

class ChatResponse {
  const ChatResponse({
    required this.sessionId,
    required this.userMessage,
    required this.reply,
    required this.urgent,
    required this.contextUsed,
  });

  final String sessionId;
  final ChatMessage userMessage;
  final ChatMessage reply;
  final bool urgent;
  final List<String> contextUsed;

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    final sessionId = json['session_id'];
    final userMessage = json['user_message'];
    final reply = json['reply'];
    final urgent = json['urgent'];
    final contextUsed = json['context_used'];
    if (sessionId is! String ||
        userMessage is! Map<String, dynamic> ||
        reply is! Map<String, dynamic> ||
        urgent is! bool ||
        contextUsed is! List<dynamic> ||
        contextUsed.any((item) => item is! String)) {
      throw const FormatException('Chat response has an invalid shape.');
    }

    final parsedUserMessage = ChatMessage.fromJson(userMessage);
    final parsedReply = ChatMessage.fromJson(reply);
    if (parsedUserMessage.role != 'user' || parsedReply.role != 'assistant') {
      throw const FormatException('Chat response returned messages in the wrong roles.');
    }
    return ChatResponse(
      sessionId: sessionId,
      userMessage: parsedUserMessage,
      reply: parsedReply,
      urgent: urgent,
      contextUsed: List<String>.unmodifiable(contextUsed.cast<String>()),
    );
  }
}
