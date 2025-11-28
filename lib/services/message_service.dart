import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:logger/logger.dart';
import 'dart:io';
import 'dart:async';
import '../presentation/notifiers/squad_notifier.dart' as sn;
import '../services/ai_service.dart';
import '../domain/entities/message.dart';
import '../chat/sqlite_helper.dart';

/// Result of a message send operation
class MessageSendResult {
  final bool success;
  final String? messageId;
  final String? errorMessage;
  final bool isOffline;

  MessageSendResult._({
    required this.success,
    this.messageId,
    this.errorMessage,
    this.isOffline = false,
  });

  factory MessageSendResult.success(String messageId) {
    return MessageSendResult._(success: true, messageId: messageId);
  }

  factory MessageSendResult.failure(String errorMessage) {
    return MessageSendResult._(success: false, errorMessage: errorMessage);
  }

  factory MessageSendResult.offline(String messageId) {
    return MessageSendResult._(
        success: true, messageId: messageId, isOffline: true);
  }
}

class MessageService {
  final Logger _logger = Logger();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SQLiteHelper _sqliteHelper = SQLiteHelper();
  final AiService _aiService = AiService();
  static const int _maxRetries = 3;
  static const Duration _initialBackoff = Duration(milliseconds: 500);

  // Offline message queue
  final List<Map<String, dynamic>> _offlineMessageQueue = [];
  bool _isOnline = true;

  // Send a new message with improved error handling
  Future<MessageSendResult> sendMessage(
    WidgetRef ref, {
    required String senderUid,
    String? text,
    String? imageUrl,
    String? videoUrl,
    String? audioUrl,
    List<Map<String, dynamic>> photos = const [],
    List<Map<String, dynamic>> videos = const [],
    List<Map<String, dynamic>> audio = const [],
    List<Map<String, dynamic>> reactions = const [],
    String? pollId,
    String? replyTo,
    String? chatGroupId,
    required ChatType chatType,
  }) async {
    final bool isUserGroup = chatType == ChatType.userGroup;
    final bool isDM = chatType == ChatType.dm;

    // Capture squadId synchronously to avoid async gaps
    final cachedSquadId = isDM || isUserGroup ? null : _getCachedSquadId(ref);

    // Validate input
    if ((text?.trim().isEmpty ?? true) &&
        photos.isEmpty &&
        videos.isEmpty &&
        audio.isEmpty &&
        imageUrl == null &&
        videoUrl == null &&
        audioUrl == null &&
        pollId == null) {
      _logger.d('Message validation failed - empty message');
      return MessageSendResult.failure('Cannot send empty message');
    }

    final msgId = Uuid().v4();
    final timestampMs = DateTime.now().millisecondsSinceEpoch;

    // Simplified message data for Firestore
    final messageData = {
      'id': msgId,
      'senderUid': senderUid,
      'timestamp_ms': timestampMs,
      'text': text?.trim() ?? '',
      'imageUrl': imageUrl,
      'videoUrl': videoUrl,
      'audioUrl': audioUrl,
      'photos': photos,
      'videos': videos,
      'audio': audio,
      'reactions': reactions,
      'pollId': pollId,
      'replyTo': replyTo,
      'delivered':
          true, // Mark as delivered immediately since we're successfully writing to Firestore
      'read': false,
      'timestamp': FieldValue.serverTimestamp(),
    };

    // Determine collection path based on whether it's a group chat and user group
    String collectionPath;
    if (isUserGroup) {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        return MessageSendResult.failure('User not authenticated');
      }
      collectionPath =
          'users/${currentUser.uid}/chat_groups/$chatGroupId/messages';
    } else if (isDM) {
      collectionPath = 'chats/$chatGroupId/messages';
    } else {
      final squadId = cachedSquadId;
      if (squadId == null) {
        return MessageSendResult.failure('No squad selected');
      }
      // Squad chats: each squad IS the chat group
      collectionPath = 'squads/$squadId/messages';
    }

    try {
      // Check connectivity before attempting to send
      final isConnected = await _checkConnectivity();
      if (!isConnected) {
        // Queue message for offline sending
        final offlineMessageData = {
          ...messageData,
          'collectionPath': collectionPath,
          'chatGroupId': chatGroupId,
          'chatType': chatType.name, // Store as string for serialization
        };
        _offlineMessageQueue.add(offlineMessageData);

        // Still cache locally for immediate display (mark as pending)
        final pendingMessageData = {
          ...messageData,
          'delivered': false, // Mark as pending sync
        };
        await _sqliteHelper.insertMessage(pendingMessageData,
            chatGroupId: chatGroupId);

        return MessageSendResult.offline(msgId);
      }

      // Write to Firestore with retry
      await _retryOperation(() async {
        await _firestore.collection(collectionPath).doc(msgId).set(messageData);
      });

      // Update group metadata if this is a group chat (not for squad chats since squads ARE the chat groups)
      if (chatGroupId != null) {
        await _updateGroupMetadata(
            isDM ? null : (isUserGroup ? null : cachedSquadId),
            chatGroupId,
            text ?? '',
            timestampMs,
            chatType: chatType,
            userId: isUserGroup ? senderUid : null);
      }

      // Cache locally for offline viewing (mark as delivered)
      final deliveredMessageData = {
        ...messageData,
        'delivered': true, // Mark as successfully synced
      };
      await _sqliteHelper.insertMessage(deliveredMessageData,
          chatGroupId: chatGroupId);

      // Check if this is a message for Grok and generate AI response
      if (text != null && _aiService.shouldGenerateAiResponse(text)) {
        // ignore: use_build_context_synchronously
        _aiService.generateGrokResponse(
            ref.read(sn.squadNotifierProvider).valueOrNull!,
            text,
            senderUid,
            isDM ? null : (isUserGroup ? null : cachedSquadId),
            chatGroupId,
            chatType: chatType);
      }

      // Process any queued offline messages
      _processOfflineQueue();

      return MessageSendResult.success(msgId);
    } catch (e) {
      // Try to cache locally even if Firestore failed
      try {
        await _sqliteHelper.insertMessage(messageData,
            chatGroupId: chatGroupId);
      } catch (cacheError) {
        // Failed to cache locally, but that's okay
      }

      return MessageSendResult.failure(_getErrorMessage(e));
    }
  }

  // Send reply to a message
  Future<void> sendReply(String messageId, String text, String squadId,
      {String? chatGroupId}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw 'No user logged in';

      final collectionPath = chatGroupId != null
          ? 'squads/$squadId/chat_groups/$chatGroupId/messages'
          : 'squads/$squadId/messages';

      await _firestore.collection(collectionPath).add({
        'text': text,
        'sender': user.displayName ?? 'User',
        'timestamp': FieldValue.serverTimestamp(),
        'replyTo': messageId,
        'delivered':
            true, // Mark as delivered since we're successfully writing to Firestore
        'read': false,
      });

      _logger.d('Reply sent to message $messageId: $text');
    } catch (e) {
      _logger.e('Failed to send reply: $e');
      rethrow;
    }
  }

  // Delete a message
  Future<void> deleteMessage(String messageId, String squadId,
      {String? chatGroupId, required ChatType chatType}) async {
    try {
      final isUserGroup = chatType == ChatType.userGroup;
      final isDM = chatType == ChatType.dm;
      final isSquad = chatType == ChatType.squad;

      // Determine collection path based on chat type (same logic as sendMessage)
      String collectionPath;
      if (isUserGroup) {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) return;
        collectionPath =
            'users/${currentUser.uid}/chat_groups/$chatGroupId/messages';
      } else if (isDM) {
        collectionPath = 'chats/$chatGroupId/messages';
      } else if (isSquad) {
        // Squad chats: each squad IS the chat group
        collectionPath = 'squads/$squadId/messages';
      } else {
        // Fallback for backward compatibility
        collectionPath = 'squads/$squadId/messages';
      }

      await _firestore.collection(collectionPath).doc(messageId).delete();
    } catch (e) {
      _logger.e('Error deleting message: $e');
    }
  }

  // Edit a message
  Future<void> editMessage(String messageId, String newText, String squadId,
      {String? chatGroupId, required ChatType chatType}) async {
    try {
      final isUserGroup = chatType == ChatType.userGroup;
      final isDM = chatType == ChatType.dm;
      final isSquad = chatType == ChatType.squad;

      // Determine collection path based on chat type (same logic as sendMessage)
      String collectionPath;
      if (isUserGroup) {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) return;
        collectionPath =
            'users/${currentUser.uid}/chat_groups/$chatGroupId/messages';
      } else if (isDM) {
        collectionPath = 'chats/$chatGroupId/messages';
      } else if (isSquad) {
        // Squad chats: each squad IS the chat group
        collectionPath = 'squads/$squadId/messages';
      } else {
        // Fallback for backward compatibility
        collectionPath = 'squads/$squadId/messages';
      }

      await _firestore.collection(collectionPath).doc(messageId).update({
        'text': newText,
        'edited': true,
        'editedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _logger.e('Error editing message: $e');
      rethrow;
    }
  }

  // Mark message as delivered
  Future<void> markAsDelivered(String docId) async {
    try {
      await _retryOperation(() async {
        await _firestore
            .collection('chat')
            .doc(docId)
            .update({'delivered': true});
      });
    } catch (e) {
      _logger.e('Failed to mark as delivered: $e');
    }
  }

  // Add reaction to a message
  Future<void> addReaction(WidgetRef ref, String msgId, String reaction,
      {String? chatGroupId, ChatType? chatType}) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      // Determine collection path based on chat type
      String collectionPath;
      if (chatType == ChatType.userGroup) {
        // User group chats: users/{uid}/chat_groups/{groupId}/messages
        collectionPath = chatGroupId != null
            ? 'users/$userId/chat_groups/$chatGroupId/messages'
            : 'users/$userId/chat_groups/default/messages';
      } else {
        // DMs: chats/{chatGroupId}/messages
        collectionPath = chatGroupId != null
            ? 'chats/$chatGroupId/messages'
            : 'chats/default/messages';
      }

      final docRef = _firestore.collection(collectionPath).doc(msgId);
      final snapshot = await docRef.get();
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        final currentReactions =
            List<Map<String, dynamic>>.from(data['reactions'] ?? []);

        // Check if user already reacted with this emoji
        final existingReactionIndex = currentReactions.indexWhere(
          (r) => r['userId'] == userId && r['reaction'] == reaction,
        );

        if (existingReactionIndex != -1) {
          // User already reacted with this emoji, remove it
          final reactionToRemove = currentReactions[existingReactionIndex];
          await docRef.update({
            'reactions': FieldValue.arrayRemove([reactionToRemove])
          });
          await _sqliteHelper.updateMessage(msgId,
              {'reactions': currentReactions..removeAt(existingReactionIndex)});
        } else {
          // User hasn't reacted with this emoji, add it
          final newReaction = {
            'userId': userId,
            'reaction': reaction,
            'timestamp': FieldValue.serverTimestamp(),
          };
          await docRef.update({
            'reactions': FieldValue.arrayUnion([newReaction])
          });
          await _sqliteHelper.updateMessage(
              msgId, {'reactions': currentReactions..add(newReaction)});
        }
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      _logger.e('Failed to update reaction: $e');
    }
  }

  // Update typing status
  Future<void> updateTypingStatus(WidgetRef ref, String user, bool isTyping,
      {String? chatGroupId}) async {
    try {
      if (user.isEmpty) return;
      ref
          .read(sn.squadNotifierProvider.notifier)
          .updateTypingStatus(user, isTyping);

      final squadId = _getCachedSquadId(ref);
      if (squadId == null) return;

      // Use different typing status paths for squad vs group chats
      final typingPath = chatGroupId != null
          ? 'squads/$squadId/chat_groups/$chatGroupId/typing_status'
          : 'squads/$squadId/chat_metadata/typing_status';

      await _firestore.collection(typingPath).doc('status').set({
        'typing': {user: isTyping},
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      _logger.e('Failed to update typing status: $e');
    }
  }

  // Fetch historical messages from PostgreSQL (removed 30-day limit)
  Future<List<Map<String, dynamic>>> loadMoreMessages({
    required int offset,
    required int limit,
    String? chatGroupId,
  }) async {
    // TEMPORARILY DISABLED: Backend message loading - only use SQLite cache
    try {
      final cachedMessages = await _sqliteHelper.getMessages(offset, limit,
          chatGroupId: chatGroupId);
      _logger.d(
          'Loaded ${cachedMessages.length} messages from SQLite cache (backend disabled): ${cachedMessages.map((m) => m['id']).toList()}');
      return cachedMessages;
    } catch (e) {
      _logger.e('Failed to load cached messages: $e');
      return [];
    }
  }

  // Get cached messages from SQLite
  Future<List<Map<String, dynamic>>> getCachedMessages(int offset, int limit,
      {String? chatGroupId}) async {
    return await _sqliteHelper.getMessages(offset, limit,
        chatGroupId: chatGroupId);
  }

  // Cache messages from Firestore snapshot to SQLite
  Future<void> cacheMessagesFromSnapshot(
      QuerySnapshot snapshot, String? chatGroupId) async {
    try {
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        // Convert Firestore timestamp to milliseconds
        final timestamp = data['timestamp'];
        final timestampMs = timestamp is Timestamp
            ? timestamp.millisecondsSinceEpoch
            : (timestamp is int
                ? timestamp
                : DateTime.now().millisecondsSinceEpoch);

        final messageData = {
          ...data,
          'timestamp_ms': timestampMs,
          'id': doc.id,
        };

        await _sqliteHelper.insertMessage(messageData,
            chatGroupId: chatGroupId);
      }
    } catch (e) {
      _logger.e('Failed to cache messages from snapshot: $e');
    }
  }

  // Public method to retry sending offline messages
  Future<void> retryOfflineMessages() async {
    await _checkConnectivity();
    await _processOfflineQueue();
  }

  // Get current offline queue status
  int get offlineMessageCount => _offlineMessageQueue.length;
  bool get isOnline => _isOnline;

  // Private helper methods
  String? _getCachedSquadId(WidgetRef ref) {
    try {
      final squadStateAsync = ref.watch(sn.squadNotifierProvider);
      return squadStateAsync.maybeWhen(
        data: (squadState) => squadState.selectedSquadId,
        orElse: () => null,
      );
    } catch (e) {
      _logger.e('Failed to get cached squad ID: $e');
      return null;
    }
  }

  Future<bool> _checkConnectivity() async {
    // Simplified connectivity check - in a real app you'd use connectivity_plus
    try {
      // For now, assume we're online unless we get a specific network error
      return true;
    } catch (e) {
      _isOnline = false;
      return false;
    }
  }

  Future<void> _processOfflineQueue() async {
    if (_offlineMessageQueue.isEmpty || !_isOnline) return;

    final messagesToSend =
        List<Map<String, dynamic>>.from(_offlineMessageQueue);
    _offlineMessageQueue.clear();

    for (final messageData in messagesToSend) {
      try {
        final collectionPath = messageData.remove('collectionPath');
        final chatGroupId = messageData.remove('chatGroupId');
        final chatTypeString = messageData.remove('chatType');
        final chatType = ChatType.values.firstWhere(
          (e) => e.name == chatTypeString,
          orElse: () => ChatType.userGroup,
        );

        await _retryOperation(() async {
          await _firestore
              .collection(collectionPath)
              .doc(messageData['id'])
              .set(messageData);
        });

        // Update group metadata if needed
        if (chatGroupId != null) {
          await _updateGroupMetadata(
              chatType == ChatType.dm
                  ? null
                  : null, // squadId logic would need context
              chatGroupId,
              messageData['text'] ?? '',
              messageData['timestamp_ms'],
              chatType: chatType,
              userId: chatType == ChatType.userGroup
                  ? messageData['senderUid']
                  : null);
        }

        _logger.d('Successfully sent offline message: ${messageData['id']}');
      } catch (e) {
        _logger.e('Failed to send offline message ${messageData['id']}: $e');
        // Re-queue the message
        _offlineMessageQueue.add(messageData);
      }
    }
  }

  // Retry logic with exponential backoff
  Future<void> _retryOperation(Future<void> Function() operation) async {
    int attempt = 0;
    while (attempt < _maxRetries) {
      try {
        await operation();
        return;
      } catch (e) {
        attempt++;
        if (attempt == _maxRetries) rethrow;
        await Future.delayed(_initialBackoff * (attempt * 2));
      }
    }
  }

  // Convert exceptions to user-friendly error messages
  String _getErrorMessage(dynamic error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'You don\'t have permission to send messages in this chat';
        case 'unavailable':
          return 'Service temporarily unavailable. Message will be sent when connection is restored';
        case 'cancelled':
          return 'Message sending was cancelled';
        case 'deadline-exceeded':
          return 'Request timed out. Please try again';
        default:
          return 'Failed to send message: ${error.message ?? 'Unknown error'}';
      }
    } else if (error is TimeoutException) {
      return 'Request timed out. Please check your connection and try again';
    } else if (error is SocketException) {
      return 'Network connection error. Please check your internet connection';
    } else {
      return 'An unexpected error occurred. Please try again';
    }
  }

  // Update group metadata when a message is sent
  Future<void> _updateGroupMetadata(
      String? squadId, String groupId, String lastMessage, int timestampMs,
      {required ChatType chatType, String? userId}) async {
    try {
      CollectionReference collectionRef;
      if (chatType == ChatType.userGroup) {
        collectionRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('chat_groups');
      } else if (chatType == ChatType.dm) {
        collectionRef = _firestore.collection('chats');
      } else {
        collectionRef = _firestore
            .collection('squads')
            .doc(squadId)
            .collection('chat_groups');
      }

      await collectionRef.doc(groupId).update({
        'lastMessage': lastMessage,
        'lastMessageTime': Timestamp.fromMillisecondsSinceEpoch(timestampMs),
        if (chatType != ChatType.dm) 'messageCount': FieldValue.increment(1),
      });
    } catch (e) {
      _logger.e('Failed to update group metadata: $e');
    }
  }
}
