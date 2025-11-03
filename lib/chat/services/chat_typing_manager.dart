import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/ai_service.dart';
import '../chat_service.dart';
import '../chat_state.dart';
import '../../squad_state.dart';

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
    BuildContext context, {
    required String? chatGroupId,
    required ChatType chatType,
    required SquadState squadState,
  }) {
    // Cancel previous subscription to prevent memory leaks
    _typingSubscription?.cancel();

    final chatService = ChatService();
    _typingSubscription = chatService
        .getTypingUser(context, chatGroupId: chatGroupId, chatType: chatType)
        .listen((typingUser) {
      final myName = squadState.displayName;
      Provider.of<ChatState>(context, listen: false).setTypingUser(
        typingUser != null && typingUser != myName ? typingUser : null,
      );
    });
  }

  /// Update typing status when user starts typing
  Future<void> startTyping(
    BuildContext context, {
    required String? chatGroupId,
    required SquadState squadState,
  }) async {
    final chatService = ChatService();
    final displayName = squadState.displayName ?? 'Anonymous';

    // Cancel existing timer
    _typingTimer?.cancel();

    // Update typing status to active
    await chatService.updateTypingStatus(context, displayName, true,
        chatGroupId: chatGroupId);

    // Set timer to stop typing indicator after 3 seconds of inactivity
    _typingTimer = Timer(const Duration(seconds: 3), () async {
      await stopTyping(context,
          chatGroupId: chatGroupId, squadState: squadState);
    });
  }

  /// Update typing status when user stops typing
  Future<void> stopTyping(
    BuildContext context, {
    required String? chatGroupId,
    required SquadState squadState,
  }) async {
    final chatService = ChatService();
    final displayName = squadState.displayName ?? 'Anonymous';

    // Cancel timer
    _typingTimer?.cancel();

    // Update typing status to inactive
    await chatService.updateTypingStatus(context, displayName, false,
        chatGroupId: chatGroupId);
  }

  /// Handle text input changes to manage typing status
  void onTextChanged(
    String text,
    BuildContext context, {
    required String? chatGroupId,
    required SquadState squadState,
  }) {
    if (text.isNotEmpty) {
      startTyping(context, chatGroupId: chatGroupId, squadState: squadState);
    } else {
      stopTyping(context, chatGroupId: chatGroupId, squadState: squadState);
    }
  }

  /// Clear typing status when message is sent
  Future<void> onMessageSent(
    BuildContext context, {
    required String? chatGroupId,
    required SquadState squadState,
  }) async {
    await stopTyping(context, chatGroupId: chatGroupId, squadState: squadState);
  }
}
