import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:riverpod/riverpod.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show WidgetRef;
import 'package:collection/collection.dart';
import 'package:squad_sync/domain/entities/message.dart';
import 'package:squad_sync/domain/repositories/chat_repository.dart';
import 'package:squad_sync/core/injection.dart';
import '../../services/message_service.dart';
import '../../services/auth_service_supabase.dart';
import '../../services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_notifier.dart' as cn;

/// State for MessageNotifier - handles core messaging operations
class MessageState {
  final Map<String, List<Message>> messages; // chatGroupId -> messages
  final Map<String, Set<String>> reactions; // messageId -> reactions
  final Map<String, Set<String>>
      typingUsers; // chatGroupId -> typing user display names
  final Map<String, DateTime> lastSyncTimestamps; // chatGroupId -> last sync
  final String? replyingToMessageId;
  final Message? replyToMessage;
  final bool isSyncing;
  final String? syncError;

  MessageState({
    required this.messages,
    required this.reactions,
    required this.typingUsers,
    required this.lastSyncTimestamps,
    this.replyingToMessageId,
    this.replyToMessage,
    this.isSyncing = false,
    this.syncError,
  });

  factory MessageState.initial() => MessageState(
        messages: {},
        reactions: {},
        typingUsers: {},
        lastSyncTimestamps: {},
      );

  MessageState copyWith({
    Map<String, List<Message>>? messages,
    Map<String, Set<String>>? reactions,
    Map<String, Set<String>>? typingUsers,
    Map<String, DateTime>? lastSyncTimestamps,
    String? replyingToMessageId,
    Message? replyToMessage,
    bool? isSyncing,
    String? syncError,
    bool clearReplyTo = false,
  }) {
    return MessageState(
      messages: messages ?? this.messages,
      reactions: reactions ?? this.reactions,
      typingUsers: typingUsers ?? this.typingUsers,
      lastSyncTimestamps: lastSyncTimestamps ?? this.lastSyncTimestamps,
      replyingToMessageId: clearReplyTo
          ? null
          : (replyingToMessageId ?? this.replyingToMessageId),
      replyToMessage:
          clearReplyTo ? null : (replyToMessage ?? this.replyToMessage),
      isSyncing: isSyncing ?? this.isSyncing,
      syncError: syncError ?? this.syncError,
    );
  }
}

/// MessageNotifier - Handles core messaging operations:
/// - Sending/receiving messages with optimistic updates
/// - Real-time message streaming (Supabase)
/// - Reactions on messages
/// - Typing indicators
/// - Reply functionality
class MessageNotifier extends AsyncNotifier<MessageState> {
  late final ChatRepository _repository;
  late final MessageService _messageService;
  final AuthServiceSupabase _authService = AuthServiceSupabase();

  // Real-time streaming
  StreamSubscription<List<Map<String, dynamic>>>? _messagesSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _supabaseMessagesSubscription;
  RealtimeChannel? _typingChannel;
  String? _currentChatGroupId;
  ChatType? _currentChatType;
  int _retryCount = 0;
  static const int _maxRetries = 3;
  Timer? _retryTimer;
  Timer? _typingDebounceTimer;
  final Set<String> _currentTypingUsers = {};
  bool _useSupabase = true;

  @override
  Future<MessageState> build() async {
    try {
      _repository = ref.read(chatRepositoryProvider);
      _messageService = MessageService();

      // Register cleanup callback
      ref.onDispose(() {
        _disposeMessagesStream();
      });

      return MessageState.initial();
    } catch (e) {
      rethrow;
    }
  }

  // ============================================================================
  // MESSAGE STREAMING
  // ============================================================================

  /// Initialize real-time message streaming for a chat group
  Future<void> initializeMessagesStream(
      String chatGroupId, ChatType chatType) async {
    await future;

    // AGGRESSIVE cleanup BEFORE creating new channels
    final currentChannelCount = SupabaseService.activeChannelCount;
    debugPrint(
        'MessageNotifier: 📊 Current channel count: $currentChannelCount');

    // Force cleanup if we have ANY orphaned channels
    if (currentChannelCount > 0) {
      debugPrint(
          'MessageNotifier: 🧹 Pre-emptive cleanup of $currentChannelCount channels');
      await _disposeMessagesStream(); // Clean up our own first
      await SupabaseService.cleanupOldChannels(); // Then global cleanup

      final afterCleanup = SupabaseService.activeChannelCount;
      debugPrint('MessageNotifier: ✅ After cleanup: $afterCleanup channels');
    }

    // Wait a moment for cleanup to complete
    await Future.delayed(const Duration(milliseconds: 100));

    if (_currentChatGroupId != chatGroupId || _currentChatType != chatType) {
      await _disposeMessagesStream();
      _currentChatGroupId = chatGroupId;
      _currentChatType = chatType;
      _retryCount = 0;
    }

    await _loadInitialMessages(chatGroupId);
    _startMessagesStream(chatGroupId, chatType);
  }

  Future<void> _loadInitialMessages(String chatGroupId) async {
    try {
      debugPrint('MessageNotifier: Loading initial messages for $chatGroupId');
      final cachedMessages =
          await _repository.loadMessages(chatGroupId, limit: 100);

      state = await AsyncValue.guard(() async {
        final currentState = await future;
        final updatedMessages =
            Map<String, List<Message>>.from(currentState.messages);
        updatedMessages[chatGroupId] = cachedMessages;
        return currentState.copyWith(messages: updatedMessages);
      });

      debugPrint(
          'MessageNotifier: Loaded ${cachedMessages.length} cached messages');
    } catch (e) {
      debugPrint('MessageNotifier: Error loading initial messages: $e');
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  void _startMessagesStream(String chatGroupId, ChatType chatType) {
    _startSupabaseMessagesStream(chatGroupId, chatType);
  }

  Future<void> _startSupabaseMessagesStream(
      String chatGroupId, ChatType chatType) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        debugPrint(
            'MessageNotifier: No authenticated user for Supabase stream');
        return;
      }

      debugPrint('MessageNotifier: Starting Supabase stream for $chatGroupId');

      _supabaseMessagesSubscription = supabase
          .from('chat_messages')
          .stream(primaryKey: ['id'])
          .eq('chat_id', chatGroupId)
          .order('timestamp', ascending: true)
          .limit(100)
          .listen(
            (data) {
              debugPrint(
                  'MessageNotifier: 🎯 Supabase stream emitted data type: ${data.runtimeType}');
              _onSupabaseMessagesSnapshot(data, chatGroupId);
            },
            onError: (error) {
              debugPrint('MessageNotifier: Supabase stream error: $error');

              // Handle RealtimeSubscribeException specifically
              if (error is RealtimeSubscribeException) {
                debugPrint(
                    'MessageNotifier: Channel error detected - ${error.status}');
                if (error.status == RealtimeSubscribeStatus.channelError) {
                  debugPrint(
                      'MessageNotifier: Channel limit likely exceeded, cleaning up');
                  SupabaseService.cleanupOldChannels();
                }
              }

              _useSupabase = false;
              _supabaseMessagesSubscription?.cancel();
              _supabaseMessagesSubscription = null;
              _startFallbackMessagesStream(chatGroupId, chatType);
            },
          );

      await _initializeTypingChannel(chatGroupId);
      debugPrint('MessageNotifier: Supabase stream initialized');
    } catch (e) {
      debugPrint('MessageNotifier: Failed to start Supabase stream: $e');
      _useSupabase = false;
      _startFallbackMessagesStream(chatGroupId, chatType);
    }
  }

  void _startFallbackMessagesStream(String chatGroupId, ChatType chatType) {
    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      debugPrint('MessageNotifier: No authenticated user, skipping stream');
      return;
    }

    debugPrint(
        'MessageNotifier: Starting Supabase fallback stream for $chatGroupId');

    final stream = SupabaseService.client
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('chat_id', chatGroupId)
        .order('timestamp', ascending: true)
        .limit(100)
        .map((messages) =>
            messages.where((msg) => msg['is_deleted'] != true).toList());

    _messagesSubscription = stream.listen(
      (data) {
        debugPrint(
            'MessageNotifier: 🎯 Stream emitted data type: ${data.runtimeType}, count: ${(data as List).length}');
        _onSupabaseMessagesSnapshot(data, chatGroupId);
      },
      onError: (error) => _onStreamError(error, chatGroupId, chatType),
      onDone: () => debugPrint('MessageNotifier: Messages stream done'),
    );
  }

  void _onSupabaseMessagesSnapshot(dynamic data, String chatGroupId) async {
    try {
      // Handle RealtimeSubscribeException that may be thrown as data
      if (data is RealtimeSubscribeException) {
        debugPrint(
            'MessageNotifier: RealtimeSubscribeException received: ${data.status}');
        if (data.status == RealtimeSubscribeStatus.channelError) {
          debugPrint(
              'MessageNotifier: Channel error - cleaning up and skipping');
          await SupabaseService.cleanupOldChannels();
        }
        return; // Don't process further, error already logged
      }

      // CRITICAL: Accept dynamic and safely cast to avoid signature-level cast errors
      if (data is! List) {
        if (kDebugMode) {
          debugPrint(
              'MessageNotifier: ❌ Data is not a List: ${data.runtimeType}');
        }
        return;
      }

      final dataList = data;
      _retryCount = 0;

      final remoteMessages = <Message>[];
      print(
          '📥 Processing ${dataList.length} messages from Supabase stream for chat $chatGroupId');
      for (final item in dataList) {
        // Declare at outer scope so catch block can access
        Map<String, dynamic> messageData = {};

        try {
          // Safely cast each item to Map without deep validation
          if (item is! Map) {
            if (kDebugMode) {
              debugPrint(
                  'MessageNotifier: ⚠️ Skipping non-Map item: ${item.runtimeType}');
            }
            continue;
          }

          // Use dynamic map first, then convert manually field by field
          final rawMap = item;

          // Manually copy each field to avoid any constructor issues
          for (final rawKey in rawMap.keys) {
            final key = rawKey.toString();
            final value = rawMap[rawKey];
            messageData[key] = value;
          }

          final cleanedData = <String, dynamic>{};

          // Copy only safe fields, skipping problematic JSONB columns entirely
          for (final entry in messageData.entries) {
            final key = entry.key;
            final value = entry.value;

            // Skip all JSONB fields that could cause type issues
            if (key == 'metadata' ||
                key == 'reactions' ||
                key == 'clip_data' ||
                key == 'clipData' ||
                key == 'poll' ||
                key == 'ai_response') {
              // Only include these fields if they're the correct type
              if (key == 'reactions') {
                // Always include reactions regardless of type - let Message.fromJson handle it
                cleanedData[key] = value;
              } else if (key == 'metadata' ||
                  key == 'clip_data' ||
                  key == 'poll') {
                if (value == null || value is Map) {
                  // Check for old schema in metadata
                  if (key == 'metadata' && value is Map) {
                    final meta = value;
                    if (!meta.containsKey('photos') &&
                        !meta.containsKey('videos') &&
                        !meta.containsKey('audio')) {
                      cleanedData[key] = value;
                    }
                  } else {
                    cleanedData[key] = value;
                  }
                }
              }
              // Skip if wrong type
              continue;
            }

            // Copy all other fields as-is
            cleanedData[key] = value;
          }

          final message = Message.fromJson(cleanedData);

          // Log photo messages specifically
          if (message.messageType == MessageType.image ||
              message.mediaUrl != null) {
            print(
                '📸 Photo message parsed: id=${message.id}, messageType=${message.messageType}, mediaUrl=${message.mediaUrl}, mediaType=${message.mediaType}');
          }

          remoteMessages.add(message);
        } catch (e, stackTrace) {
          debugPrint(
              'MessageNotifier: ❌ Failed to parse message ${messageData['id']}: $e');
          debugPrint('MessageNotifier: Keys: ${messageData.keys.join(', ')}');

          // Show types of all JSONB fields to identify the culprit
          for (final key in [
            'metadata',
            'reactions',
            'clip_data',
            'poll',
            'ai_response'
          ]) {
            final value = messageData[key];
            if (value != null) {
              debugPrint(
                  'MessageNotifier: $key type=${value.runtimeType}, value=${value.toString().substring(0, value.toString().length > 100 ? 100 : value.toString().length)}');
            }
          }

          debugPrint(
              'MessageNotifier: Stack trace: ${stackTrace.toString().split('\n').take(5).join('\n')}');
          // Skip this message and continue with others
          continue;
        }
      }

      await _mergeMessages(chatGroupId, remoteMessages);
    } on RealtimeSubscribeException catch (e, stackTrace) {
      // Handle channel subscription errors gracefully without crashing
      debugPrint(
          'MessageNotifier: RealtimeSubscribeException caught: ${e.status}');
      debugPrint('MessageNotifier: Details: ${e.details}');

      if (e.status == RealtimeSubscribeStatus.channelError) {
        debugPrint('MessageNotifier: Channel error - attempting cleanup');
        await SupabaseService.cleanupOldChannels();
      }

      // Don't set error state for channel errors - just log and continue
      debugPrint('MessageNotifier: Continuing without throwing exception');
    } catch (e, stackTrace) {
      debugPrint('MessageNotifier: Error processing Supabase messages: $e');
      debugPrint(
          'MessageNotifier: Error stack trace: ${stackTrace.toString().split('\n').take(10).join('\n')}');
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> _mergeMessages(
      String chatGroupId, List<Message> remoteMessages) async {
    try {
      // CRITICAL: Don't use await future if state is error - access state directly
      MessageState currentState;
      if (state.hasValue) {
        currentState = state.requireValue;
      } else if (state.isLoading && state.hasValue) {
        currentState = state.requireValue;
      } else {
        // State is error or null - create fresh state with just these messages
        debugPrint(
            'MessageNotifier: State is error/null, creating fresh state');
        final newState = MessageState(
          messages: {chatGroupId: remoteMessages},
          reactions: {},
          typingUsers: {},
          lastSyncTimestamps: {},
        );
        state = AsyncValue.data(newState);
        return;
      }

      final existingMessages = currentState.messages[chatGroupId] ?? [];

      // CRITICAL: Deduplicate messages to prevent unnecessary rebuilds
      // Check if remote messages are actually different from existing ones
      if (existingMessages.length == remoteMessages.length) {
        final existingIds = existingMessages.map((m) => m.id).toSet();
        final remoteIds = remoteMessages.map((m) => m.id).toSet();

        if (existingIds.difference(remoteIds).isEmpty &&
            remoteIds.difference(existingIds).isEmpty) {
          // Same messages, check if any actually changed
          bool hasChanges = false;
          final existingMap = {for (var msg in existingMessages) msg.id: msg};

          const deepEq = DeepCollectionEquality();
          for (final remoteMsg in remoteMessages) {
            final existingMsg = existingMap[remoteMsg.id];
            if (existingMsg != null) {
              // Compare reactions and other mutable fields using deep equality
              if (!deepEq.equals(existingMsg.reactions, remoteMsg.reactions) ||
                  existingMsg.text != remoteMsg.text) {
                hasChanges = true;
                break;
              }
            }
          }

          if (!hasChanges) {
            // No actual changes - skip merge to prevent unnecessary rebuilds
            return;
          }
        }
      }

      final existingMap = {for (var msg in existingMessages) msg.id: msg};
      final mergedMessages = <Message>[];
      mergedMessages.addAll(existingMessages);

      int newCount = 0;
      int updatedCount = 0;

      const deepEq = DeepCollectionEquality();
      for (final remoteMsg in remoteMessages) {
        final existingMsg = existingMap[remoteMsg.id];
        if (existingMsg == null) {
          mergedMessages.add(remoteMsg);
          newCount++;
        } else {
          // Only count as updated if reactions or text actually changed (deep equality)
          if (!deepEq.equals(existingMsg.reactions, remoteMsg.reactions) ||
              existingMsg.text != remoteMsg.text) {
            final index =
                mergedMessages.indexWhere((m) => m.id == remoteMsg.id);
            if (index != -1) {
              mergedMessages[index] = remoteMsg;
              updatedCount++;
            }
          }
        }
      }

      mergedMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // CRITICAL: Only update state if there are actual new or updated messages
      if (newCount == 0 && updatedCount == 0) {
        // No changes - skip state update to prevent unnecessary rebuilds
        print('⏭️ Skipping state update - no new or updated messages');
        return;
      }

      if (newCount > 0 || updatedCount > 0) {
        debugPrint(
            'MessageNotifier: Merging $newCount new, $updatedCount updated messages');
        print(
            '✅ STATE UPDATE: $newCount new messages, $updatedCount updated messages for chat $chatGroupId');

        // Update the chat group's lastActivity timestamp when new messages arrive
        if (newCount > 0 && remoteMessages.isNotEmpty) {
          _updateChatGroupLastActivity(chatGroupId, remoteMessages);
        }
      }

      final newState = currentState.copyWith(
        messages: {
          ...currentState.messages,
          chatGroupId: mergedMessages,
        },
      );

      state = AsyncValue.data(newState);
    } catch (e, stackTrace) {
      debugPrint('MessageNotifier: ERROR in _mergeMessages: $e');
      debugPrint(
          'MessageNotifier: _mergeMessages stack trace: ${stackTrace.toString().split('\n').take(15).join('\n')}');

      // DON'T rethrow - this causes RealtimeSubscribeException wrapping
      // Instead, just log and create a fresh state with remote messages
      debugPrint(
          'MessageNotifier: Recovering from error by creating fresh state');
      try {
        final newState = MessageState(
          messages: {chatGroupId: remoteMessages},
          reactions: {},
          typingUsers: {},
          lastSyncTimestamps: {},
        );
        state = AsyncValue.data(newState);
      } catch (recoveryError) {
        debugPrint('MessageNotifier: Failed to recover: $recoveryError');
        // Only NOW set error state as last resort
        state = AsyncValue.error(e, stackTrace);
      }
    }
  }

  void _onStreamError(Object error, String chatGroupId, ChatType chatType) {
    debugPrint(
        'MessageNotifier: Stream error: $error, retry count: $_retryCount');

    if (_retryCount < _maxRetries) {
      _retryCount++;
      final delay = Duration(seconds: 1 << (_retryCount - 1));
      debugPrint('MessageNotifier: Retrying in ${delay.inSeconds} seconds');

      _retryTimer?.cancel();
      _retryTimer = Timer(delay, () {
        if (_currentChatGroupId == chatGroupId &&
            _currentChatType == chatType) {
          _startMessagesStream(chatGroupId, chatType);
        }
      });
    } else {
      debugPrint('MessageNotifier: Max retries reached');
      state = AsyncValue.error(error, StackTrace.current);
    }
  }

  Future<void> _disposeMessagesStream() async {
    debugPrint('MessageNotifier: Disposing messages stream');
    await _messagesSubscription?.cancel();
    _messagesSubscription = null;
    await _supabaseMessagesSubscription?.cancel();
    _supabaseMessagesSubscription = null;

    if (_typingChannel != null) {
      await SupabaseService.safeRemoveChannel(_typingChannel!);
      _typingChannel = null;
    }

    // CRITICAL: Clean up orphaned channels created by .stream()
    // These aren't tracked by subscriptions and cause channelratelimitreached
    try {
      final channels = supabase.getChannels();
      debugPrint(
          'MessageNotifier: Cleaning up ${channels.length} orphaned channels');
      for (final channel in channels) {
        await SupabaseService.safeRemoveChannel(channel);
      }
    } catch (e) {
      debugPrint('MessageNotifier: Error cleaning orphaned channels: $e');
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
  // MESSAGE OPERATIONS
  // ============================================================================

  /// Send a message with optimistic updates
  Future<void> sendMessage(
    WidgetRef ref,
    String chatGroupId,
    String text,
    MessageType messageType,
    ChatType chatType, {
    String? mediaUrl,
    String? mediaType,
    String? replyTo,
    String? mediaFilePath,
  }) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) throw 'User not authenticated';

      // Create optimistic message
      final optimisticMessage = Message.create(
        senderId: currentUser.id,
        text: text,
        messageType: messageType,
        mediaUrl: mediaUrl,
        mediaType: mediaType,
        replyTo: replyTo,
      );

      // Add to UI immediately
      await _addOptimisticMessage(chatGroupId, optimisticMessage);

      // Send via MessageService
      final result = await _messageService.sendMessage(
        ref,
        senderUid: currentUser.id,
        text: text,
        chatGroupId: chatGroupId,
        chatType: chatType,
        mediaFilePath: mediaFilePath,
        mediaType: mediaType,
        replyTo: replyTo,
      );

      if (result.success) {
        await _replaceOptimisticMessage(
            chatGroupId, optimisticMessage.id, result.messageId!);
      } else {
        await _removeOptimisticMessage(chatGroupId, optimisticMessage.id);
        throw result.errorMessage ?? 'Failed to send message';
      }
    } catch (e) {
      debugPrint('MessageNotifier: Send message failed: $e');
      rethrow;
    }
  }

  Future<void> _addOptimisticMessage(
      String chatGroupId, Message message) async {
    try {
      debugPrint('MessageNotifier: _addOptimisticMessage START');
      final currentState = await future;
      debugPrint('MessageNotifier: Got currentState');
      debugPrint(
          'MessageNotifier: currentState.messages type: ${currentState.messages.runtimeType}');
      debugPrint(
          'MessageNotifier: currentState.messages keys: ${currentState.messages.keys}');

      // Defensive: Check if messages map has correct types
      final cleanMessages = <String, List<Message>>{};
      for (final entry in currentState.messages.entries) {
        debugPrint(
            'MessageNotifier: Entry key=${entry.key}, value type=${entry.value.runtimeType}');
        // Type is guaranteed by state definition
        cleanMessages[entry.key] = entry.value;
      }

      final messages = List<Message>.from(cleanMessages[chatGroupId] ?? []);
      messages.add(message); // Add to end (newest at bottom)
      cleanMessages[chatGroupId] = messages;

      state = AsyncValue.data(currentState.copyWith(messages: cleanMessages));
      debugPrint('MessageNotifier: _addOptimisticMessage SUCCESS');
    } catch (e, stackTrace) {
      debugPrint('MessageNotifier: ERROR in _addOptimisticMessage: $e');
      debugPrint(
          'MessageNotifier: Stack trace: ${stackTrace.toString().split('\n').take(10).join('\n')}');
      rethrow;
    }
  }

  Future<void> _replaceOptimisticMessage(
      String chatGroupId, String optimisticId, String finalId) async {
    final currentState = await future;
    final updatedMessages =
        Map<String, List<Message>>.from(currentState.messages);
    final messages = List<Message>.from(updatedMessages[chatGroupId] ?? []);

    final index = messages.indexWhere((m) => m.id == optimisticId);
    if (index != -1) {
      messages[index] = messages[index].copyWith(id: finalId);
      updatedMessages[chatGroupId] = messages;
      state = AsyncValue.data(currentState.copyWith(messages: updatedMessages));
    }
  }

  Future<void> _removeOptimisticMessage(
      String chatGroupId, String messageId) async {
    final currentState = await future;
    final updatedMessages =
        Map<String, List<Message>>.from(currentState.messages);
    final messages = List<Message>.from(updatedMessages[chatGroupId] ?? []);
    messages.removeWhere((m) => m.id == messageId);
    updatedMessages[chatGroupId] = messages;

    state = AsyncValue.data(currentState.copyWith(messages: updatedMessages));
  }

  // ============================================================================
  // REACTIONS
  // ============================================================================

  Future<void> addReaction(
      String chatGroupId, String messageId, String reaction) async {
    try {
      await _repository.addReaction(chatGroupId, messageId, reaction);

      state = await AsyncValue.guard(() async {
        final currentState = await future;
        final updatedReactions =
            Map<String, Set<String>>.from(currentState.reactions);
        final reactions = Set<String>.from(updatedReactions[messageId] ?? {});
        reactions.add(reaction);
        updatedReactions[messageId] = reactions;
        return currentState.copyWith(reactions: updatedReactions);
      });
    } catch (e) {
      debugPrint('MessageNotifier: Failed to add reaction: $e');
      rethrow;
    }
  }

  Future<void> removeReaction(
      String chatGroupId, String messageId, String reaction) async {
    try {
      await _repository.removeReaction(chatGroupId, messageId, reaction);

      state = await AsyncValue.guard(() async {
        final currentState = await future;
        final updatedReactions =
            Map<String, Set<String>>.from(currentState.reactions);
        final reactions = Set<String>.from(updatedReactions[messageId] ?? {});
        reactions.remove(reaction);
        updatedReactions[messageId] = reactions;
        return currentState.copyWith(reactions: updatedReactions);
      });
    } catch (e) {
      debugPrint('MessageNotifier: Failed to remove reaction: $e');
      rethrow;
    }
  }

  // ============================================================================
  // TYPING INDICATORS
  // ============================================================================

  Future<void> _initializeTypingChannel(String chatGroupId) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        debugPrint('⚠️ MessageNotifier: No user, skipping typing channel');
        return;
      }

      // Proactive cleanup if approaching channel limit
      if (SupabaseService.isApproachingChannelLimit) {
        debugPrint(
            'MessageNotifier: ⚠️ Approaching channel limit, cleaning up');
        await SupabaseService.cleanupOldChannels();
      }

      // Remove existing channel first to avoid duplicates
      if (_typingChannel != null) {
        try {
          await SupabaseService.safeRemoveChannel(_typingChannel!);
          debugPrint('🧹 Removed previous typing channel');
        } catch (e) {
          debugPrint('⚠️ Error removing typing channel: $e');
        }
        _typingChannel = null;
      }

      _typingChannel = supabase.channel('typing:$chatGroupId');

      _typingChannel!
          .onBroadcast(
        event: 'typing',
        callback: (payload) {
          final userId = payload['user_id'] as String?;
          final isTyping = payload['is_typing'] as bool? ?? false;
          final displayName =
              payload['display_name'] as String? ?? userId ?? 'Unknown';

          debugPrint('MessageNotifier: Typing event - $displayName: $isTyping');

          if (userId == currentUser.id) return;

          if (isTyping) {
            _currentTypingUsers.add(displayName);
          } else {
            _currentTypingUsers.remove(displayName);
          }

          _updateTypingIndicators(chatGroupId);
        },
      )
          .subscribe((status, error) async {
        if (status == RealtimeSubscribeStatus.subscribed) {
          debugPrint(
              'MessageNotifier: Typing channel subscribed for $chatGroupId');
        } else if (status == RealtimeSubscribeStatus.channelError) {
          debugPrint('❌ MessageNotifier: Typing channel error: $error');
          // Cleanup on error - don't let this block chat functionality
          if (_typingChannel != null) {
            await SupabaseService.safeRemoveChannel(_typingChannel!);
            _typingChannel = null;
          }
        }
      });

      debugPrint(
          'MessageNotifier: Typing channel initialized for $chatGroupId');
    } catch (e) {
      debugPrint('⚠️ MessageNotifier: Failed to initialize typing channel: $e');
      // Don't throw - typing indicators are nice-to-have, not critical
      _typingChannel = null;
    }
  }

  Future<void> _updateTypingIndicators(String chatGroupId) async {
    state = await AsyncValue.guard(() async {
      final currentState = await future;
      final updatedIndicators =
          Map<String, Set<String>>.from(currentState.typingUsers);
      updatedIndicators[chatGroupId] = Set<String>.from(_currentTypingUsers);
      return currentState.copyWith(typingUsers: updatedIndicators);
    });
  }

  Future<void> updateTypingIndicator(String chatGroupId, bool isTyping) async {
    _typingDebounceTimer?.cancel();

    if (_useSupabase && _typingChannel != null) {
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

        debugPrint('MessageNotifier: Sent typing indicator - $isTyping');

        if (isTyping) {
          _typingDebounceTimer = Timer(const Duration(seconds: 3), () {
            updateTypingIndicator(chatGroupId, false);
          });
        }
      } catch (e) {
        debugPrint('MessageNotifier: Failed to send typing indicator: $e');
        await _repository.updateTypingIndicator(chatGroupId, isTyping);
      }
    } else {
      await _repository.updateTypingIndicator(chatGroupId, isTyping);
    }
  }

  // ============================================================================
  // REPLY FUNCTIONALITY
  // ============================================================================

  Future<void> setReplyingToMessage(String? messageId) async {
    state = await AsyncValue.guard(() async {
      final currentState = await future;

      Message? replyToMessage;
      if (messageId != null && _currentChatGroupId != null) {
        final messages = currentState.messages[_currentChatGroupId] ?? [];
        try {
          replyToMessage =
              messages.firstWhere((message) => message.id == messageId);
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
      return currentState.copyWith(clearReplyTo: true);
    });
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  List<Message> getMessagesForGroup(String chatGroupId) {
    return state.maybeWhen(
      data: (data) => data.messages[chatGroupId] ?? [],
      orElse: () => [],
    );
  }

  Set<String> getTypingUsers(String chatGroupId) {
    return state.maybeWhen(
      data: (data) => data.typingUsers[chatGroupId] ?? {},
      orElse: () => {},
    );
  }

  bool isUserTyping(String chatGroupId, String userId) {
    return getTypingUsers(chatGroupId).contains(userId);
  }

  /// Update chat group's lastActivity timestamp when new messages arrive
  void _updateChatGroupLastActivity(
      String chatGroupId, List<Message> messages) {
    try {
      if (messages.isEmpty) return;

      // Get the most recent message timestamp
      final latestMessage =
          messages.reduce((a, b) => a.timestamp.isAfter(b.timestamp) ? a : b);

      // Update the ChatNotifier's state with new lastActivity
      final chatNotifier = ref.read(cn.chatNotifierProvider.notifier);
      chatNotifier.updateGroupLastActivity(
          chatGroupId, latestMessage.timestamp);
    } catch (e) {
      debugPrint('MessageNotifier: Failed to update group lastActivity: $e');
    }
  }
}

// Backward compatibility alias (riverpod generates 'messageProvider')
final messageNotifierProvider =
    AsyncNotifierProvider<MessageNotifier, MessageState>(
  MessageNotifier.new,
);
