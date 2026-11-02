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
import '../../core/realtime_subscribe.dart';
import '../../core/chat_list_loader.dart';
import '../../core/chat_history.dart';
import '../../core/chat_messages.dart';
import '../../core/chat_send.dart';
import '../../core/chat_surface.dart';
import 'package:uuid/uuid.dart';
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
  MessageNotifier()
      : _messageServiceOverride = null,
        _testingUserId = null;

  /// Unit tests inject the send service and the signed-in id so a bubble
  /// can move through sending / sent / failed without a live Supabase client.
  @visibleForTesting
  MessageNotifier.testing({
    MessageService? messageService,
    String? currentUserId,
  })  : _messageServiceOverride = messageService,
        _testingUserId = currentUserId;

  late final ChatRepository _repository;
  late final MessageService _messageService;
  final MessageService? _messageServiceOverride;
  final String? _testingUserId;
  final AuthServiceSupabase _authService = AuthServiceSupabase();

  // Real-time streaming
  StreamSubscription<List<Map<String, dynamic>>>? _messagesSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _supabaseMessagesSubscription;
  RealtimeChannel? _typingChannel;
  String? _currentChatGroupId;
  ChatType? _currentChatType;
  int _retryCount = 0;
  int _messagesChannelErrorRetries = 0;
  int _typingChannelErrorRetries = 0;
  bool _subscribing = false;
  static const int _maxRetries = 3;
  Timer? _retryTimer;
  Timer? _fallbackPollTimer;
  Timer? _typingDebounceTimer;
  final Set<String> _currentTypingUsers = {};
  bool _useSupabase = true;
  final Set<String> _noOlderHistory = {};
  final Set<String> _olderPageInFlight = {};

  @override
  Future<MessageState> build() async {
    try {
      _repository = ref.read(chatRepositoryProvider);
      _messageService = _messageServiceOverride ?? MessageService();

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

    final session = await SupabaseService.ensureFreshSession();
    if (session == null) {
      debugPrint('MessageNotifier: no valid session; skip realtime');
      return;
    }

    if (shouldNukeAllRealtimeChannels(SupabaseService.activeChannelCount)) {
      debugPrint(
          'MessageNotifier: near channel cap (${SupabaseService.activeChannelCount}); scoped cleanup');
      await _disposeOwnRealtime();
    }

    if (_currentChatGroupId != chatGroupId || _currentChatType != chatType) {
      await _disposeOwnRealtime();
      _currentChatGroupId = chatGroupId;
      _currentChatType = chatType;
      _retryCount = 0;
      _messagesChannelErrorRetries = 0;
      _typingChannelErrorRetries = 0;
    }

    await _loadInitialMessages(chatGroupId);
    await _startSupabaseMessagesStream(chatGroupId, chatType);
  }

  Future<void> _loadInitialMessages(String chatGroupId) async {
    debugPrint('MessageNotifier: Loading initial messages for $chatGroupId');
    final loaded = await loadChatList(
      fetch: () =>
          _repository.loadMessages(chatGroupId, limit: kOpenChatPageSize),
    );
    if (loaded.phase == ChatSurfacePhase.error) {
      debugPrint(
          'MessageNotifier: Error loading initial messages: ${loaded.error}');
      state = AsyncValue.error(
        loaded.error ?? Exception("Couldn't load chat"),
        StackTrace.current,
      );
      return;
    }

    state = await AsyncValue.guard(() async {
      final currentState = await future;
      final updatedMessages =
          Map<String, List<Message>>.from(currentState.messages);
      final existing = updatedMessages[chatGroupId] ?? const <Message>[];
      // Keep a failed/sending bubble if this reload's page does not echo it.
      updatedMessages[chatGroupId] = mergeRemoteEcho(
        local: existing,
        remote: loaded.items,
      );
      return currentState.copyWith(messages: updatedMessages);
    });

    if (loaded.items.length < kOpenChatPageSize) {
      _noOlderHistory.add(chatGroupId);
    } else {
      _noOlderHistory.remove(chatGroupId);
    }

    debugPrint(
        'MessageNotifier: Loaded ${loaded.items.length} newest messages');
  }

  /// Scroll-up page. Older rows join the same list. Returns whether another
  /// older page may exist. Empty thread does not count as "no more".
  Future<bool> loadOlderMessages(String chatGroupId) async {
    if (_noOlderHistory.contains(chatGroupId) ||
        _olderPageInFlight.contains(chatGroupId)) {
      return !_noOlderHistory.contains(chatGroupId);
    }
    final current = _readMessageState();
    final existing = sortThread(current?.messages[chatGroupId] ?? const []);
    if (existing.isEmpty) return true;

    _olderPageInFlight.add(chatGroupId);
    try {
      final cursor = existing.first;
      final page = await _repository.loadMessages(
        chatGroupId,
        limit: kOlderChatPageSize,
        before: cursor.timestamp,
        beforeId: cursor.id,
      );
      final stitch = stitchOlderPage(
        loaded: existing,
        fetched: page,
        limit: kOlderChatPageSize,
      );
      if (stitch.added == 0) {
        _noOlderHistory.add(chatGroupId);
        return false;
      }
      await _writeThread(chatGroupId, (_) => stitch.messages);
      if (!stitch.hasMore) _noOlderHistory.add(chatGroupId);
      return stitch.hasMore;
    } catch (e) {
      debugPrint('MessageNotifier: older page failed: $e');
      return true;
    } finally {
      _olderPageInFlight.remove(chatGroupId);
    }
  }

  Future<void> _startSupabaseMessagesStream(
      String chatGroupId, ChatType chatType) async {
    if (_subscribing) return;
    _subscribing = true;
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        debugPrint(
            'MessageNotifier: No authenticated user for Supabase stream');
        return;
      }

      await _supabaseMessagesSubscription?.cancel();
      _supabaseMessagesSubscription = null;

      debugPrint('MessageNotifier: Starting Supabase stream for $chatGroupId');

      _supabaseMessagesSubscription = supabase
          .from('chat_messages')
          .stream(primaryKey: ['id'])
          .eq('chat_id', chatGroupId)
          .order('created_at', ascending: false)
          .limit(kOpenChatPageSize)
          .listen(
            (data) {
              debugPrint(
                  'MessageNotifier: 🎯 Supabase stream emitted data type: ${data.runtimeType}');
              _onSupabaseMessagesSnapshot(data, chatGroupId);
            },
            onError: (error) {
              debugPrint('MessageNotifier: Supabase stream error: $error');
              _recoverDeadMessagesChannel(error, chatGroupId, chatType);
            },
          );

      await _initializeTypingChannel(chatGroupId);
      debugPrint('MessageNotifier: Supabase stream initialized');
    } catch (e) {
      debugPrint('MessageNotifier: Failed to start Supabase stream: $e');
      _subscribing = false;
      await _recoverDeadMessagesChannel(e, chatGroupId, chatType);
    } finally {
      _subscribing = false;
    }
  }

  Future<void> _recoverDeadMessagesChannel(
    Object error,
    String chatGroupId,
    ChatType chatType,
  ) async {
    final dead = error is RealtimeSubscribeException &&
        isDeadRealtimeStatus(error.status);
    if (!dead && error is! RealtimeSubscribeException) {
      debugPrint('MessageNotifier: non-channel stream error: $error');
    }
    await _disposeOwnRealtime();
    if (!shouldResubscribeAfterChannelError(_messagesChannelErrorRetries)) {
      debugPrint(
          'MessageNotifier: channel dead after $kMaxRealtimeResubscribe resubscribe; degraded REST poll');
      _startFallbackMessagesPoll(chatGroupId);
      return;
    }
    _messagesChannelErrorRetries++;
    debugPrint(
        'MessageNotifier: resubscribing live channel (attempt $_messagesChannelErrorRetries)');
    await _startSupabaseMessagesStream(chatGroupId, chatType);
  }

  void _startFallbackMessagesPoll(String chatGroupId) {
    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      debugPrint('MessageNotifier: No authenticated user, skipping REST poll');
      return;
    }

    debugPrint('MessageNotifier: Starting degraded REST poll for $chatGroupId');
    _fallbackPollTimer?.cancel();
    Future<void> poll() async {
      try {
        final page = await _repository.loadMessages(chatGroupId,
            limit: kOpenChatPageSize);
        debugPrint('MessageNotifier: REST poll got ${page.length}');
        await _mergeMessages(chatGroupId, page);
      } catch (e) {
        debugPrint('MessageNotifier: REST poll failed: $e');
      }
    }

    poll();
    _fallbackPollTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      poll();
    });
  }

  void _onSupabaseMessagesSnapshot(dynamic data, String chatGroupId) async {
    try {
      // Handle RealtimeSubscribeException that may be thrown as data
      if (data is RealtimeSubscribeException) {
        debugPrint(
            'MessageNotifier: RealtimeSubscribeException received: ${data.status}');
        if (isDeadRealtimeStatus(data.status)) {
          final type = _currentChatType;
          if (type != null) {
            await _recoverDeadMessagesChannel(data, chatGroupId, type);
          }
        }
        return;
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
          for (final rawKey in rawMap.keys) {
            final key = rawKey.toString();
            final value = rawMap[rawKey];
            messageData[key] = value;
          }

          final message = parseLiveChatMessage(
            messageData,
            expectedChatId: chatGroupId,
          );
          if (message == null) continue;

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

      if (isDeadRealtimeStatus(e.status) && _currentChatGroupId != null) {
        await _recoverDeadMessagesChannel(
          e,
          _currentChatGroupId!,
          _currentChatType ?? ChatType.userGroup,
        );
      }
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
      final mergedMessages = mergeRemoteEcho(
        local: existingMessages,
        remote: remoteMessages,
      );
      if (sameThreadSnapshot(existingMessages, mergedMessages)) {
        return;
      }

      final existingIds = existingMessages.map((m) => m.id).toSet();
      final newCount =
          remoteMessages.where((m) => !existingIds.contains(m.id)).length;
      debugPrint(
          'MessageNotifier: Merged echo for $chatGroupId ($newCount new)');
      if (newCount > 0 && remoteMessages.isNotEmpty) {
        _updateChatGroupLastActivity(chatGroupId, remoteMessages);
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
        final existing = state.hasValue
            ? (state.requireValue.messages[chatGroupId] ?? const <Message>[])
            : const <Message>[];
        final merged = mergeRemoteEcho(
          local: existing,
          remote: remoteMessages,
        );
        final base = state.hasValue
            ? state.requireValue
            : MessageState(
                messages: const {},
                reactions: const {},
                typingUsers: const {},
                lastSyncTimestamps: const {},
              );
        state = AsyncValue.data(base.copyWith(
          messages: {
            ...base.messages,
            chatGroupId: merged,
          },
        ));
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
          _startSupabaseMessagesStream(chatGroupId, chatType);
        }
      });
    } else {
      debugPrint('MessageNotifier: Max retries reached');
      state = AsyncValue.error(error, StackTrace.current);
    }
  }

  Future<void> _disposeOwnRealtime() async {
    _fallbackPollTimer?.cancel();
    _fallbackPollTimer = null;
    await _messagesSubscription?.cancel();
    _messagesSubscription = null;
    await _supabaseMessagesSubscription?.cancel();
    _supabaseMessagesSubscription = null;
    if (_typingChannel != null) {
      await SupabaseService.safeRemoveChannel(_typingChannel!);
      _typingChannel = null;
    }
  }

  Future<void> _disposeMessagesStream() async {
    debugPrint('MessageNotifier: Disposing messages stream');
    await _disposeOwnRealtime();

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

  /// Send a message. One client id is the server row id. The bubble stays
  /// in the list: sending, then sent only after the insert confirms, or
  /// failed with the same id so tap-to-retry can run again.
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
    final senderId = _testingUserId ?? _authService.currentUser?.id;
    if (senderId == null) throw 'User not authenticated';

    final clientId = const Uuid().v4();
    final optimistic = Message(
      id: clientId,
      senderId: senderId,
      text: text,
      timestamp: DateTime.now(),
      messageType: messageType,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      replyTo: replyTo,
      reactions: const {},
      isEdited: false,
      isDeleted: false,
    );
    await _writeThread(
      chatGroupId,
      (messages) => appendSending(messages, optimistic),
    );

    try {
      final result = await _messageService.sendMessage(
        ref,
        senderUid: senderId,
        text: text,
        chatGroupId: chatGroupId,
        chatType: chatType,
        mediaFilePath: mediaFilePath,
        mediaType: mediaType,
        replyTo: replyTo,
        clientMessageId: clientId,
        imageUrl: messageType == MessageType.image ? mediaUrl : null,
        videoUrl: messageType == MessageType.video ? mediaUrl : null,
        audioUrl: messageType == MessageType.audio ||
                messageType == MessageType.voiceNote
            ? mediaUrl
            : null,
      );
      await _applyServerResult(chatGroupId, clientId, result);
    } catch (e) {
      debugPrint('MessageNotifier: Send message failed: $e');
      await _writeThread(
        chatGroupId,
        (messages) => applySendResult(
          messages: messages,
          clientId: clientId,
          confirmed: false,
        ),
      );
    }
  }

  /// Tap-to-retry. Same client id, so a server row that already landed
  /// comes back as a duplicate-key confirm instead of a second bubble.
  Future<void> retryFailedMessage(
    WidgetRef ref,
    String chatGroupId,
    String messageId,
    ChatType chatType,
  ) async {
    final current = _readMessageState();
    if (current == null) return;
    final existing = messageById(
      current.messages[chatGroupId] ?? const [],
      messageId,
    );
    if (existing == null ||
        outboundDeliveryOf(existing) != OutboundDelivery.failed) {
      return;
    }

    await _writeThread(
      chatGroupId,
      (messages) => markRetrying(messages: messages, clientId: messageId),
    );

    try {
      final result = await _messageService.sendMessage(
        ref,
        senderUid: existing.senderId,
        text: existing.text,
        chatGroupId: chatGroupId,
        chatType: chatType,
        replyTo: existing.replyTo,
        mediaType: existing.mediaType,
        clientMessageId: existing.id,
        imageUrl:
            existing.messageType == MessageType.image ? existing.mediaUrl : null,
        videoUrl:
            existing.messageType == MessageType.video ? existing.mediaUrl : null,
        audioUrl: existing.messageType == MessageType.audio ||
                existing.messageType == MessageType.voiceNote
            ? existing.mediaUrl
            : null,
      );
      await _applyServerResult(chatGroupId, messageId, result);
    } catch (e) {
      debugPrint('MessageNotifier: Retry failed: $e');
      await _writeThread(
        chatGroupId,
        (messages) => applySendResult(
          messages: messages,
          clientId: messageId,
          confirmed: false,
        ),
      );
    }
  }

  Future<void> _applyServerResult(
    String chatGroupId,
    String clientId,
    MessageSendResult result,
  ) {
    final confirmed = isServerConfirmed(
      success: result.success,
      isOffline: result.isOffline,
      messageId: result.messageId,
      clientId: clientId,
    );
    return _writeThread(
      chatGroupId,
      (messages) => applySendResult(
        messages: messages,
        clientId: clientId,
        confirmed: confirmed,
      ),
    );
  }

  MessageState? _readMessageState() {
    if (state.hasValue) return state.requireValue;
    return null;
  }

  Future<void> _writeThread(
    String chatGroupId,
    List<Message> Function(List<Message> messages) transform,
  ) async {
    final currentState = _readMessageState() ?? await future;
    final updatedMessages =
        Map<String, List<Message>>.from(currentState.messages);
    updatedMessages[chatGroupId] = transform(
      List<Message>.from(updatedMessages[chatGroupId] ?? const []),
    );
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
          if (_typingChannel != null) {
            await SupabaseService.safeRemoveChannel(_typingChannel!);
            _typingChannel = null;
          }
          if (shouldResubscribeAfterChannelError(_typingChannelErrorRetries)) {
            _typingChannelErrorRetries++;
            debugPrint('MessageNotifier: resubscribing typing channel');
            await _initializeTypingChannel(chatGroupId);
          } else {
            debugPrint(
                'MessageNotifier: typing channel dead after resubscribe; degraded');
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
