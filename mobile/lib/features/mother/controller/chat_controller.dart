import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/app_role.dart';
import '../../../services/authenticated_api.dart';
import '../../../services/backend_api.dart';
import '../../auth/controller/auth_controller.dart';
import '../models/chat_models.dart';

final chatControllerProvider = AsyncNotifierProvider<ChatController, ChatState>(
  ChatController.new,
);

/// Backend mengizinkan chat untuk ibu dan pendamping.
bool _canChat(AppRole? role) =>
    role == AppRole.mother || role == AppRole.companion;

class ChatController extends AsyncNotifier<ChatState> {
  @override
  Future<ChatState> build() async {
    final session = ref.watch(authControllerProvider).asData?.value.session;
    final userId = session?.user.id;
    final empty = ChatState(userId: userId);
    if (ref.watch(backendTokenProvider) == null ||
        session == null ||
        !_canChat(session.user.role)) {
      return empty;
    }
    try {
      return await _loadLatest(userId);
    } on Exception {
      // Riwayat hanya pelengkap: kalau gagal dimuat, tetap bisa mulai percakapan baru.
      return empty;
    }
  }

  /// Percakapan terakhir (sesi yang paling baru diperbarui) beserta pesannya.
  Future<ChatState> _loadLatest(String? userId) async {
    final api = ref.watch(authenticatedApiProvider);
    final sessions = (await api.getJson('/chat/sessions'))['sessions'];
    if (sessions is! List) {
      throw const FormatException('Chat session list has an invalid shape.');
    }
    if (sessions.isEmpty) return ChatState(userId: userId);

    final latest = sessions.first;
    if (latest is! Map<String, dynamic> || latest['id'] is! String) {
      throw const FormatException('Chat session has an invalid shape.');
    }
    final sessionId = latest['id'] as String;
    final items = (await api.getJson(
      '/chat/sessions/$sessionId/messages',
    ))['messages'];
    if (items is! List) {
      throw const FormatException('Chat messages have an invalid shape.');
    }
    final messages = <ChatMessage>[];
    for (final item in items) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Chat message has an invalid shape.');
      }
      messages.add(ChatMessage.fromJson(item));
    }
    return ChatState(userId: userId, sessionId: sessionId, messages: messages);
  }

  Future<bool> send(String message) async {
    final text = message.trim();
    // Selama riwayat masih dimuat (state belum punya nilai), pesan belum boleh dikirim.
    final loaded = state.asData?.value;
    if (text.isEmpty ||
        text.length > 2000 ||
        loaded == null ||
        loaded.isSending) {
      return false;
    }

    final auth = ref.read(authControllerProvider).asData?.value;
    final userId = auth?.session?.user.id;
    if (ref.read(backendTokenProvider) == null) {
      _setFailure('Mode pratinjau aktif. Pesan belum dikirim ke layanan AI.');
      return false;
    }
    if (userId == null) {
      _setFailure(
        'Sesi login tidak valid untuk percakapan. Silakan masuk kembali.',
      );
      return false;
    }

    if (!_canChat(auth?.session?.user.role)) {
      _setFailure('Fitur percakapan ini hanya untuk akun ibu dan pendamping.');
      return false;
    }

    final active = loaded.userId == userId ? loaded : ChatState(userId: userId);
    state = AsyncData(
      active.copyWith(
        isSending: true,
        urgent: false,
        contextUsed: const [],
        clearError: true,
      ),
    );

    try {
      final response = ChatResponse.fromJson(
        await ref
            .read(authenticatedApiProvider)
            .postJson(
              '/chat',
              body: {'message': text, 'session_id': active.sessionId},
            ),
      );
      state = AsyncData(
        active.copyWith(
          messages: [...active.messages, response.userMessage, response.reply],
          sessionId: response.sessionId,
          urgent: response.urgent,
          contextUsed: response.contextUsed,
          isSending: false,
          clearError: true,
        ),
      );
      return true;
    } on ApiConfigurationException catch (error) {
      _setFailure(error.message, previous: active);
    } on ApiNetworkException catch (error) {
      _setFailure(error.message, previous: active);
    } on BackendApiException catch (error) {
      if (error.statusCode == 404) {
        // Sesi lama sudah tidak ada: lupakan, pesan berikutnya membuka percakapan baru.
        _setFailure(
          'Percakapan sebelumnya tidak ditemukan. Kirim lagi untuk memulai '
          'percakapan baru.',
          previous: active.copyWith(clearSession: true),
        );
      } else {
        final message = switch (error.statusCode) {
          401 => 'Sesi login telah berakhir. Silakan masuk kembali.',
          403 => 'Akun ini tidak memiliki akses ke percakapan.',
          // 422, 429, 503, 500: pesan dari backend sudah ramah dan berbahasa Indonesia.
          _ => error.message,
        };
        _setFailure(message, previous: active);
      }
    } on ApiResponseFormatException catch (error) {
      _setFailure(
        'Respons percakapan tidak dapat dibaca: ${error.message}',
        previous: active,
      );
    } on FormatException catch (error) {
      _setFailure(
        'Respons percakapan tidak dapat dibaca: ${error.message}',
        previous: active,
      );
    }
    return false;
  }

  void _setFailure(String message, {ChatState? previous}) {
    final current = previous ?? state.requireValue;
    state = AsyncData(
      current.copyWith(
        isSending: false,
        errorMessage: message,
        clearUrgent: true,
      ),
    );
  }
}

class ChatState {
  const ChatState({
    this.userId,
    this.sessionId,
    this.messages = const [],
    this.contextUsed = const [],
    this.isSending = false,
    this.urgent = false,
    this.errorMessage,
  });

  final String? userId;
  final String? sessionId;
  final List<ChatMessage> messages;
  final List<String> contextUsed;
  final bool isSending;
  final bool urgent;
  final String? errorMessage;

  ChatState copyWith({
    List<ChatMessage>? messages,
    String? sessionId,
    List<String>? contextUsed,
    bool? isSending,
    bool? urgent,
    String? errorMessage,
    bool clearError = false,
    bool clearUrgent = false,
    bool clearSession = false,
  }) {
    return ChatState(
      userId: userId,
      sessionId: clearSession ? null : sessionId ?? this.sessionId,
      messages: messages ?? this.messages,
      contextUsed: contextUsed ?? this.contextUsed,
      isSending: isSending ?? this.isSending,
      urgent: clearUrgent ? false : urgent ?? this.urgent,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
