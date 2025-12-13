import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:logger/logger.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:squad_sync/presentation/notifiers/lobby_notifier.dart' as ln;
import '../services/media_service.dart';
import '../services/auth_service_supabase.dart';
import '../services/supabase_service.dart';
import '../domain/entities/message.dart';
import '../chat/sqlite_helper.dart';

/// Result of a message send operation
class MessageSendResult {
  final bool success;
  final String? messageId;
  final String? errorMessage;
  final bool isOffline;

  MessageSendResult._({
    required this.success,
    this.messageId,
    this.errorMessage,
    this.isOffline = false,
  });

  factory MessageSendResult.success(String messageId) {
    return MessageSendResult._(success: true, messageId: messageId);
  }

  factory MessageSendResult.failure(String errorMessage) {
    return MessageSendResult._(success: false, errorMessage: errorMessage);
  }

  factory MessageSendResult.offline(String messageId) {
    return MessageSendResult._(
        success: true, messageId: messageId, isOffline: true);
  }
}

/// Consolidated MessageService - handles all chat/messaging operations
/// Merged ChatService functionality for Realtime subscriptions and media upload
class MessageService with WidgetsBindingObserver {
  final Logger _logger = Logger();
  final SupabaseClient _supabase = supabase;
  final SQLiteHelper _sqliteHelper = SQLiteHelper();
  final MediaService _mediaService = MediaService();
  final AuthServiceSupabase _authService = AuthServiceSupabase();
  static const int _maxRetries = 3;
  static const Duration _initialBackoff = Duration(milliseconds: 500);

  // Realtime subscription management (from ChatService)
  RealtimeChannel? _messageChannel;
  RealtimeChannel? _typingChannel;
  final StreamController<List<Map<String, dynamic>>> _messagesController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  final StreamController<String?> _typingController =
      StreamController<String?>.broadcast();

  // Stream cache tracking (from ChatService)
  String? _lastStreamGroupId;
  bool _lastStreamIsUserGroup = false;
  bool _lastStreamIsDM = false;

  // Lobby ID caching (from ChatService)
  String? _cachedSquadId;
  int _cacheTimestamp = 0;
  static const int _cacheValidityMs = 5000; // 5 second cache validity

  // Offline message queue
  final List<Map<String, dynamic>> _offlineMessageQueue = [];
  bool _isOnline = true;

  MessageService() {
    // Register as app lifecycle observer (from ChatService)
    WidgetsBinding.instance.addObserver(this);
  }

  // App lifecycle management for sync (from ChatService)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _performBackgroundSync();
    }
  }

  Future<void> _performBackgroundSync() async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) return;
      // Sync logic with Supabase if needed
    } catch (e) {
      debugPrint('Background sync failed: $e');
    }
  }

  // Get cached squad ID with automatic invalidation (from ChatService)
  String? _getCachedSquadId(WidgetRef ref) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_cachedSquadId != null && (now - _cacheTimestamp) < _cacheValidityMs) {
      return _cachedSquadId;
    }

    // Update cache
    final squadStateAsync = ref.watch(ln.lobbyNotifierProvider);
    _cachedSquadId = squadStateAsync.maybeWhen(
      data: (squadState) => squadState.selectedLobbyId,
      orElse: () => null,
    );
    _cacheTimestamp = now;
    return _cachedSquadId;
  }

  // Stream for real-time messages from Supabase (from ChatService)
  Stream<List<Map<String, dynamic>>> getChatMessages(WidgetRef ref,
      {String? chatGroupId, required ChatType chatType}) {
    final currentUid = _authService.currentUser?.id;
    if (currentUid == null) {
      debugPrint("Skipping chat messages stream - user not authenticated");
      return Stream.value([]);
    }

    final bool isUserGroup = chatType == ChatType.userGroup;
    final bool isDM = chatType == ChatType.dm;

    // Check if we can reuse the cached stream
    if (_messageChannel != null &&
        _lastStreamGroupId == chatGroupId &&
        _lastStreamIsUserGroup == isUserGroup &&
        _lastStreamIsDM == isDM) {
      return _messagesController.stream;
    }

    // Unsubscribe from previous channel
    _messageChannel?.unsubscribe();

    // Determine chat_id based on type
    final String chatId;
    if (chatType == ChatType.userGroup || chatType == ChatType.dm) {
      chatId = chatGroupId ?? '';
      if (chatId.isEmpty) {
        debugPrint("Cannot create message stream - no chat group ID");
        return Stream.value([]);
      }
    } else {
      final squadId = _getCachedSquadId(ref);
      if (squadId == null) {
        debugPrint("Cannot create message stream - no squad ID");
        return Stream.value([]);
      }
      chatId = squadId;
    }

    // Load initial messages
    _loadInitialMessages(chatId, chatType.name);

    // Subscribe to realtime updates
    _messageChannel = _supabase
        .channel('messages_$chatId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'chat_id',
            value: chatId,
          ),
          callback: (payload) {
            _handleMessageChange(payload, chatId, chatType.name);
          },
        )
        .subscribe();

    _lastStreamGroupId = chatGroupId;
    _lastStreamIsUserGroup = isUserGroup;
    _lastStreamIsDM = isDM;

    return _messagesController.stream;
  }

  // Load initial messages from Supabase (from ChatService)
  Future<void> _loadInitialMessages(String chatId, String chatType) async {
    try {
      final response = await _supabase
          .from('chat_messages')
          .select()
          .eq('chat_id', chatId)
          .eq('chat_type', chatType)
          .order('timestamp', ascending: false)
          .limit(100);

      _messagesController.add(response);
    } catch (e) {
      debugPrint('Failed to load initial messages: $e');
      _messagesController.add([]);
    }
  }

  // Handle realtime message changes (from ChatService)
  void _handleMessageChange(
      PostgresChangePayload payload, String chatId, String chatType) async {
    try {
      await _loadInitialMessages(chatId, chatType);
    } catch (e) {
      debugPrint('Failed to handle message change: $e');
    }
  }

  // Stream for typing status from Supabase (from ChatService)
  Stream<String?> getTypingUser(WidgetRef ref,
      {String? chatGroupId, required ChatType chatType}) {
    final currentUid = _authService.currentUser?.id;
    if (currentUid == null) {
      debugPrint("Skipping typing status stream - user not authenticated");
      return Stream.value(null);
    }

    // Determine chat_id based on type
    final String chatId;
    if (chatType == ChatType.userGroup || chatType == ChatType.dm) {
      chatId = chatGroupId ?? '';
      if (chatId.isEmpty) {
        debugPrint("Cannot create typing stream - no chat group ID");
        return Stream.value(null);
      }
    } else {
      final squadId = _getCachedSquadId(ref);
      if (squadId == null) {
        debugPrint("Cannot create typing stream - no squad ID");
        return Stream.value(null);
      }
      chatId = squadId;
    }

    // Unsubscribe from previous typing channel
    _typingChannel?.unsubscribe();

    // Subscribe to realtime typing updates
    _typingChannel = _supabase
        .channel('typing_$chatId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'typing_indicators',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'chat_id',
            value: chatId,
          ),
          callback: (payload) async {
            _handleTypingChange(payload, currentUid);
          },
        )
        .subscribe();

    return _typingController.stream;
  }

  // Handle realtime typing changes (from ChatService)
  void _handleTypingChange(
      PostgresChangePayload payload, String currentUid) async {
    try {
      if (payload.newRecord['is_typing'] == true) {
        final typingUid = payload.newRecord['user_id'] as String;
        if (typingUid != currentUid) {
          _typingController.add(typingUid);
          return;
        }
      }
      _typingController.add(null);
    } catch (e) {
      debugPrint('Failed to handle typing change: $e');
      _typingController.add(null);
    }
  }

  // Upload media methods (from ChatService)
  Future<String> uploadMedia(File file, String fileName, bool isVideo) async {
    return _mediaService.uploadMedia(file, fileName, isVideo);
  }

  Future<String> uploadAudio(File file, String fileName) async {
    return _mediaService.uploadAudio(file, fileName);
  }

  // Send a new message with media upload support (consolidated from ChatService)
  Future<MessageSendResult> sendMessage(
    WidgetRef ref, {
    required String senderUid,
    String? text,
    String? imageUrl,
    String? videoUrl,
    String? audioUrl,
    List<Map<String, dynamic>> photos = const [],
    List<Map<String, dynamic>> videos = const [],
    List<Map<String, dynamic>> audio = const [],
    List<Map<String, dynamic>> reactions = const [],
    String? pollId,
    String? replyTo,
    String? chatGroupId,
    required ChatType chatType,
    String? mediaFilePath,
    String? mediaType,
  }) async {
    // Handle media upload first if present (from ChatService)
    String? finalImageUrl = imageUrl;
    String? finalVideoUrl = videoUrl;
    String? finalAudioUrl = audioUrl;

    if (mediaFilePath != null && mediaType != null) {
      try {
        final file = File(mediaFilePath);
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
        final finalMediaUrl =
            await _mediaService.uploadMediaWithSignedUrl(file, fileName);

        // Assign to appropriate media URL based on type
        if (mediaType.startsWith('image')) {
          finalImageUrl = finalMediaUrl;
        } else if (mediaType.startsWith('video')) {
          finalVideoUrl = finalMediaUrl;
        } else if (mediaType.startsWith('audio')) {
          finalAudioUrl = finalMediaUrl;
        }
      } catch (e) {
        debugPrint('Media upload failed: $e');
        return MessageSendResult.failure('Failed to upload media: $e');
      }
    }

    final bool isUserGroup = chatType == ChatType.userGroup;
    final bool isDM = chatType == ChatType.dm;

    // Capture squadId synchronously to avoid async gaps
    final cachedSquadId = isDM || isUserGroup ? null : _getCachedSquadId(ref);

    // Validate input
    if ((text?.trim().isEmpty ?? true) &&
        photos.isEmpty &&
        videos.isEmpty &&
        audio.isEmpty &&
        finalImageUrl == null &&
        finalVideoUrl == null &&
        finalAudioUrl == null &&
        pollId == null) {
      _logger.d('Message validation failed - empty message');
      return MessageSendResult.failure('Cannot send empty message');
    }

    final msgId = const Uuid().v4();
    final timestamp = DateTime.now();

    // Determine chat_id based on chat type
    final chatId = isDM || isUserGroup ? chatGroupId : cachedSquadId;
    if (chatId == null) {
      return MessageSendResult.failure(
          isDM || isUserGroup ? 'No chat group ID' : 'No squad selected');
    }

    // Determine message type
    String messageType = 'text';
    if (pollId != null) {
      messageType = 'poll';
    } else if (finalImageUrl != null || photos.isNotEmpty) {
      messageType = 'image';
    } else if (finalVideoUrl != null || videos.isNotEmpty) {
      messageType = 'video';
    } else if (finalAudioUrl != null || audio.isNotEmpty) {
      messageType = 'audio';
    }

    // Determine media URL and type
    final mediaUrl = finalImageUrl ?? finalVideoUrl ?? finalAudioUrl;
    String? detectedMediaType;
    if (finalImageUrl != null || photos.isNotEmpty) {
      detectedMediaType = 'image';
    } else if (finalVideoUrl != null || videos.isNotEmpty) {
      detectedMediaType = 'video';
    } else if (finalAudioUrl != null || audio.isNotEmpty) {
      detectedMediaType = 'audio';
    }

    // Build Supabase message data (removed old metadata with photos/videos/audio arrays)
    final supabaseMessage = {
      'id': msgId,
      'sender_id': senderUid,
      'chat_id': chatId,
      'chat_type': chatType.name,
      'text': text?.trim(),
      'message_type': messageType,
      'media_url': mediaUrl,
      'media_type': detectedMediaType,
      'reactions': {},
      'reply_to': replyTo,
      'poll': pollId != null ? {'id': pollId} : null,
      // metadata removed - no longer needed, use media_url instead
      'timestamp': timestamp.toIso8601String(),
      'is_deleted': false,
    };

    // SQLite cache format (matches new schema without photos/videos/audio columns)
    final cacheMessageData = {
      'id': msgId,
      'sender_id': senderUid,
      'timestamp_ms': timestamp.millisecondsSinceEpoch,
      'text': text?.trim() ?? '',
      'message_type': messageType,
      'media_url': mediaUrl,
      'media_type': detectedMediaType,
      'reactions': jsonEncode(reactions),
      'poll': pollId != null ? jsonEncode({'id': pollId}) : null,
      'reply_to': replyTo,
      'delivered': 1,
      'read': 0,
      'created_at': timestamp.toIso8601String(),
      'chat_group_id': chatGroupId,
      'synced': 1,
    };

    try {
      // Check connectivity before attempting to send
      final isConnected = await _checkConnectivity();
      if (!isConnected) {
        // Queue message for offline sending
        final offlineMessageData = {
          ...supabaseMessage,
          'cached_at': DateTime.now().toIso8601String(),
        };
        _offlineMessageQueue.add(offlineMessageData);
        _logger.d('Message queued for offline sending: $msgId');

        // Save to SQLite with pending status
        final pendingCacheData = {...cacheMessageData, 'delivered': false};
        await _sqliteHelper.insertMessage(pendingCacheData,
            chatGroupId: chatGroupId);

        return MessageSendResult.offline(msgId);
      }

      // Send to Supabase with retry logic
      await _retryOperation(() async {
        await _supabase.from('chat_messages').insert(supabaseMessage);
      });

      // Cache to SQLite for offline access
      await _sqliteHelper.insertMessage(cacheMessageData,
          chatGroupId: chatGroupId);

      _logger.d('Message sent successfully: $msgId');
      return MessageSendResult.success(msgId);
    } catch (e) {
      _logger.e('Failed to send message: $e');

      // Queue for retry
      final offlineMessageData = {
        ...supabaseMessage,
        'cached_at': DateTime.now().toIso8601String(),
      };
      _offlineMessageQueue.add(offlineMessageData);

      // Save to SQLite with pending status
      try {
        final pendingCacheData = {...cacheMessageData, 'delivered': false};
        await _sqliteHelper.insertMessage(pendingCacheData,
            chatGroupId: chatGroupId);
      } catch (sqliteError) {
        _logger.e('Failed to cache message to SQLite: $sqliteError');
      }

      return MessageSendResult.offline(msgId);
    }
  }

  // Send reply to a message
  Future<void> sendReply(String messageId, String text, String squadId,
      {String? chatGroupId}) async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    // Implementation would call sendMessage with replyTo parameter
    _logger.d('Sending reply to message: $messageId');
  }

  // Delete a message
  Future<void> deleteMessage(String messageId, String squadId,
      {String? chatGroupId, required ChatType chatType}) async {
    try {
      await _supabase.from('chat_messages').update({
        'is_deleted': true,
        'deleted_at': DateTime.now().toIso8601String()
      }).eq('id', messageId);

      _logger.d('Message deleted: $messageId');
    } catch (e) {
      _logger.e('Failed to delete message: $e');
      rethrow;
    }
  }

  // Edit a message
  Future<void> editMessage(String messageId, String newText, String squadId,
      {String? chatGroupId, required ChatType chatType}) async {
    try {
      await _supabase.from('chat_messages').update({
        'text': newText,
        'is_edited': true,
        'edited_at': DateTime.now().toIso8601String(),
      }).eq('id', messageId);

      _logger.d('Message edited: $messageId');
    } catch (e) {
      _logger.e('Failed to edit message: $e');
      rethrow;
    }
  }

  // Update typing status
  Future<void> updateTypingStatus(WidgetRef ref, String user, bool isTyping,
      {String? chatGroupId}) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) return;

      final squadId = chatGroupId ?? _getCachedSquadId(ref);
      if (squadId == null) return;

      if (isTyping) {
        await _supabase.from('typing_indicators').upsert({
          'user_id': currentUser.id,
          'chat_id': squadId,
          'is_typing': true,
          'updated_at': DateTime.now().toIso8601String(),
        });
      } else {
        await _supabase
            .from('typing_indicators')
            .delete()
            .eq('chat_id', squadId)
            .eq('user_id', currentUser.id);
      }
      _logger.d('Updated typing status: $isTyping for chat $squadId');
    } catch (e) {
      _logger.e('Failed to update typing status: $e');
    }
  }

  // Add reaction to a message
  Future<void> addReaction(WidgetRef ref, String msgId, String reaction,
      {String? chatGroupId, ChatType? chatType}) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) return;

      // Fetch current reactions
      final response = await _supabase
          .from('chat_messages')
          .select('reactions')
          .eq('id', msgId)
          .single();

      final Map<String, dynamic> reactions =
          Map<String, dynamic>.from(response['reactions'] ?? {});

      // Toggle reaction
      if (reactions.containsKey(reaction)) {
        final List<dynamic> users = List<dynamic>.from(reactions[reaction]);
        if (users.contains(currentUser.id)) {
          users.remove(currentUser.id);
          if (users.isEmpty) {
            reactions.remove(reaction);
          } else {
            reactions[reaction] = users;
          }
        } else {
          users.add(currentUser.id);
          reactions[reaction] = users;
        }
      } else {
        reactions[reaction] = [currentUser.id];
      }

      // Update message
      await _supabase
          .from('chat_messages')
          .update({'reactions': reactions}).eq('id', msgId);

      _logger.d('Reaction added to message: $msgId');
    } catch (e) {
      _logger.e('Failed to add reaction: $e');
      rethrow;
    }
  }

  // Fetch historical messages
  Future<List<Map<String, dynamic>>> loadMoreMessages({
    required int offset,
    required int limit,
    String? chatGroupId,
  }) async {
    try {
      final cachedMessages = await _sqliteHelper.getMessages(offset, limit,
          chatGroupId: chatGroupId);
      _logger.d('Loaded ${cachedMessages.length} messages from SQLite cache');
      return cachedMessages;
    } catch (e) {
      _logger.e('Failed to load cached messages: $e');
      return [];
    }
  }

  // Get cached messages from SQLite
  Future<List<Map<String, dynamic>>> getCachedMessages(int offset, int limit,
      {String? chatGroupId}) async {
    return await _sqliteHelper.getMessages(offset, limit,
        chatGroupId: chatGroupId);
  }

  // Retry sending offline messages
  Future<void> retryOfflineMessages() async {
    await _checkConnectivity();
    await _processOfflineQueue();
  }

  // Get current offline queue status
  int get offlineMessageCount => _offlineMessageQueue.length;
  bool get isOnline => _isOnline;

  // Private helper methods
  Future<bool> _checkConnectivity() async {
    try {
      return true; // Simplified - in production use connectivity_plus
    } catch (e) {
      _isOnline = false;
      return false;
    }
  }

  // Process offline message queue
  Future<void> _processOfflineQueue() async {
    if (_offlineMessageQueue.isEmpty || !_isOnline) return;

    final messagesToSend =
        List<Map<String, dynamic>>.from(_offlineMessageQueue);
    _offlineMessageQueue.clear();

    for (final messageData in messagesToSend) {
      try {
        await _supabase.from('chat_messages').insert(messageData);
        _logger.d('Successfully sent offline message: ${messageData['id']}');
      } catch (e) {
        _logger.e('Failed to send offline message ${messageData['id']}: $e');
        _offlineMessageQueue.add(messageData);
      }
    }
  }

  // Retry logic with exponential backoff
  Future<void> _retryOperation(Future<void> Function() operation) async {
    int attempt = 0;
    while (attempt < _maxRetries) {
      try {
        await operation();
        return;
      } catch (e) {
        attempt++;
        if (attempt == _maxRetries) rethrow;
        await Future.delayed(_initialBackoff * (attempt * 2));
      }
    }
  }

  // Clean up resources (from ChatService)
  void dispose() {
    _messageChannel?.unsubscribe();
    _typingChannel?.unsubscribe();
    _messagesController.close();
    _typingController.close();
    WidgetsBinding.instance.removeObserver(this);
  }
}
