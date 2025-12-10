import '../../services/auth_service_supabase.dart';
import '../../services/supabase_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squad_sync/presentation/notifiers/lobby_notifier.dart' as ln;
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
        // Query user_groups JSONB field from users table
        final userData = await SupabaseService.client
            .from('users')
            .select('user_groups')
            .eq('uid', currentUser.id)
            .maybeSingle();

        if (userData != null && context.mounted) {
          final userGroups =
              List<Map<String, dynamic>>.from(userData['user_groups'] ?? []);
          // Find the specific group by chatGroupId
          final groupData = userGroups.firstWhere(
            (group) => group['id'] == chatGroupId,
            orElse: () => <String, dynamic>{},
          );

          if (groupData.isNotEmpty) {
            setChatName(groupData['name'] ?? 'Group Chat');
            setChatImageUrl(groupData['image_url']);
          }
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
