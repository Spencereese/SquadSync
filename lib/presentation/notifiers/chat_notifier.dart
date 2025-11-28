import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:riverpod/riverpod.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squad_sync/domain/entities/chat_group.dart';
import 'package:squad_sync/domain/entities/chat_state.dart';
import 'package:squad_sync/domain/entities/message.dart';
import 'package:squad_sync/domain/usecases/load_messages.dart';
import 'package:squad_sync/domain/usecases/delta_sync.dart';
import 'package:squad_sync/domain/usecases/add_reaction.dart';
import 'package:squad_sync/domain/usecases/create_poll.dart';
import 'package:squad_sync/domain/usecases/vote_poll.dart';
import 'package:squad_sync/domain/usecases/upload_media.dart';
import 'package:squad_sync/domain/usecases/create_group.dart';
import 'package:squad_sync/domain/usecases/join_group.dart';
import 'package:squad_sync/domain/usecases/leave_group.dart';
import 'package:squad_sync/domain/usecases/update_typing_indicator.dart';
import 'package:squad_sync/domain/usecases/pin_message.dart';
import 'package:squad_sync/domain/usecases/load_media_history.dart';
import 'package:squad_sync/core/injection.dart' as di;
import '../../services/message_service.dart';
import '../../chat/chat_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatNotifier extends AutoDisposeAsyncNotifier<ChatState> {
  late final LoadMessages _loadMessages;
  late final DeltaSync _deltaSync;
  late final AddReaction _addReaction;
  late final CreatePoll _createPoll;
  late final VotePoll _votePoll;
  late final UploadMedia _uploadMedia;
  late final CreateGroup _createGroup;
  late final JoinGroup _joinGroup;
  late final LeaveGroup _leaveGroup;
  late final UpdateTypingIndicator _updateTypingIndicator;
  late final PinMessage _pinMessage;
  late final LoadMediaHistory _loadMediaHistory;
  late final ChatService _chatService;

  // Real-time streaming
  StreamSubscription<QuerySnapshot>? _messagesSubscription;
  String? _currentChatGroupId;
  ChatType? _currentChatType;
  DateTime? _lastSyncTimestamp;
  int _retryCount = 0;
  static const int _maxRetries = 3;
  Timer? _retryTimer;

  @override
  Future<ChatState> build() async {
    try {
      // Get dependencies from get_it
      _loadMessages = di.getIt<LoadMessages>();
      _deltaSync = di.getIt<DeltaSync>();
      _addReaction = di.getIt<AddReaction>();
      _createPoll = di.getIt<CreatePoll>();
      _votePoll = di.getIt<VotePoll>();
      _uploadMedia = di.getIt<UploadMedia>();
      _createGroup = di.getIt<CreateGroup>();
      _joinGroup = di.getIt<JoinGroup>();
      _leaveGroup = di.getIt<LeaveGroup>();
      _updateTypingIndicator = di.getIt<UpdateTypingIndicator>();
      _pinMessage = di.getIt<PinMessage>();
      _loadMediaHistory = di.getIt<LoadMediaHistory>();
      _chatService = ChatService();

      return ChatState.initial();
    } catch (e) {
      // If dependency injection fails, rethrow to make provider unavailable
      // This ensures the error is properly handled upstream
      rethrow;
    }
  }

  // Initialize real-time streaming for a chat group
  Future<void> initializeMessagesStream(
      String chatGroupId, ChatType chatType) async {
    // Dispose existing subscription if chat group changed
    if (_currentChatGroupId != chatGroupId || _currentChatType != chatType) {
      await _disposeMessagesStream();
      _currentChatGroupId = chatGroupId;
      _currentChatType = chatType;
      _retryCount = 0;
      _lastSyncTimestamp = await _getLastSyncTimestamp(chatGroupId);
    }

    // Load initial messages from cache
    await _loadInitialMessages(chatGroupId);

    // Start real-time stream
    _startMessagesStream(chatGroupId, chatType);
  }

  Future<void> _loadInitialMessages(String chatGroupId) async {
    try {
      debugPrint(
          'DEBUG ChatNotifier: Loading initial messages for $chatGroupId');
      final cachedMessages = await _loadMessages(chatGroupId, limit: 100);
      state = await AsyncValue.guard(() async {
        final currentState = await future;
        final updatedMessages =
            Map<String, List<Message>>.from(currentState.chatMessages);
        updatedMessages[chatGroupId] = cachedMessages;
        return currentState.copyWith(chatMessages: updatedMessages);
      });
      debugPrint(
          'DEBUG ChatNotifier: Loaded ${cachedMessages.length} cached messages');
    } catch (e) {
      debugPrint('DEBUG ChatNotifier: Error loading initial messages: $e');
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  void _startMessagesStream(String chatGroupId, ChatType chatType) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      debugPrint('DEBUG ChatNotifier: No authenticated user, skipping stream');
      return;
    }

    String collectionPath;
    if (chatType == ChatType.userGroup) {
      collectionPath =
          'users/${currentUser.uid}/chat_groups/$chatGroupId/messages';
    } else if (chatType == ChatType.dm) {
      collectionPath = 'chats/$chatGroupId/messages';
    } else {
      debugPrint('DEBUG ChatNotifier: Unsupported chat type: $chatType');
      return;
    }

    debugPrint(
        'DEBUG ChatNotifier: Starting messages stream for $collectionPath');

    final stream = FirebaseFirestore.instance
        .collection(collectionPath)
        .where('timestamp_ms',
            isGreaterThan: _lastSyncTimestamp?.millisecondsSinceEpoch ?? 0)
        .orderBy('timestamp_ms', descending: true)
        .limit(100)
        .snapshots();

    _messagesSubscription = stream.listen(
      (snapshot) => _onMessagesSnapshot(snapshot, chatGroupId),
      onError: (error) => _onStreamError(error, chatGroupId, chatType),
      onDone: () => debugPrint('DEBUG ChatNotifier: Messages stream done'),
    );
  }

  void _onMessagesSnapshot(QuerySnapshot snapshot, String chatGroupId) async {
    try {
      debugPrint(
          'DEBUG ChatNotifier: Received ${snapshot.docs.length} new messages');
      _retryCount = 0; // Reset retry count on success

      final remoteMessages = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Message.fromJson({
          ...data,
          'id': doc.id,
        });
      }).toList();

      // Merge with cached messages
      await _mergeMessages(chatGroupId, remoteMessages);

      // Update last sync timestamp
      _lastSyncTimestamp = DateTime.now();
      await _updateLastSyncTimestamp(chatGroupId, _lastSyncTimestamp!);
    } catch (e) {
      debugPrint('DEBUG ChatNotifier: Error processing messages snapshot: $e');
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> _mergeMessages(
      String chatGroupId, List<Message> remoteMessages) async {
    final currentState = await future;
    final existingMessages = currentState.chatMessages[chatGroupId] ?? [];

    // Create a map of existing messages by ID for quick lookup
    final existingMap = {for (var msg in existingMessages) msg.id: msg};

    // Merge remote messages, prioritizing remote on conflicts (by timestamp)
    final mergedMessages = <Message>[];
    mergedMessages.addAll(existingMessages);

    for (final remoteMsg in remoteMessages) {
      final existingMsg = existingMap[remoteMsg.id];
      if (existingMsg == null) {
        // New message
        mergedMessages.add(remoteMsg);
        debugPrint('DEBUG ChatNotifier: Added new message ${remoteMsg.id}');
      } else {
        // Always update existing messages with remote data (for status updates like delivered)
        final index = mergedMessages.indexWhere((m) => m.id == remoteMsg.id);
        if (index != -1) {
          mergedMessages[index] = remoteMsg;
          debugPrint('DEBUG ChatNotifier: Updated message ${remoteMsg.id}');
        }
      }
    }

    // Sort by timestamp descending
    mergedMessages.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    state = AsyncValue.data(currentState.copyWith(
      chatMessages: {
        ...currentState.chatMessages,
        chatGroupId: mergedMessages,
      },
    ));

    debugPrint(
        'DEBUG ChatNotifier: Merged messages, total: ${mergedMessages.length}');
  }

  void _onStreamError(Object error, String chatGroupId, ChatType chatType) {
    debugPrint(
        'DEBUG ChatNotifier: Stream error: $error, retry count: $_retryCount');

    if (_retryCount < _maxRetries) {
      _retryCount++;
      final delay =
          Duration(seconds: 1 << (_retryCount - 1)); // Exponential backoff
      debugPrint('DEBUG ChatNotifier: Retrying in ${delay.inSeconds} seconds');

      _retryTimer?.cancel();
      _retryTimer = Timer(delay, () {
        if (_currentChatGroupId == chatGroupId &&
            _currentChatType == chatType) {
          _startMessagesStream(chatGroupId, chatType);
        }
      });
    } else {
      debugPrint('DEBUG ChatNotifier: Max retries reached, giving up');
      state = AsyncValue.error(error, StackTrace.current);
    }
  }

  Future<DateTime?> _getLastSyncTimestamp(String chatGroupId) async {
    // TODO: Implement getting last sync timestamp from local storage
    // For now, return null to sync from beginning
    return null;
  }

  Future<void> _updateLastSyncTimestamp(
      String chatGroupId, DateTime timestamp) async {
    // TODO: Implement updating last sync timestamp in local storage
  }

  Future<void> _disposeMessagesStream() async {
    debugPrint('DEBUG ChatNotifier: Disposing messages stream');
    await _messagesSubscription?.cancel();
    _messagesSubscription = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    _currentChatGroupId = null;
    _currentChatType = null;
  }

  // Message operations
  Future<void> sendMessage(WidgetRef ref, String chatGroupId, String text,
      MessageType messageType, ChatType chatType,
      {String? mediaUrl,
      String? mediaType,
      String? replyTo,
      Poll? poll,
      String? voiceNoteUrl,
      int? voiceNoteDuration,
      String? mediaFilePath}) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw 'User not authenticated';

      // Create optimistic message for immediate UI update
      final optimisticMessage = Message.create(
        senderId: currentUser.uid,
        text: text,
        messageType: messageType,
        mediaUrl: mediaUrl,
        mediaType: mediaType,
        replyTo: replyTo,
        poll: poll,
        voiceNoteUrl: voiceNoteUrl,
        voiceNoteDuration: voiceNoteDuration,
      );

      // Add optimistic message to UI immediately (marked as sending)
      await _addOptimisticMessage(chatGroupId, optimisticMessage);

      // Send via ChatService
      final result = await _chatService.sendMessage(
        ref,
        senderUid: currentUser.uid,
        text: text,
        chatGroupId: chatGroupId,
        chatType: chatType,
        mediaFilePath: mediaFilePath,
        mediaType: mediaType,
      );

      if (result.success) {
        // Replace optimistic message with final message
        await _replaceOptimisticMessage(
            chatGroupId, optimisticMessage.id, result.messageId!);
      } else {
        // Handle failure - show error and remove optimistic message
        await _removeOptimisticMessage(chatGroupId, optimisticMessage.id);
        throw result.errorMessage ?? 'Failed to send message';
      }
    } catch (e) {
      debugPrint('Send message failed: $e');
      rethrow;
    }
  }

  Future<void> _addOptimisticMessage(
      String chatGroupId, Message message) async {
    final currentState = await future;
    final updatedMessages =
        Map<String, List<Message>>.from(currentState.chatMessages);
    final messages = List<Message>.from(updatedMessages[chatGroupId] ?? []);
    messages.insert(0, message); // Add to top (newest first)
    updatedMessages[chatGroupId] = messages;

    state =
        AsyncValue.data(currentState.copyWith(chatMessages: updatedMessages));
  }

  Future<void> _replaceOptimisticMessage(
      String chatGroupId, String optimisticId, String finalId) async {
    final currentState = await future;
    final updatedMessages =
        Map<String, List<Message>>.from(currentState.chatMessages);
    final messages = List<Message>.from(updatedMessages[chatGroupId] ?? []);

    final index = messages.indexWhere((m) => m.id == optimisticId);
    if (index != -1) {
      // Replace with final message (will be updated via stream)
      messages[index] = messages[index].copyWith(id: finalId);
      updatedMessages[chatGroupId] = messages;
      state =
          AsyncValue.data(currentState.copyWith(chatMessages: updatedMessages));
    }
  }

  Future<void> _removeOptimisticMessage(
      String chatGroupId, String messageId) async {
    final currentState = await future;
    final updatedMessages =
        Map<String, List<Message>>.from(currentState.chatMessages);
    final messages = List<Message>.from(updatedMessages[chatGroupId] ?? []);
    messages.removeWhere((m) => m.id == messageId);
    updatedMessages[chatGroupId] = messages;

    state =
        AsyncValue.data(currentState.copyWith(chatMessages: updatedMessages));
  }

  Future<void> loadMessages(String chatGroupId,
      {int limit = 50, DateTime? before}) async {
    final messages =
        await _loadMessages(chatGroupId, limit: limit, before: before);
    state = await AsyncValue.guard(() async {
      final currentState = await future;
      final updatedMessages =
          Map<String, List<Message>>.from(currentState.chatMessages);
      updatedMessages[chatGroupId] = messages;
      return currentState.copyWith(chatMessages: updatedMessages);
    });
  }

  Future<void> syncMessages(String chatGroupId) async {
    await _deltaSync(chatGroupId);
    // Reload messages after sync
    await loadMessages(chatGroupId);
  }

  // Reactions
  Future<void> addReaction(
      String chatGroupId, String messageId, String reaction) async {
    await _addReaction(chatGroupId, messageId, reaction);
  }

  // Polls
  Future<void> createPoll(
      String chatGroupId, String question, List<String> options) async {
    await _createPoll(chatGroupId, question, options);
  }

  Future<void> votePoll(
      String chatGroupId, String pollId, String option, String voterId) async {
    await _votePoll(chatGroupId, pollId, option, voterId);
  }

  // Media
  Future<String> uploadMedia(String filePath, String mediaType) async {
    return await _uploadMedia(filePath, mediaType);
  }

  Future<void> loadMediaHistory(String chatGroupId) async {
    final mediaHistory = await _loadMediaHistory(chatGroupId);
    state = await AsyncValue.guard(() async {
      final currentState = await future;
      return currentState.copyWith(mediaHistory: mediaHistory);
    });
  }

  // Group management
  Future<void> createGroup(String name, bool isPublic,
      {String? description}) async {
    final group = await _createGroup(name, isPublic, description: description);
    state = await AsyncValue.guard(() async {
      final currentState = await future;
      final updatedGroups =
          Map<String, ChatGroup>.from(currentState.chatGroups);
      updatedGroups[group.id] = group;
      return currentState.copyWith(chatGroups: updatedGroups);
    });
  }

  Future<void> joinGroup(String groupId) async {
    await _joinGroup(groupId);
  }

  Future<void> leaveGroup(String groupId) async {
    await _leaveGroup(groupId);
  }

  // Typing indicators
  Future<void> updateTypingIndicator(String chatGroupId, bool isTyping) async {
    await _updateTypingIndicator(chatGroupId, isTyping);
  }

  // Pinning
  Future<void> pinMessage(String chatGroupId, String messageId) async {
    await _pinMessage(chatGroupId, messageId);
  }

  // UI state management
  Future<void> selectChatGroup(String? groupId) async {
    state = await AsyncValue.guard(() async {
      final currentState = await future;
      return currentState.copyWith(selectedChatGroupId: groupId);
    });
  }

  Future<void> setReplyingToMessage(String? messageId) async {
    state = await AsyncValue.guard(() async {
      final currentState = await future;

      Message? replyToMessage;
      if (messageId != null && currentState.selectedChatGroupId != null) {
        final messages =
            currentState.chatMessages[currentState.selectedChatGroupId] ?? [];
        try {
          replyToMessage = messages.firstWhere(
            (message) => message.id == messageId,
          );
        } catch (e) {
          replyToMessage = null;
        }
      }

      return currentState.copyWith(
        replyingToMessageId: messageId,
        replyToMessage: replyToMessage,
      );
    });
  }

  Future<void> setReplyingToMessageObject(Message? message) async {
    state = await AsyncValue.guard(() async {
      final currentState = await future;
      return currentState.copyWith(
        replyingToMessageId: message?.id,
        replyToMessage: message,
      );
    });
  }

  Future<void> clearReplyToMessage() async {
    state = await AsyncValue.guard(() async {
      final currentState = await future;
      return currentState.copyWith(
          replyingToMessageId: null, replyToMessage: null);
    });
  }

  // Sync operations
  Future<void> performSync() async {
    // TODO: Implement delta sync
    // await _deltaSync();
  }

  Future<void> clearSyncError() async {
    state = await AsyncValue.guard(() async {
      final currentState = await future;
      return currentState.copyWith(syncError: null);
    });
  }

  // Dispose method (for compatibility)
  void dispose() {
    _disposeMessagesStream();
    // AsyncNotifier handles disposal automatically
  }

  // Helper methods for computed properties
  List<Message> getMessagesForGroup(String chatGroupId) {
    return state.maybeWhen(
      data: (data) => data.chatMessages[chatGroupId] ?? [],
      orElse: () => [],
    );
  }

  Set<String> getTypingUsers(String chatGroupId) {
    return state.maybeWhen(
      data: (data) => data.typingIndicators[chatGroupId] ?? {},
      orElse: () => {},
    );
  }

  int getUnreadCount(String chatGroupId) {
    return state.maybeWhen(
      data: (data) => data.unreadCounts[chatGroupId] ?? 0,
      orElse: () => 0,
    );
  }

  bool isUserTyping(String chatGroupId, String userId) {
    return getTypingUsers(chatGroupId).contains(userId);
  }

  List<Map<String, dynamic>> getMediaHistory() {
    return state.maybeWhen(
      data: (data) => data.mediaHistory,
      orElse: () => [],
    );
  }

  Map<String, Poll> getActivePolls(String chatGroupId) {
    return state.maybeWhen(
      data: (data) => (data.activePolls[chatGroupId] ?? {}).map(
        (key, value) => MapEntry(key, value),
      ),
      orElse: () => {},
    );
  }

  Future<void> markAsDelivered(String docId) async {
    await di.getIt<MessageService>().markAsDelivered(docId);
  }
}

final chatNotifierProvider =
    AutoDisposeAsyncNotifierProvider<ChatNotifier, ChatState>(
  () => ChatNotifier(),
);
