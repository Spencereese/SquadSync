import 'dart:async';
import 'package:squad_sync/domain/entities/message.dart';
import 'package:squad_sync/domain/entities/chat_group.dart';

abstract class ChatLocalDataSource {
  // Message caching
  Future<void> cacheMessages(String chatGroupId, List<Message> messages);
  Future<List<Message>> getCachedMessages(String chatGroupId, {int limit = 50, DateTime? before});
  Future<void> updateMessage(String chatGroupId, String messageId, Message message);
  Future<void> deleteMessage(String chatGroupId, String messageId);

  // Group caching
  Future<void> cacheChatGroups(List<ChatGroup> groups);
  Future<List<ChatGroup>> getCachedChatGroups();
  Future<void> updateChatGroup(ChatGroup group);

  // Sync state
  Future<void> markMessagesAsSynced(String chatGroupId, List<String> messageIds);
  Future<List<Message>> getUnsyncedMessages(String chatGroupId);
  Future<void> updateLastSyncTimestamp(String chatGroupId, DateTime timestamp);
  Future<DateTime?> getLastSyncTimestamp(String chatGroupId);

  // Reactions and interactions
  Future<void> cacheReactions(String chatGroupId, String messageId, Map<String, int> reactions);
  Future<Map<String, int>?> getCachedReactions(String chatGroupId, String messageId);

  // Polls
  Future<void> cachePoll(String chatGroupId, Poll poll);
  Future<Map<String, Poll>> getCachedPolls(String chatGroupId);

  // Typing indicators
  Future<void> updateTypingIndicator(String chatGroupId, String userId, bool isTyping);
  Future<Map<String, Set<String>>> getTypingIndicators(String chatGroupId);

  // Read status
  Future<void> markAsRead(String chatGroupId, DateTime timestamp);
  Future<DateTime?> getLastReadTimestamp(String chatGroupId);

  // Media history
  Future<void> cacheMediaHistory(List<Map<String, dynamic>> mediaItems);
  Future<List<Map<String, dynamic>>> getCachedMediaHistory(String chatGroupId);

  // Cleanup (30-day purging)
  Future<void> purgeOldMessages({Duration maxAge = const Duration(days: 30)});
  Future<void> purgeOldMedia({Duration maxAge = const Duration(days: 30)});

  // Analytics
  Future<void> cacheAnalytics(String chatGroupId, Map<String, dynamic> analytics);
  Future<Map<String, dynamic>?> getCachedAnalytics(String chatGroupId);
}