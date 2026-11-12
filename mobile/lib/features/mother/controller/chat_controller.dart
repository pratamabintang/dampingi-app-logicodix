import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/backend_api.dart';
import '../../auth/controller/auth_controller.dart';
import '../models/chat_models.dart';

final chatControllerProvider =
    AsyncNotifierProvider<ChatController, ChatState>(ChatController.new);

class ChatController extends AsyncNotifier<ChatState> {
  @override
  ChatState build() {
    final auth = ref.watch(authControllerProvider).asData?.value;
    return ChatState(userId: auth?.session?.user.id);
  }

  Future<bool> send(String message) async {
    final text = message.trim();
    if (text.isEmpty || text.length > 2000 || state.requireValue.isSending) {
      return false;
    }

    final auth = ref.read(authControllerProvider).asData?.value;
    final token = auth?.session?.accessToken;
    final userId = auth?.session?.user.id;
    if (token?.startsWith('mock-') ?? false) {
      _setFailure(
        'Mode pratinjau aktif. Pesan belum dikirim ke layanan AI.',
      );
      return false;
    }
    if (token == null || userId == null) {
      _setFailure(
        'Sesi login tidak valid untuk percakapan. Silakan masuk kembali.',
      );
      return false;
    }

    if (auth?.session?.user.role?.value != 'mother') {
      _setFailure('Fitur percakapan ini hanya tersedia untuk akun ibu.');
      return false;
    }

    final current = state.requireValue;
    final active = current.userId == userId
        ? current
        : ChatState(userId: userId);
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
            .read(backendApiProvider)
            .postJson(
              '/chat',
              body: {'message': text, 'session_id': active.sessionId},
              accessToken: token,
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
      final message = switch (error.statusCode) {
        401 => 'Sesi login telah berakhir. Silakan masuk kembali.',
        403 => 'Akun ini tidak memiliki akses ke percakapan.',
        404 => 'Percakapan tidak ditemukan. Mulai pesan baru.',
        422 => error.message,
        429 => 'Pesan belum dapat diproses. Tunggu sebentar lalu coba lagi.',
        503 => 'Layanan percakapan sedang tidak tersedia. Coba lagi nanti.',
        _ => error.message,
      };
      _setFailure(message, previous: active);
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
  }) {
    return ChatState(
      userId: userId,
      sessionId: sessionId ?? this.sessionId,
      messages: messages ?? this.messages,
      contextUsed: contextUsed ?? this.contextUsed,
      isSending: isSending ?? this.isSending,
      urgent: clearUrgent ? false : urgent ?? this.urgent,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
