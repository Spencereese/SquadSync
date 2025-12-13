import 'dart:async';
import 'dart:io';
import 'package:squad_sync/domain/entities/message.dart';
import 'package:squad_sync/domain/entities/chat_group.dart';

abstract class ChatRemoteDataSource {
  // Message operations
  Future<Message> sendMessage(
      String chatGroupId, Message message, ChatType chatType);
  Future<List<Message>> fetchMessages(String chatGroupId,
      {int limit = 50, DateTime? before});
  Future<void> deleteMessage(String chatGroupId, String messageId);
  Future<void> editMessage(
      String chatGroupId, String messageId, String newText);

  // Real-time streams
  Stream<List<Message>> watchMessages(String chatGroupId);
  Stream<Map<String, Set<String>>> watchTypingIndicators(String chatGroupId);
  Stream<Map<String, int>> watchUnreadCounts(String userId);

  // Reactions
  Future<void> addReaction(
      String chatGroupId, String messageId, String userId, String reaction);
  Future<void> removeReaction(
      String chatGroupId, String messageId, String userId, String reaction);
  Future<Map<String, int>> getMessageReactions(
      String chatGroupId, String messageId);

  // Polls
  Future<Poll> createPoll(String chatGroupId, Poll poll);
  Future<void> votePoll(
      String chatGroupId, String pollId, String option, String voterId);
  Future<void> closePoll(String chatGroupId, String pollId);

  // Media operations
  Future<String> uploadMedia(File file, String mediaType, String chatGroupId);
  Future<void> deleteMedia(String mediaUrl);

  // Group management
  Future<ChatGroup> createGroup(ChatGroup group);
  Future<ChatGroup?> getChatGroup(String groupId);
  Future<void> joinGroup(String groupId, String userId);
  Future<void> leaveGroup(String groupId, String userId);
  Future<List<ChatGroup>> discoverGroups({String? query, int limit = 20});
  Future<ChatGroup?> getGroupByInviteCode(String code);
  Future<void> updateGroupSettings(
      String groupId, Map<String, dynamic> settings);

  // Typing indicators
  Future<void> updateTypingIndicator(
      String chatGroupId, String userId, bool isTyping);

  // Pinning
  Future<void> pinMessage(String chatGroupId, String messageId);
  Future<void> unpinMessage(String chatGroupId, String messageId);

  // AI integration
  Future<String> getAiResponse(String message, String context);

  // Sync operations
  Future<List<Message>> fetchMessagesSince(String chatGroupId, DateTime since);
  Future<void> batchSyncMessages(String chatGroupId, List<Message> messages);

  // Analytics
  Future<void> trackMessageEvent(String chatGroupId, String messageId,
      String event, Map<String, dynamic> data);

  // Voice chat
  Future<void> startVoiceChat(String chatGroupId, List<String> participantIds);
  Future<void> endVoiceChat(String chatGroupId);
  Future<void> updateVoiceChatParticipants(
      String chatGroupId, List<String> participantIds);
}
