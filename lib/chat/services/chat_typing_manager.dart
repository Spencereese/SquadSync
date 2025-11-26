import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as p;
import '../../domain/entities/message.dart';
import '../chat_service.dart';
import '../chat_state.dart';
import '../../squad_state_notifier.dart';

/// Service responsible for managing typing indicators and status updates
class ChatTypingManager {
  StreamSubscription<String?>? _typingSubscription;
  Timer? _typingTimer;

  /// Dispose of resources
  void dispose() {
    _typingSubscription?.cancel();
    _typingTimer?.cancel();
  }

  /// Initialize typing listener for the current chat
  void initializeTypingListener(
    WidgetRef ref, {
    String? chatGroupId,
    required ChatType chatType,
    SquadState? squadState,
  }) {
    // Cancel previous subscription to prevent memory leaks
    _typingSubscription?.cancel();

    final chatService = ChatService();
    _typingSubscription = chatService
        .getTypingUser(ref, chatGroupId: chatGroupId, chatType: chatType)
        .listen((typingUser) {
      final myName = squadState?.displayName ?? '';
      p.Provider.of<ChatState>(ref.context, listen: false).setTypingUser(
        typingUser != null && typingUser != myName ? typingUser : null,
      );
    });
  }

  /// Update typing status when user starts typing
  Future<void> startTyping(
    WidgetRef ref, {
    required String? chatGroupId,
    SquadState? squadState,
  }) async {
    final chatService = ChatService();
    final displayName = squadState?.displayName ?? '';

    // Cancel existing timer
    _typingTimer?.cancel();

    // Update typing status to active
    await chatService.updateTypingStatus(ref, displayName, true,
        chatGroupId: chatGroupId);

    // Set timer to stop typing indicator after 3 seconds of inactivity
    _typingTimer = Timer(const Duration(seconds: 3), () async {
      await stopTyping(ref, chatGroupId: chatGroupId, squadState: squadState);
    });
  }

  /// Update typing status when user stops typing
  Future<void> stopTyping(
    WidgetRef ref, {
    required String? chatGroupId,
    SquadState? squadState,
  }) async {
    final chatService = ChatService();
    final displayName = squadState?.displayName ?? '';

    // Cancel timer
    _typingTimer?.cancel();

    // Update typing status to inactive
    await chatService.updateTypingStatus(ref, displayName, false,
        chatGroupId: chatGroupId);
  }

  /// Handle text input changes to manage typing status
  void onTextChanged(
    String text,
    WidgetRef ref, {
    required String? chatGroupId,
    SquadState? squadState,
  }) {
    if (text.isNotEmpty) {
      startTyping(ref, chatGroupId: chatGroupId, squadState: squadState);
    } else {
      stopTyping(ref, chatGroupId: chatGroupId, squadState: squadState);
    }
  }

  /// Clear typing status when message is sent
  Future<void> onMessageSent(
    WidgetRef ref, {
    required String? chatGroupId,
    SquadState? squadState,
  }) async {
    await stopTyping(ref, chatGroupId: chatGroupId, squadState: squadState);
  }
}
