import 'dart:async';
import '../../services/auth_service_supabase.dart';
import 'package:squad_sync/data/datasources/chat_local_datasource.dart';
import 'package:squad_sync/data/datasources/chat_remote_datasource.dart';
import 'package:squad_sync/domain/entities/message.dart';
import 'package:squad_sync/domain/entities/chat_group.dart';
import 'package:squad_sync/domain/repositories/chat_repository.dart';

class ChatRepositoryImpl implements ChatRepository {
  final ChatLocalDataSource _localDataSource;
  final ChatRemoteDataSource _remoteDataSource;

  ChatRepositoryImpl(this._localDataSource, this._remoteDataSource);

  @override
  Future<Message> sendMessage(String chatGroupId, String text,
      MessageType messageType, ChatType chatType,
      {String? mediaUrl,
      String? mediaType,
      String? replyTo,
      Poll? poll,
      String? voiceNoteUrl,
      int? voiceNoteDuration}) async {
    final currentUser = AuthServiceSupabase().currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    final message = Message.create(
      senderId: currentUser.id,
      text: text,
      messageType: messageType,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      replyTo: replyTo,
      poll: poll,
      voiceNoteUrl: voiceNoteUrl,
      voiceNoteDuration: voiceNoteDuration,
    );

    // Send to remote first
    final sentMessage =
        await _remoteDataSource.sendMessage(chatGroupId, message, chatType);

    // Cache locally
    await _localDataSource.cacheMessages(chatGroupId, [sentMessage]);
    await _localDataSource.markMessagesAsSynced(chatGroupId, [sentMessage.id]);

    return sentMessage;
  }

  @override
  Future<List<Message>> loadMessages(String chatGroupId,
      {int limit = 50, DateTime? before}) async {
    // Try cache first
    final cachedMessages = await _localDataSource.getCachedMessages(chatGroupId,
        limit: limit, before: before);
    if (cachedMessages.isNotEmpty) {
      return cachedMessages;
    }

    // Fetch from remote
    final remoteMessages = await _remoteDataSource.fetchMessages(chatGroupId,
        limit: limit, before: before);
    await _localDataSource.cacheMessages(chatGroupId, remoteMessages);

    return remoteMessages;
  }

  @override
  Future<void> deleteMessage(String chatGroupId, String messageId) async {
    await _remoteDataSource.deleteMessage(chatGroupId, messageId);
    await _localDataSource.deleteMessage(chatGroupId, messageId);
  }

  @override
  Future<Message> editMessage(
      String chatGroupId, String messageId, String newText) async {
    // First update remote
    await _remoteDataSource.editMessage(chatGroupId, messageId, newText);

    // Get the current message and update it locally
    final cachedMessages =
        await _localDataSource.getCachedMessages(chatGroupId, limit: 100);
    final messageToUpdate =
        cachedMessages.firstWhere((msg) => msg.id == messageId);

    final editedMessage = messageToUpdate.copyWith(
      text: newText,
      isEdited: true,
      editedAt: DateTime.now(),
    );

    await _localDataSource.updateMessage(chatGroupId, messageId, editedMessage);
    return editedMessage;
  }

  @override
  Stream<List<Message>> watchMessages(String chatGroupId) {
    return _remoteDataSource
        .watchMessages(chatGroupId)
        .asyncMap((messages) async {
      await _localDataSource.cacheMessages(chatGroupId, messages);
      return messages;
    });
  }

  @override
  Stream<Map<String, Set<String>>> watchTypingIndicators(String chatGroupId) {
    return _remoteDataSource.watchTypingIndicators(chatGroupId);
  }

  @override
  Stream<Map<String, int>> watchUnreadCounts() {
    return _remoteDataSource.watchUnreadCounts('current_user_id');
  }

  @override
  Future<void> addReaction(
      String chatGroupId, String messageId, String reaction) async {
    await _remoteDataSource.addReaction(
        chatGroupId, messageId, 'current_user_id', reaction);
    // Update local cache
    final reactions = await getMessageReactions(chatGroupId, messageId);
    await _localDataSource.cacheReactions(chatGroupId, messageId, reactions);
  }

  @override
  Future<void> removeReaction(
      String chatGroupId, String messageId, String reaction) async {
    await _remoteDataSource.removeReaction(
        chatGroupId, messageId, 'current_user_id', reaction);
    final reactions = await getMessageReactions(chatGroupId, messageId);
    await _localDataSource.cacheReactions(chatGroupId, messageId, reactions);
  }

  @override
  Future<Map<String, int>> getMessageReactions(
      String chatGroupId, String messageId) async {
    final cached =
        await _localDataSource.getCachedReactions(chatGroupId, messageId);
    if (cached != null) return cached;

    final remote =
        await _remoteDataSource.getMessageReactions(chatGroupId, messageId);
    await _localDataSource.cacheReactions(chatGroupId, messageId, remote);
    return remote;
  }

  @override
  Future<Poll> createPoll(
      String chatGroupId, String question, List<String> options) async {
    final poll = Poll(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      question: question,
      options: options,
      votes: {},
      createdAt: DateTime.now(),
      createdBy: 'current_user_id',
    );

    final createdPoll = await _remoteDataSource.createPoll(chatGroupId, poll);
    await _localDataSource.cachePoll(chatGroupId, createdPoll);
    return createdPoll;
  }

  @override
  Future<void> votePoll(
      String chatGroupId, String pollId, String option, String voterId) async {
    await _remoteDataSource.votePoll(chatGroupId, pollId, option, voterId);
    // Refresh local poll data
    final polls = await getActivePolls(chatGroupId);
    for (final poll in polls.values) {
      await _localDataSource.cachePoll(chatGroupId, poll);
    }
  }

  @override
  Future<void> closePoll(String chatGroupId, String pollId) async {
    await _remoteDataSource.closePoll(chatGroupId, pollId);
  }

  @override
  Future<Map<String, Poll>> getActivePolls(String chatGroupId) async {
    final cached = await _localDataSource.getCachedPolls(chatGroupId);
    if (cached.isNotEmpty) return cached;

    // This would need to be implemented in remote datasource
    // For now, return cached
    return cached;
  }

  @override
  Future<String> uploadMedia(String filePath, String mediaType) async {
    // This would need file handling
    throw UnimplementedError();
  }

  @override
  Future<List<Map<String, dynamic>>> getMediaHistory(String chatGroupId) async {
    final cached = await _localDataSource.getCachedMediaHistory(chatGroupId);
    if (cached.isNotEmpty) return cached;

    // Fetch from remote
    return [];
  }

  @override
  Future<void> deleteMedia(String mediaUrl) async {
    await _remoteDataSource.deleteMedia(mediaUrl);
  }

  @override
  Future<ChatGroup> createGroup(String name, bool isPublic,
      {String? description}) async {
    final currentUser = AuthServiceSupabase().currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    final group = ChatGroup.create(
      name: name,
      createdBy: currentUser.id,
      isPublic: isPublic,
      description: description,
    );

    final createdGroup = await _remoteDataSource.createGroup(group);
    // TODO: Add chat_groups table to SQLite schema before enabling caching
    // await _localDataSource.updateChatGroup(createdGroup);
    return createdGroup;
  }

  @override
  Future<void> joinGroup(String groupId) async {
    await _remoteDataSource.joinGroup(groupId, 'current_user_id');
  }

  @override
  Future<void> leaveGroup(String groupId) async {
    await _remoteDataSource.leaveGroup(groupId, 'current_user_id');
  }

  @override
  Future<List<ChatGroup>> discoverGroups(
      {String? query, int limit = 20}) async {
    return await _remoteDataSource.discoverGroups(query: query, limit: limit);
  }

  @override
  Future<void> updateGroupSettings(
      String groupId, Map<String, dynamic> settings) async {
    await _remoteDataSource.updateGroupSettings(groupId, settings);
  }

  @override
  Future<void> updateTypingIndicator(String chatGroupId, bool isTyping) async {
    await _remoteDataSource.updateTypingIndicator(
        chatGroupId, 'current_user_id', isTyping);
    await _localDataSource.updateTypingIndicator(
        chatGroupId, 'current_user_id', isTyping);
  }

  @override
  Future<Map<String, Set<String>>> getTypingIndicators(
      String chatGroupId) async {
    return await _localDataSource.getTypingIndicators(chatGroupId);
  }

  @override
  Future<void> pinMessage(String chatGroupId, String messageId) async {
    await _remoteDataSource.pinMessage(chatGroupId, messageId);
  }

  @override
  Future<void> unpinMessage(String chatGroupId, String messageId) async {
    await _remoteDataSource.unpinMessage(chatGroupId, messageId);
  }

  @override
  Future<List<String>> getPinnedMessages(String chatGroupId) async {
    // This would need implementation
    return [];
  }

  @override
  Future<String> getAiResponse(
      String chatGroupId, String userMessage, String context) async {
    return await _remoteDataSource.getAiResponse(userMessage, context);
  }

  @override
  Future<List<Message>> searchMessages(String chatGroupId, String query) async {
    // This would need implementation
    return [];
  }

  @override
  Future<void> syncMessages(String chatGroupId, {DateTime? since}) async {
    final lastSync = since ??
        await _localDataSource.getLastSyncTimestamp(chatGroupId) ??
        DateTime.now().subtract(const Duration(days: 1));
    final remoteMessages =
        await _remoteDataSource.fetchMessagesSince(chatGroupId, lastSync);
    await _localDataSource.cacheMessages(chatGroupId, remoteMessages);
    await _localDataSource.updateLastSyncTimestamp(chatGroupId, DateTime.now());
  }

  @override
  Future<List<Map<String, dynamic>>> getPendingMessages() async {
    // Implementation needed
    return [];
  }

  @override
  Future<void> markMessagesAsRead(
      String chatGroupId, DateTime timestamp) async {
    await _localDataSource.markAsRead(chatGroupId, timestamp);
  }

  @override
  Future<void> trackMessageAnalytics(
      String chatGroupId, String messageId, String event) async {
    await _remoteDataSource
        .trackMessageEvent(chatGroupId, messageId, event, {});
  }

  @override
  Future<Map<String, dynamic>> getChatAnalytics(String chatGroupId) async {
    return await _localDataSource.getCachedAnalytics(chatGroupId) ?? {};
  }

  @override
  Future<void> startVoiceChat(String chatGroupId) async {
    // Implementation needed
  }

  @override
  Future<void> endVoiceChat(String chatGroupId) async {
    await _remoteDataSource.endVoiceChat(chatGroupId);
  }

  @override
  Future<void> joinVoiceChat(String chatGroupId) async {
    // Implementation needed
  }

  @override
  Future<void> leaveVoiceChat(String chatGroupId) async {
    // Implementation needed
  }

  @override
  Future<List<String>> getVoiceChatParticipants(String chatGroupId) async {
    // Implementation needed
    return [];
  }
}
