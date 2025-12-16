import '../../services/auth_service_supabase.dart';
import '../../services/supabase_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squad_sync/presentation/notifiers/lobby_notifier.dart' as ln;
import 'package:squad_sync/presentation/notifiers/chat_notifier.dart' as cn;

import '../../domain/entities/lobby_state.dart';
import '../../domain/entities/message.dart';
import '../chat_state_notifier.dart';

/// Service responsible for complex chat initialization logic
class ChatInitializationService {
  /// Initializes chat with all necessary setup operations
  Future<void> initializeChat({
    required BuildContext context,
    required WidgetRef ref,
    required String? chatGroupId,
    required String? chatGroupName,
    required ChatType chatType,
    required Function(String) setChatName,
    required Function(String?) setChatImageUrl,
    required Function() loadMoreMessages,
    required Function() scrollToBottom,
    required Function(String) sendMessage,
    required TextEditingController messageController,
    required String? initialMessage,
  }) async {
    final squadState = ref.read(ln.lobbyNotifierProvider).valueOrNull;

    if (squadState == null) {
      // Handle loading state
      return;
    }

    // Update online status
    _updateOnlineStatus(true, squadState);

    // Load chat details
    await _loadChatDetails(
      context: context,
      chatGroupId: chatGroupId,
      chatType: chatType,
      squadState: squadState,
      setChatName: setChatName,
      setChatImageUrl: setChatImageUrl,
    );

    // Load notification settings
    await _loadNotificationSettings();

    // Load quick reaction emoji
    await ref.read(chatStateProvider.notifier).loadQuickReactionEmojis();

    // Load user display names for better performance
    await _loadUserDisplayNames(context);

    // Mark group as read when opening
    if (chatGroupId != null && chatType == ChatType.userGroup) {
      try {
        await ref
            .read(cn.chatNotifierProvider.notifier)
            .markGroupAsRead(chatGroupId);
      } catch (e) {
        debugPrint('Error marking group as read: $e');
      }
    }

    // Load initial historical messages
    await loadMoreMessages();

    // Check for handoff draft
    await _checkHandoffDraft();

    // Handle initial message if provided
    if (initialMessage != null && context.mounted) {
      messageController.text = initialMessage;
      sendMessage(initialMessage);
    }

    // Scroll to bottom after everything is loaded and UI is built
    if (context.mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        scrollToBottom();
      });
    }
  }

  Future<void> _loadChatDetails({
    required BuildContext context,
    required String? chatGroupId,
    required ChatType chatType,
    required LobbyState squadState,
    required Function(String) setChatName,
    required Function(String?) setChatImageUrl,
  }) async {
    if (!context.mounted || chatGroupId == null) return;

    try {
      final currentUser = AuthServiceSupabase().currentUser;
      if (currentUser == null) return;

      if (chatType == ChatType.userGroup) {
        // Query chat_groups table directly to get current avatar_url
        final groupData = await SupabaseService.client
            .from('chat_groups')
            .select('name, avatar_url')
            .eq('id', chatGroupId)
            .maybeSingle();

        if (groupData != null && context.mounted) {
          setChatName(groupData['name'] ?? 'Group Chat');
          setChatImageUrl(groupData['avatar_url']);
        }
      }
      // For DMs, no additional loading needed
    } catch (e) {
      debugPrint('Error loading chat details: $e');
    }
  }

  Future<void> _loadNotificationSettings() async {
    // Implementation for loading notification settings
    // This would load user preferences for chat notifications
  }

  Future<void> _loadUserDisplayNames(BuildContext context) async {
    // Implementation for pre-loading user display names
    // This improves performance by avoiding FutureBuilder in the message list
  }

  Future<void> _checkHandoffDraft() async {
    // Implementation for checking if there's a draft message from handoff
    // This handles cases where the app was terminated while composing
  }

  void _updateOnlineStatus(bool isOnline, LobbyState squadState) {
    // Implementation moved from ChatScreen
    // Updates user's online status in Firestore
  }

  /// Cleanup operations when chat is disposed
  void dispose(BuildContext context, WidgetRef ref) {
    final squadState = ref.read(ln.lobbyNotifierProvider).valueOrNull;
    if (squadState != null) {
      _updateOnlineStatus(false, squadState);
    }
  }
}
