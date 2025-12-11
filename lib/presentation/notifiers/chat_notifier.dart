import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squad_sync/domain/entities/chat_group.dart';
import 'package:squad_sync/domain/entities/chat_state.dart';
import 'package:squad_sync/domain/entities/message.dart';
import 'package:squad_sync/domain/repositories/chat_repository.dart';
import 'package:squad_sync/core/injection.dart';
import 'package:squad_sync/services/clip_service.dart';
import '../../services/message_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';
import '../../services/auth_service_supabase.dart';

class ChatNotifier extends AutoDisposeAsyncNotifier<ChatState> {
  late final ChatRepository _repository;
  late final MessageService _chatService;
  late final ClipService _clipService;
  final AuthServiceSupabase _authService = AuthServiceSupabase();

  // Real-time streaming - Dual mode (Supabase + Firestore fallback)
  StreamSubscription<List<Map<String, dynamic>>>? _messagesSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _supabaseMessagesSubscription;
  RealtimeChannel? _typingChannel;
  RealtimeChannel? _presenceChannel;
  String? _currentChatGroupId;
  ChatType? _currentChatType;
  DateTime? _lastSyncTimestamp;
  int _retryCount = 0;
  static const int _maxRetries = 3;
  Timer? _retryTimer;
  bool _useSupabase = true; // Try Supabase first, fallback to Firestore
  Timer? _typingDebounceTimer;
  final Set<String> _currentTypingUsers = {};

  @override
  Future<ChatState> build() async {
    try {
      // Get repository from provider
      _repository = ref.read(chatRepositoryProvider);
      _chatService = MessageService();
      _clipService = ClipService();

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
    // Wait for the notifier to be fully initialized
    await future;

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
      final cachedMessages =
          await _repository.loadMessages(chatGroupId, limit: 100);
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
    if (_useSupabase) {
      _startSupabaseMessagesStream(chatGroupId, chatType);
    } else {
      _startFirestoreMessagesStream(chatGroupId, chatType);
    }
  }

  void _startSupabaseMessagesStream(String chatGroupId, ChatType chatType) {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        debugPrint(
            'DEBUG ChatNotifier: No authenticated user for Supabase stream');
        return;
      }

      // Build Supabase filter based on chat type
      // Note: All chat types use 'chat_id' column in Supabase
      Map<String, dynamic> filters = {
        'chat_id': chatGroupId,
        'chat_type': chatType.name, // 'squad', 'userGroup', 'dm'
      };

      // Delta sync: only get messages since last timestamp
      final lastTimestamp = _lastSyncTimestamp?.millisecondsSinceEpoch ?? 0;

      debugPrint(
          'DEBUG ChatNotifier: Starting Supabase stream for $chatGroupId (delta from $lastTimestamp)');

      // Create real-time stream with delta sync
      var query = supabase.from('chat_messages').stream(primaryKey: ['id']);

      // Apply filters
      filters.forEach((key, value) {
        query = query.eq(key, value) as dynamic;
      });

      // Delta sync filter (convert timestamp ms to ISO string for comparison)
      if (lastTimestamp > 0) {
        final lastDate = DateTime.fromMillisecondsSinceEpoch(lastTimestamp)
            .toIso8601String();
        query = query.gt('timestamp', lastDate) as dynamic;
      }

      _supabaseMessagesSubscription =
          query.order('timestamp', ascending: false).limit(100).listen(
        (data) => _onSupabaseMessagesSnapshot(data, chatGroupId),
        onError: (error) {
          debugPrint('DEBUG ChatNotifier: Supabase stream error: $error');
          // Fallback to Firestore
          _useSupabase = false;
          _supabaseMessagesSubscription?.cancel();
          _supabaseMessagesSubscription = null;
          _startFirestoreMessagesStream(chatGroupId, chatType);
        },
      );

      // Initialize typing channel
      _initializeTypingChannel(chatGroupId);

      // Initialize presence channel for online status
      _initializePresenceChannel(chatGroupId);

      debugPrint('DEBUG ChatNotifier: Supabase stream initialized');
    } catch (e) {
      debugPrint('DEBUG ChatNotifier: Failed to start Supabase stream: $e');
      // Fallback to Firestore
      _useSupabase = false;
      _startFirestoreMessagesStream(chatGroupId, chatType);
    }
  }

  void _startFirestoreMessagesStream(String chatGroupId, ChatType chatType) {
    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      debugPrint('DEBUG ChatNotifier: No authenticated user, skipping stream');
      return;
    }

    debugPrint(
        'DEBUG ChatNotifier: Starting Supabase stream for chat_group_id: $chatGroupId (fallback mode)');

    // Delta sync: only sync messages since last timestamp
    final stream = SupabaseService.client
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('chat_id', chatGroupId)
        .order('timestamp', ascending: false)
        .limit(100);

    _messagesSubscription = stream.listen(
      (data) => _onSupabaseMessagesSnapshot(data, chatGroupId),
      onError: (error) => _onStreamError(error, chatGroupId, chatType),
      onDone: () => debugPrint('DEBUG ChatNotifier: Messages stream done'),
    );
  }

  void _onSupabaseMessagesSnapshot(
      List<Map<String, dynamic>> data, String chatGroupId) async {
    try {
      debugPrint(
          'DEBUG ChatNotifier: Received ${data.length} messages from Supabase');
      _retryCount = 0; // Reset retry count on success

      final remoteMessages = data.map((messageData) {
        return Message.fromJson(messageData);
      }).toList();

      // Merge with cached messages
      await _mergeMessages(chatGroupId, remoteMessages);

      // Update last sync timestamp for delta sync
      if (remoteMessages.isNotEmpty) {
        _lastSyncTimestamp = DateTime.now();
        await _updateLastSyncTimestamp(chatGroupId, _lastSyncTimestamp!);
      }
    } catch (e) {
      debugPrint('DEBUG ChatNotifier: Error processing Supabase messages: $e');
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
    await _supabaseMessagesSubscription?.cancel();
    _supabaseMessagesSubscription = null;

    // Dispose typing channel
    if (_typingChannel != null) {
      await supabase.removeChannel(_typingChannel!);
      _typingChannel = null;
    }

    // Dispose presence channel
    if (_presenceChannel != null) {
      await supabase.removeChannel(_presenceChannel!);
      _presenceChannel = null;
    }

    _retryTimer?.cancel();
    _retryTimer = null;
    _typingDebounceTimer?.cancel();
    _typingDebounceTimer = null;
    _currentChatGroupId = null;
    _currentChatType = null;
    _currentTypingUsers.clear();
  }

  // ============================================================================
  // TYPING INDICATORS - Supabase Realtime Channel
  // ============================================================================

  void _initializeTypingChannel(String chatGroupId) {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) return;

      // Create channel for typing indicators
      _typingChannel = supabase.channel('typing:$chatGroupId');

      // Subscribe to typing events
      _typingChannel!
          .onBroadcast(
            event: 'typing',
            callback: (payload) {
              final userId = payload['user_id'] as String?;
              final isTyping = payload['is_typing'] as bool? ?? false;
              final displayName =
                  payload['display_name'] as String? ?? userId ?? 'Unknown';

              debugPrint(
                  'DEBUG ChatNotifier: Typing event - $displayName: $isTyping');

              // Don't show own typing indicator
              if (userId == currentUser.id) return;

              if (isTyping) {
                _currentTypingUsers.add(displayName);
              } else {
                _currentTypingUsers.remove(displayName);
              }

              // Update state with typing users
              _updateTypingIndicators(chatGroupId);
            },
          )
          .subscribe();

      debugPrint(
          'DEBUG ChatNotifier: Typing channel initialized for $chatGroupId');
    } catch (e) {
      debugPrint('DEBUG ChatNotifier: Failed to initialize typing channel: $e');
      // Non-critical, continue without typing indicators
    }
  }

  Future<void> _updateTypingIndicators(String chatGroupId) async {
    state = await AsyncValue.guard(() async {
      final currentState = await future;
      final updatedIndicators =
          Map<String, Set<String>>.from(currentState.typingIndicators);
      updatedIndicators[chatGroupId] = Set<String>.from(_currentTypingUsers);
      return currentState.copyWith(typingIndicators: updatedIndicators);
    });
  }

  // ============================================================================
  // ONLINE STATUS - Supabase Realtime Presence
  // ============================================================================

  void _initializePresenceChannel(String chatGroupId) {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) return;

      // Create presence channel for online status
      _presenceChannel = supabase.channel('presence:$chatGroupId');

      // Track presence
      _presenceChannel!.onPresenceSync((_) {
        final presenceState = _presenceChannel!.presenceState();
        debugPrint(
            'DEBUG ChatNotifier: Presence sync - ${presenceState.length} users online');

        // Update online users in state
        _updateOnlineUsers(chatGroupId, presenceState);
      }).onPresenceJoin((payload) {
        debugPrint('DEBUG ChatNotifier: User joined - $payload');
      }).onPresenceLeave((payload) {
        debugPrint('DEBUG ChatNotifier: User left - $payload');
      }).subscribe((status, error) async {
        if (status == RealtimeSubscribeStatus.subscribed) {
          // Track own presence
          await _presenceChannel!.track({
            'user_id': currentUser.id,
            'display_name': currentUser.userMetadata?['display_name'] ??
                currentUser.email ??
                'Unknown',
            'online_at': DateTime.now().toIso8601String(),
          });
          debugPrint('DEBUG ChatNotifier: Presence tracking enabled');
        }
      });

      debugPrint(
          'DEBUG ChatNotifier: Presence channel initialized for $chatGroupId');
    } catch (e) {
      debugPrint(
          'DEBUG ChatNotifier: Failed to initialize presence channel: $e');
      // Non-critical, continue without presence
    }
  }

  Future<void> _updateOnlineUsers(
      String chatGroupId, List<SinglePresenceState> presenceState) async {
    try {
      final onlineUserIds = <String>{};

      for (final state in presenceState) {
        // Extract user IDs from presence data
        for (final presence in state.presences) {
          final payload = presence.payload;
          final userId = payload['user_id'] as String?;
          if (userId != null) {
            onlineUserIds.add(userId);
          }
        }
      }

      // Update state with online users (you may need to add this to ChatState)
      debugPrint(
          'DEBUG ChatNotifier: ${onlineUserIds.length} users online in $chatGroupId');
    } catch (e) {
      debugPrint('DEBUG ChatNotifier: Error updating online users: $e');
    }
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
      String? mediaFilePath,
      String? clipFilePath}) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) throw 'User not authenticated';

      Map<String, dynamic>? clipData;

      // Handle clip processing
      if (messageType == MessageType.clip && clipFilePath != null) {
        debugPrint('Processing clip from: $clipFilePath');

        final processedClip = await _clipService.processClip(
          clipFilePath,
          onProgress: (progress) {
            debugPrint(
                'Clip upload progress: ${(progress * 100).toStringAsFixed(0)}%');
            // TODO: Update UI with progress if needed
          },
        );

        clipData = {
          'clipId': processedClip.clipId,
          'videoUrl': processedClip.videoUrl,
          'thumbnailUrl': processedClip.thumbUrl,
          'durationSec': (processedClip.duration / 1000).round(),
          'width': processedClip.width,
          'height': processedClip.height,
          'views': 0,
          'hypeReactions': <String>[],
        };

        // Set mediaUrl to video URL for backward compatibility
        mediaUrl = processedClip.videoUrl;
        mediaType = 'video/mp4';
      }

      // Create optimistic message for immediate UI update
      final optimisticMessage = Message.create(
        senderId: currentUser.id,
        text: text,
        messageType: messageType,
        mediaUrl: mediaUrl,
        mediaType: mediaType,
        replyTo: replyTo,
        poll: poll,
        voiceNoteUrl: voiceNoteUrl,
        voiceNoteDuration: voiceNoteDuration,
        clipData: clipData,
      );

      // Add optimistic message to UI immediately (marked as sending)
      await _addOptimisticMessage(chatGroupId, optimisticMessage);

      // Send via ChatService
      final result = await _chatService.sendMessage(
        ref,
        senderUid: currentUser.id,
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

  /// Increment view count for a clip message
  Future<void> incrementClipViews(
      String chatGroupId, String messageId, ChatType chatType) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) return;

      // Increment views in Supabase
      final clipData = await SupabaseService.client
          .from('chat_messages')
          .select('clip_data')
          .eq('id', messageId)
          .maybeSingle();

      if (clipData != null) {
        final currentViews = (clipData['clip_data']?['views'] as int?) ?? 0;
        await SupabaseService.client.from('chat_messages').update({
          'clip_data': {
            ...Map<String, dynamic>.from(clipData['clip_data'] ?? {}),
            'views': currentViews + 1,
          }
        }).eq('id', messageId);
      }

      debugPrint('Incremented views for clip $messageId');
    } catch (e) {
      debugPrint('Failed to increment clip views: $e');
      // Don't rethrow - view counting is non-critical
    }
  }

  /// Add hype reaction to a clip
  Future<void> toggleClipHype(
      String chatGroupId, String messageId, ChatType chatType) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) return;

      // Get current clip data from Supabase
      final messageData = await SupabaseService.client
          .from('chat_messages')
          .select('clip_data')
          .eq('id', messageId)
          .maybeSingle();

      if (messageData != null) {
        final clipData = messageData['clip_data'] as Map<String, dynamic>?;

        if (clipData != null) {
          final hypeReactions =
              List<String>.from(clipData['hype_reactions'] ?? []);

          if (hypeReactions.contains(currentUser.id)) {
            // Remove hype
            hypeReactions.remove(currentUser.id);
          } else {
            // Add hype
            hypeReactions.add(currentUser.id);
          }

          await SupabaseService.client.from('chat_messages').update({
            'clip_data': {
              ...clipData,
              'hype_reactions': hypeReactions,
            }
          }).eq('id', messageId);

          debugPrint('Toggled hype for clip $messageId');
        }
      }
    } catch (e) {
      debugPrint('Failed to toggle clip hype: $e');
      // Don't rethrow - hype is non-critical
    }
  }

  Future<void> loadMessages(String chatGroupId,
      {int limit = 50, DateTime? before}) async {
    final messages = await _repository.loadMessages(chatGroupId,
        limit: limit, before: before);
    state = await AsyncValue.guard(() async {
      final currentState = await future;
      final updatedMessages =
          Map<String, List<Message>>.from(currentState.chatMessages);
      updatedMessages[chatGroupId] = messages;
      return currentState.copyWith(chatMessages: updatedMessages);
    });
  }

  Future<void> syncMessages(String chatGroupId) async {
    // Delta sync moved to MessageService
    // Just reload messages
    await loadMessages(chatGroupId);
  }

  // Reactions
  Future<void> addReaction(
      String chatGroupId, String messageId, String reaction) async {
    await _repository.addReaction(chatGroupId, messageId, reaction);
  }

  // Polls
  Future<void> createPoll(
      String chatGroupId, String question, List<String> options) async {
    await _repository.createPoll(chatGroupId, question, options);
  }

  Future<void> votePoll(
      String chatGroupId, String pollId, String option, String voterId) async {
    await _repository.votePoll(chatGroupId, pollId, option, voterId);
  }

  // Media
  Future<String> uploadMedia(String filePath, String mediaType) async {
    return await _repository.uploadMedia(filePath, mediaType);
  }

  Future<void> loadMediaHistory(String chatGroupId) async {
    // Media history moved to MessageService
    // Keep empty for compatibility
    state = await AsyncValue.guard(() async {
      final currentState = await future;
      return currentState.copyWith(mediaHistory: []);
    });
  }

  // Group management
  Future<ChatGroup?> createGroup(String name, bool isPublic,
      {String? description}) async {
    final group =
        await _repository.createGroup(name, isPublic, description: description);
    state = await AsyncValue.guard(() async {
      final currentState = await future;
      final updatedGroups =
          Map<String, ChatGroup>.from(currentState.chatGroups);
      updatedGroups[group.id] = group;
      return currentState.copyWith(chatGroups: updatedGroups);
    });
    return group;
  }

  Future<void> joinGroup(String groupId) async {
    await _repository.joinGroup(groupId);
  }

  Future<void> leaveGroup(String groupId) async {
    await _repository.leaveGroup(groupId);
  }

  // Typing indicators
  Future<void> updateTypingIndicator(String chatGroupId, bool isTyping) async {
    // Cancel existing debounce timer
    _typingDebounceTimer?.cancel();

    if (_useSupabase && _typingChannel != null) {
      // Use Supabase realtime broadcast for typing indicators
      final currentUser = _authService.currentUser;
      if (currentUser == null) return;

      try {
        await _typingChannel!.sendBroadcastMessage(
          event: 'typing',
          payload: {
            'user_id': currentUser.id,
            'display_name': currentUser.userMetadata?['display_name'] ??
                currentUser.email ??
                'Unknown',
            'is_typing': isTyping,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          },
        );

        debugPrint(
            'DEBUG ChatNotifier: Sent typing indicator via Supabase - $isTyping');

        // Auto-clear typing indicator after 3 seconds
        if (isTyping) {
          _typingDebounceTimer = Timer(const Duration(seconds: 3), () {
            updateTypingIndicator(chatGroupId, false);
          });
        }
      } catch (e) {
        debugPrint(
            'DEBUG ChatNotifier: Failed to send typing via Supabase: $e');
        // Fallback to Firestore
        await _repository.updateTypingIndicator(chatGroupId, isTyping);
      }
    } else {
      // Fallback to original Firestore implementation
      await _repository.updateTypingIndicator(chatGroupId, isTyping);
    }
  }

  // Pinning
  Future<void> pinMessage(String chatGroupId, String messageId) async {
    await _repository.pinMessage(chatGroupId, messageId);
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
    // await _repository.deltaSync();
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

  // NOTE: markAsDelivered removed - Supabase inserts are immediate, no delivery tracking needed
}

final chatNotifierProvider =
    AutoDisposeAsyncNotifierProvider<ChatNotifier, ChatState>(
  () => ChatNotifier(),
);
