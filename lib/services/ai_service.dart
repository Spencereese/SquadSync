import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../squad_state.dart';
import '../services/grok_service.dart';
import '../chat/sqlite_helper.dart';

/// Service responsible for AI/Grok integration in chat functionality.
/// Handles AI response generation, context gathering, and message processing.
class AiService {
  final GrokService _grokService = GrokService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SQLiteHelper _sqliteHelper = SQLiteHelper();

  /// Generate AI response from Grok for messages directed at it
  Future<void> generateGrokResponse(BuildContext context, String userMessage,
      String senderUid, String? squadId, String? chatGroupId,
      {required ChatType chatType}) async {
    try {
      // Clean the message by removing Grok mentions
      final cleanMessage = _grokService.cleanGrokMessage(userMessage);

      // Get context about the current squad/game
      final squadState = Provider.of<SquadState>(context, listen: false);
      final currentGame = squadState.currentGame;
      final gameContext = currentGame != null
          ? 'Currently playing: ${currentGame['name']} (${currentGame['genres']?.join(', ') ?? 'Unknown genre'})'
          : 'No specific game selected';

      // Get recent messages for context (last 5 messages)
      final recentMessages = await _getRecentMessages(squadId, chatGroupId,
          limit: 5, chatType: chatType, userId: senderUid);

      // Generate Grok response
      final grokResponse = await _grokService.getGrokResponse(
        cleanMessage,
        context: gameContext,
        recentMessages: recentMessages,
      );

      // Create Grok's response message
      final grokMsgId = Uuid().v4();
      final timestampMs = DateTime.now().millisecondsSinceEpoch;

      final grokMessageData = {
        'id': grokMsgId,
        'senderUid': 'grok-ai', // Special UID for Grok
        'timestamp_ms': timestampMs,
        'text': grokResponse,
        'imageUrl': null,
        'videoUrl': null,
        'audioUrl': null,
        'photos': [],
        'videos': [],
        'audio': [],
        'reactions': [],
        'reply_to': null,
        'pollId': null,
        'delivered': true,
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
        'isAiResponse': true, // Flag to identify AI responses
      };

      // Determine collection path
      String collectionPath;
      if (chatType == ChatType.userGroup) {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) return;
        collectionPath =
            'users/${currentUser.uid}/chat_groups/$chatGroupId/messages';
      } else if (chatType == ChatType.dm) {
        collectionPath = 'chats/$chatGroupId/messages';
      } else {
        collectionPath = chatGroupId != null
            ? 'squads/$squadId/chat_groups/$chatGroupId/messages'
            : 'squads/$squadId/messages';
      }

      // Send Grok's response
      await _firestore
          .collection(collectionPath)
          .doc(grokMsgId)
          .set(grokMessageData);

      // Cache locally
      await _sqliteHelper.insertMessage(grokMessageData,
          chatGroupId: chatGroupId);
    } catch (e) {
      debugPrint('Failed to generate Grok response: $e');
      // Don't show error to user, just log it
    }
  }

  /// Get recent messages for context
  Future<List<String>> _getRecentMessages(String? squadId, String? chatGroupId,
      {int limit = 5, required ChatType chatType, String? userId}) async {
    try {
      String collectionPath;
      if (chatType == ChatType.userGroup) {
        collectionPath = 'users/$userId/chat_groups/$chatGroupId/messages';
      } else if (chatType == ChatType.dm) {
        collectionPath = 'chats/$chatGroupId/messages';
      } else {
        collectionPath = chatGroupId != null
            ? 'squads/$squadId/chat_groups/$chatGroupId/messages'
            : 'squads/$squadId/messages';
      }

      final snapshot = await _firestore
          .collection(collectionPath)
          .orderBy('timestamp_ms', descending: true)
          .limit(limit * 2) // Get more to filter out AI responses
          .get();

      final messages = snapshot.docs
          .where((doc) =>
              !(doc.data()['isAiResponse'] ?? false)) // Exclude AI responses
          .take(limit)
          .map((doc) => doc.data()['text'] as String?)
          .where((text) => text != null && text.isNotEmpty)
          .cast<String>()
          .toList();

      return messages.reversed.toList(); // Return in chronological order
    } catch (e) {
      debugPrint('Failed to get recent messages: $e');
      return [];
    }
  }

  /// Check if a message should trigger an AI response
  bool shouldGenerateAiResponse(String message) {
    return _grokService.isMessageForGrok(message);
  }
}

/// Enum for chat types (moved here for AiService usage)
enum ChatType { squad, dm, userGroup }
