import 'dart:async';
import '../domain/entities/message.dart';
import '../models/chat_metadata.dart';

/// **Chat Persistence Service Interface**
///
/// Abstract layer for chat storage - supports multiple backends:
/// - Firestore (legacy)
/// - Supabase (target)
/// - Dual-mode (migration)
///
/// This enables clean migration without touching business logic.
abstract class ChatPersistenceService {
  // ============================================================================
  // MESSAGE OPERATIONS
  // ============================================================================

  /// Stream messages for a chat context
  /// Real-time updates with automatic reconnection
  Stream<List<Message>> streamMessages({
    required String chatId,
    required ChatType chatType,
    int limit = 100,
  });

  /// Get messages once (no real-time)
  /// Useful for initial load and pagination
  Future<List<Message>> getMessages({
    required String chatId,
    required ChatType chatType,
    int limit = 100,
    String? beforeMessageId,
  });

  /// Send a new message
  /// Returns the message ID on success
  Future<String> sendMessage(Message message);

  /// Update an existing message (edits, reactions)
  Future<void> updateMessage(String messageId, Map<String, dynamic> updates);

  /// Delete a message (soft delete - marks as deleted)
  Future<void> deleteMessage(String messageId);

  /// Add reaction to a message
  Future<void> addReaction(String messageId, String emoji, String userId);

  /// Remove reaction from a message
  Future<void> removeReaction(String messageId, String emoji, String userId);

  // ============================================================================
  // METADATA OPERATIONS
  // ============================================================================

  /// Stream chat metadata (typing, unread counts, last message)
  Stream<ChatMetadata?> streamChatMetadata(String chatId);

  /// Get chat metadata once
  Future<ChatMetadata?> getChatMetadata(String chatId);

  /// Update chat metadata
  Future<void> updateChatMetadata(String chatId, Map<String, dynamic> updates);

  // ============================================================================
  // TYPING INDICATORS
  // ============================================================================

  /// Stream typing users for a chat
  /// Returns list of user IDs currently typing
  Stream<List<String>> streamTypingUsers(String chatId);

  /// Set typing status for current user
  Future<void> setTyping(String chatId, String userId, bool isTyping);

  // ============================================================================
  // READ RECEIPTS
  // ============================================================================

  /// Mark messages as read up to a specific message
  Future<void> markAsRead(String chatId, String userId, String lastMessageId);

  /// Get unread count for a chat
  Future<int> getUnreadCount(String chatId, String userId);

  // ============================================================================
  // OFFLINE SUPPORT
  // ============================================================================

  /// Queue message for offline send
  /// Returns a temporary ID that will be replaced when online
  Future<String> queueOfflineMessage(Message message);

  /// Get all queued offline messages
  Future<List<Message>> getOfflineQueue();

  /// Process offline queue when back online
  Future<void> processOfflineQueue();

  // ============================================================================
  // CLEANUP & MAINTENANCE
  // ============================================================================

  /// Delete old messages (retention policy)
  Future<void> deleteOldMessages(String chatId, DateTime beforeDate);

  /// Clear local cache (for testing/debugging)
  Future<void> clearCache();
}
