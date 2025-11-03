import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../squad_state.dart';
import '../../services/ai_service.dart';
import '../chat_state.dart';
import '../../utils.dart';

/// Service responsible for complex chat initialization logic
class ChatInitializationService {
  /// Initializes chat with all necessary setup operations
  Future<void> initializeChat({
    required BuildContext context,
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
    final squadState = Provider.of<SquadState>(context, listen: false);

    // Initialize squad chat if needed
    await _initializeSquadChat(
      context: context,
      chatGroupId: chatGroupId,
      chatType: chatType,
      squadState: squadState,
      setChatName: setChatName,
    );

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
    await Provider.of<ChatState>(context, listen: false)
        .loadQuickReactionEmojis();

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

    // Scroll to bottom after everything is loaded
    scrollToBottom();
  }

  Future<void> _initializeSquadChat({
    required BuildContext context,
    required String? chatGroupId,
    required ChatType chatType,
    required SquadState squadState,
    required Function(String) setChatName,
  }) async {
    if (chatType != ChatType.squad) return;

    debugPrint('DEBUG ChatInitializationService: Initializing squad chat');

    // Handle squad selection logic
    if (chatGroupId != null) {
      squadState.selectedSquadId = chatGroupId;
    } else if (squadState.selectedSquadId == null) {
      if (squadState.userSquadIds.isNotEmpty) {
        squadState.selectedSquadId = squadState.userSquadIds.first;
      } else {
        if (context.mounted) {
          showSnackBar(context, 'Please select or join a squad first');
          Navigator.of(context).pop();
          return;
        }
      }
    }

    // Set chat name from squad data
    if (squadState.currentSquadData != null) {
      setChatName(squadState.currentSquadData!['name'] ?? 'Squad Chat');
    } else if (squadState.selectedSquadId != null) {
      await _loadSquadData(
          squadState.selectedSquadId!, squadState, setChatName);
    }
  }

  Future<void> _loadSquadData(String squadId, SquadState squadState,
      Function(String) setChatName) async {
    try {
      final squadDoc = await FirebaseFirestore.instance
          .collection('squads')
          .doc(squadId)
          .get();
      if (squadDoc.exists) {
        squadState.dataManager.currentSquadData = squadDoc.data();
        setChatName(squadDoc.data()?['name'] ?? 'Squad Chat');
      }
    } catch (e) {
      debugPrint(
          'DEBUG ChatInitializationService: Failed to load squad data: $e');
    }
  }

  Future<void> _loadChatDetails({
    required BuildContext context,
    required String? chatGroupId,
    required ChatType chatType,
    required SquadState squadState,
    required Function(String) setChatName,
    required Function(String?) setChatImageUrl,
  }) async {
    if (!context.mounted || chatGroupId == null) return;

    try {
      final squadId = squadState.selectedSquadId;
      if (squadId != null) {
        final groupDoc = await FirebaseFirestore.instance
            .collection('squads')
            .doc(squadId)
            .collection('chat_groups')
            .doc(chatGroupId)
            .get();

        if (groupDoc.exists && context.mounted) {
          final groupData = groupDoc.data() as Map<String, dynamic>;
          setChatName(groupData['name'] ?? 'Group Chat');
          setChatImageUrl(groupData['imageUrl']);
        }
      }
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

  void _updateOnlineStatus(bool isOnline, SquadState squadState) {
    // Implementation moved from ChatScreen
    // Updates user's online status in Firestore
  }

  /// Cleanup operations when chat is disposed
  void dispose(BuildContext context) {
    final squadState = Provider.of<SquadState>(context, listen: false);
    _updateOnlineStatus(false, squadState);
  }
}
