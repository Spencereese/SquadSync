import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:riverpod/riverpod.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show WidgetRef;
import 'package:squad_sync/domain/entities/message.dart';
import 'package:squad_sync/domain/repositories/chat_repository.dart';
import 'package:squad_sync/core/injection.dart';
import '../../services/message_service.dart';
import '../../services/auth_service_supabase.dart';
import '../../services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
/// - Real-time message streaming (Supabase + Firestore fallback)
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
    if (_useSupabase) {
      _startSupabaseMessagesStream(chatGroupId, chatType);
    } else {
      _startFirestoreMessagesStream(chatGroupId, chatType);
    }
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
              _useSupabase = false;
              _supabaseMessagesSubscription?.cancel();
              _supabaseMessagesSubscription = null;
              _startFirestoreMessagesStream(chatGroupId, chatType);
            },
          );

      await _initializeTypingChannel(chatGroupId);
      debugPrint('MessageNotifier: Supabase stream initialized');
    } catch (e) {
      debugPrint('MessageNotifier: Failed to start Supabase stream: $e');
      _useSupabase = false;
      _startFirestoreMessagesStream(chatGroupId, chatType);
    }
  }

  void _startFirestoreMessagesStream(String chatGroupId, ChatType chatType) {
    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      debugPrint('MessageNotifier: No authenticated user, skipping stream');
      return;
    }

    debugPrint(
        'MessageNotifier: Starting Firestore fallback stream for $chatGroupId');

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
            'MessageNotifier: 🎯 Stream emitted data type: ${data.runtimeType}');
        _onSupabaseMessagesSnapshot(data, chatGroupId);
      },
      onError: (error) => _onStreamError(error, chatGroupId, chatType),
      onDone: () => debugPrint('MessageNotifier: Messages stream done'),
    );
  }

  void _onSupabaseMessagesSnapshot(dynamic data, String chatGroupId) async {
    debugPrint('MessageNotifier: 🚀 ENTERED _onSupabaseMessagesSnapshot');
    debugPrint('MessageNotifier: 🚀 data type = ${data.runtimeType}');

    try {
      // CRITICAL: Accept dynamic and safely cast to avoid signature-level cast errors
      if (data is! List) {
        debugPrint(
            'MessageNotifier: ❌ Data is not a List: ${data.runtimeType}');
        return;
      }

      debugPrint('MessageNotifier: 🚀 Data is a List, casting...');
      final dataList = data as List;
      debugPrint(
          'MessageNotifier: 🔥 _onSupabaseMessagesSnapshot called with ${dataList.length} messages');
      _retryCount = 0;

      final remoteMessages = <Message>[];
      for (final item in dataList) {
        // Declare at outer scope so catch block can access
        Map<String, dynamic> messageData = {};

        try {
          debugPrint('MessageNotifier: 🔸 Item type: ${item.runtimeType}');

          // Safely cast each item to Map without deep validation
          if (item is! Map) {
            debugPrint(
                'MessageNotifier: ⚠️ Skipping non-Map item: ${item.runtimeType}');
            continue;
          }

          debugPrint(
              'MessageNotifier: 🔸 Converting raw map to messageData...');

          // Use dynamic map first, then convert manually field by field
          final rawMap = item as Map;

          debugPrint('MessageNotifier: 🔸 rawMap has ${rawMap.length} keys');

          // Manually copy each field to avoid any constructor issues
          for (final rawKey in rawMap.keys) {
            final key = rawKey.toString();
            final value = rawMap[rawKey];
            messageData[key] = value;

            // Debug problematic fields
            if (key == 'reactions' ||
                key == 'metadata' ||
                key == 'poll' ||
                key == 'clip_data') {
              debugPrint('MessageNotifier: 🔸 $key type: ${value.runtimeType}');
            }
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
                if (value == null ||
                    value is Map ||
                    (value is List && value.isEmpty)) {
                  // Safe to include
                  cleanedData[key] = value;
                }
              } else if (key == 'metadata' ||
                  key == 'clip_data' ||
                  key == 'poll') {
                if (value == null || value is Map) {
                  // Check for old schema in metadata
                  if (key == 'metadata' && value is Map) {
                    final meta = value as Map;
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

          // Debug cleaned data types before parsing
          debugPrint('MessageNotifier: Cleaned data for ${cleanedData['id']}:');
          debugPrint(
              '  - reactions: ${cleanedData['reactions']?.runtimeType ?? 'null'}');
          debugPrint(
              '  - metadata: ${cleanedData['metadata']?.runtimeType ?? 'null'}');
          debugPrint('  - poll: ${cleanedData['poll']?.runtimeType ?? 'null'}');
          debugPrint(
              '  - clip_data: ${cleanedData['clip_data']?.runtimeType ?? 'null'}');

          final message = Message.fromJson(cleanedData);
          debugPrint(
              'MessageNotifier: ✅ Successfully parsed message ${message.id}');
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
      debugPrint('MessageNotifier: _mergeMessages START');
      final currentState = await future;
      debugPrint('MessageNotifier: Got currentState, accessing messages map');
      final existingMessages = currentState.messages[chatGroupId] ?? [];
      debugPrint(
          'MessageNotifier: Got ${existingMessages.length} existing messages');

      final existingMap = {for (var msg in existingMessages) msg.id: msg};
      final mergedMessages = <Message>[];
      mergedMessages.addAll(existingMessages);

      for (final remoteMsg in remoteMessages) {
        final existingMsg = existingMap[remoteMsg.id];
        if (existingMsg == null) {
          mergedMessages.add(remoteMsg);
          debugPrint('MessageNotifier: Added new message ${remoteMsg.id}');
        } else {
          final index = mergedMessages.indexWhere((m) => m.id == remoteMsg.id);
          if (index != -1) {
            mergedMessages[index] = remoteMsg;
            debugPrint('MessageNotifier: Updated message ${remoteMsg.id}');
          }
        }
      }

      mergedMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      debugPrint('MessageNotifier: About to create newState');
      debugPrint(
          'MessageNotifier: currentState.messages type: ${currentState.messages.runtimeType}');
      debugPrint(
          'MessageNotifier: currentState.messages keys: ${currentState.messages.keys}');

      // Check if currentState.messages contains any Lists that should be Maps
      for (final entry in currentState.messages.entries) {
        debugPrint(
            'MessageNotifier: messages[$chatGroupId] type: ${entry.value.runtimeType}');
        debugPrint(
            'MessageNotifier: messages[$chatGroupId] length: ${entry.value.length}');
      }

      final newState = currentState.copyWith(
        messages: {
          ...currentState.messages,
          chatGroupId: mergedMessages,
        },
      );

      state = AsyncValue.data(newState);

      debugPrint(
          'MessageNotifier: Merged messages, total: ${mergedMessages.length}');
      debugPrint(
          'MessageNotifier: State updated - messages in state: ${newState.messages[chatGroupId]?.length ?? 0}');
    } catch (e, stackTrace) {
      debugPrint('MessageNotifier: ERROR in _mergeMessages: $e');
      debugPrint(
          'MessageNotifier: _mergeMessages stack trace: ${stackTrace.toString().split('\n').take(15).join('\n')}');
      rethrow;
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
      await supabase.removeChannel(_typingChannel!);
      _typingChannel = null;
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
        if (entry.value is List<Message>) {
          cleanMessages[entry.key] = entry.value as List<Message>;
        } else {
          debugPrint(
              'MessageNotifier: WARNING - Skipping corrupted entry ${entry.key}');
        }
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

      // Remove existing channel first to avoid duplicates
      if (_typingChannel != null) {
        try {
          await supabase.removeChannel(_typingChannel!);
        } catch (e) {
          debugPrint('⚠️ Warning: Failed to remove old typing channel: $e');
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
          .subscribe((status, error) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          debugPrint(
              'MessageNotifier: Typing channel subscribed for $chatGroupId');
        } else if (status == RealtimeSubscribeStatus.channelError) {
          debugPrint('❌ MessageNotifier: Typing channel error: $error');
          // Cleanup on error - don't let this block chat functionality
          try {
            supabase.removeChannel(_typingChannel!).then((_) {
              _typingChannel = null;
            }).catchError((e) {
              debugPrint('⚠️ Error removing failed typing channel: $e');
              _typingChannel = null;
            });
          } catch (e) {
            debugPrint('⚠️ Error in typing channel cleanup: $e');
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
}

// Backward compatibility alias (riverpod generates 'messageProvider')
final messageNotifierProvider =
    AsyncNotifierProvider<MessageNotifier, MessageState>(
  MessageNotifier.new,
);
