import 'package:squad_sync/domain/entities/message.dart';
import 'package:squad_sync/domain/entities/chat_group.dart';

abstract class ChatRepository {
  // Message operations
  Future<Message> sendMessage(String chatGroupId, String text,
      MessageType messageType, ChatType chatType,
      {String? mediaUrl,
      String? mediaType,
      String? replyTo,
      Poll? poll,
      String? voiceNoteUrl,
      int? voiceNoteDuration});
  Future<List<Message>> loadMessages(String chatGroupId,
      {int limit = 50, DateTime? before});
  Future<void> deleteMessage(String chatGroupId, String messageId);
  Future<Message> editMessage(
      String chatGroupId, String messageId, String newText);

  // Real-time streams
  Stream<List<Message>> watchMessages(String chatGroupId);
  Stream<Map<String, Set<String>>> watchTypingIndicators(String chatGroupId);
  Stream<Map<String, int>> watchUnreadCounts();

  // Reactions and interactions
  Future<void> addReaction(
      String chatGroupId, String messageId, String reaction);
  Future<void> removeReaction(
      String chatGroupId, String messageId, String reaction);
  Future<Map<String, int>> getMessageReactions(
      String chatGroupId, String messageId);

  // Polls
  Future<Poll> createPoll(
      String chatGroupId, String question, List<String> options);
  Future<void> votePoll(
      String chatGroupId, String pollId, String option, String voterId);
  Future<void> closePoll(String chatGroupId, String pollId);
  Future<Map<String, Poll>> getActivePolls(String chatGroupId);

  // Media operations
  Future<String> uploadMedia(String filePath, String mediaType);
  Future<List<Map<String, dynamic>>> getMediaHistory(String chatGroupId);
  Future<void> deleteMedia(String mediaUrl);

  // Group management
  Future<ChatGroup> createGroup(String name, bool isPublic,
      {String? description});
  Future<void> joinGroup(String groupId);
  Future<void> leaveGroup(String groupId);
  Future<List<ChatGroup>> discoverGroups({String? query, int limit = 20});
  Future<void> updateGroupSettings(
      String groupId, Map<String, dynamic> settings);

  // Typing indicators
  Future<void> updateTypingIndicator(String chatGroupId, bool isTyping);
  Future<Map<String, Set<String>>> getTypingIndicators(String chatGroupId);

  // Pinning and moderation
  Future<void> pinMessage(String chatGroupId, String messageId);
  Future<void> unpinMessage(String chatGroupId, String messageId);
  Future<List<String>> getPinnedMessages(String chatGroupId);

  // AI integration
  Future<String> getAiResponse(
      String chatGroupId, String userMessage, String context);
  Future<List<Message>> searchMessages(String chatGroupId, String query);

  // Sync and offline support
  Future<void> syncMessages(String chatGroupId, {DateTime? since});
  Future<List<Map<String, dynamic>>> getPendingMessages();
  Future<void> markMessagesAsRead(String chatGroupId, DateTime timestamp);

  // Analytics
  Future<void> trackMessageAnalytics(
      String chatGroupId, String messageId, String event);
  Future<Map<String, dynamic>> getChatAnalytics(String chatGroupId);

  // Voice chat integration
  Future<void> startVoiceChat(String chatGroupId);
  Future<void> endVoiceChat(String chatGroupId);
  Future<void> joinVoiceChat(String chatGroupId);
  Future<void> leaveVoiceChat(String chatGroupId);
  Future<List<String>> getVoiceChatParticipants(String chatGroupId);
}
