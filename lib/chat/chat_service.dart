import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import 'package:http/http.dart' as http; // TEMPORARILY DISABLED
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'dart:async';
import '../services/media_service.dart';
import '../services/message_service.dart';
import '../managers/stubs.dart';
import '../chat/sqlite_helper.dart';
import 'models/message_data.dart';
import '../presentation/notifiers/squad_notifier.dart' as sn;
import '../presentation/notifiers/user_notifier.dart';
import '../domain/entities/message.dart';

class ChatService with WidgetsBindingObserver {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MediaService _mediaService = MediaService();
  final MessageService _messageService = MessageService();
  final SQLiteHelper _sqliteHelper = SQLiteHelper();
  final SyncManager _syncManager;

  ChatService([SyncManager? syncManager])
      : _syncManager =
            syncManager ?? SyncManager(sqliteHelper: SQLiteHelper()) {
    // Register as app lifecycle observer
    WidgetsBinding.instance.addObserver(this);
  }

  // App lifecycle management for sync
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Trigger sync when app resumes
      _performBackgroundSync();
    }
  }

  Future<void> _performBackgroundSync() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Sync all active chat groups (simplified - in practice you'd track active chats)
      // For now, sync squad chat
      await _syncManager.deltaSync('');
    } catch (e) {
      debugPrint('Background sync failed: $e');
    }
  }

  // Improved caching with invalidation
  String? _cachedSquadId;
  int _cacheTimestamp = 0;
  static const int _cacheValidityMs = 5000; // 5 second cache validity

  // Stream cache to avoid recreating streams unnecessarily
  Stream<QuerySnapshot>? _messagesStream;
  Stream<String?>? _typingStream;
  String? _lastStreamSquadId;
  String? _lastStreamGroupId;
  bool _lastStreamIsUserGroup = false;
  bool _lastStreamIsDM = false;

  // Get cached squad ID with automatic invalidation
  String? _getCachedSquadId(WidgetRef ref) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_cachedSquadId != null && (now - _cacheTimestamp) < _cacheValidityMs) {
      return _cachedSquadId;
    }

    // Update cache
    final squadStateAsync = ref.watch(sn.squadNotifierProvider);
    _cachedSquadId = squadStateAsync.maybeWhen(
      data: (squadState) => squadState.selectedSquadId,
      orElse: () => null,
    );
    _cacheTimestamp = now;
    return _cachedSquadId;
  }

  // Stream for real-time messages from Firestore (updated for squad and groups)
  Stream<QuerySnapshot> getChatMessages(WidgetRef ref,
      {String? chatGroupId, required ChatType chatType}) {
    // Check if user is authenticated
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      debugPrint("Skipping chat messages stream - user not authenticated");
      return Stream.empty();
    }

    final bool isUserGroup = chatType == ChatType.userGroup;
    final bool isDM = chatType == ChatType.dm;

    // Check if we can reuse the cached stream
    if (_messagesStream != null &&
        _lastStreamGroupId == chatGroupId &&
        _lastStreamIsUserGroup == (chatType == ChatType.userGroup) &&
        _lastStreamIsDM == (chatType == ChatType.dm)) {
      return _messagesStream!;
    }

    // Create new stream
    String collectionPath;
    if (chatType == ChatType.userGroup) {
      collectionPath =
          'users/${currentUser.uid}/chat_groups/$chatGroupId/messages';
    } else if (chatType == ChatType.dm) {
      collectionPath = 'chats/$chatGroupId/messages';
    } else {
      return Stream.empty();
    }

    _messagesStream = _firestore
        .collection(collectionPath)
        .orderBy('timestamp_ms', descending: true)
        .limit(100)
        .snapshots();

    _lastStreamSquadId = isUserGroup || isDM ? null : _getCachedSquadId(ref);
    _lastStreamGroupId = chatGroupId;
    _lastStreamIsUserGroup = isUserGroup;
    _lastStreamIsDM = isDM;

    return _messagesStream!;
  }

  // Stream for typing status
  Stream<String?> getTypingUser(WidgetRef ref,
      {String? chatGroupId, required ChatType chatType}) {
    // Check if user is authenticated
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      debugPrint("Skipping typing status stream - user not authenticated");
      return Stream.value(null);
    }

    final bool isUserGroup = chatType == ChatType.userGroup;
    final bool isDM = chatType == ChatType.dm;

    // Check if we can reuse the cached typing stream
    if (_typingStream != null &&
        _lastStreamSquadId == null && // For DM and user groups
        _lastStreamGroupId == chatGroupId &&
        _lastStreamIsUserGroup == isUserGroup &&
        _lastStreamIsDM == isDM) {
      return _typingStream!;
    }

    // Use different typing status paths for group chats vs DMs
    String typingPath;
    if (isUserGroup) {
      typingPath =
          'users/${currentUser.uid}/chat_groups/$chatGroupId/typing_status/status';
    } else if (isDM) {
      typingPath = 'chats/$chatGroupId/typing_status/status';
    } else {
      return Stream.value(null);
    }

    // Capture displayName synchronously to avoid async gap
    final currentUserDisplayName = ref.watch(userNotifierProvider
        .select((asyncValue) => asyncValue.value?.displayName ?? ''));

    _typingStream = _firestore.doc(typingPath).snapshots().map((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        final typing = data['typing'] as Map<String, dynamic>?;
        if (typing != null) {
          final typingUsers = typing.entries
              .where((entry) => entry.value == true)
              .map((entry) => entry.key)
              .toList();
          typingUsers.removeWhere((user) => user == currentUserDisplayName);
          return typingUsers.isNotEmpty ? typingUsers.first : null;
        }
      }
      return null;
    });

    _lastStreamSquadId = isUserGroup || isDM ? null : _getCachedSquadId(ref);
    _lastStreamGroupId = chatGroupId;
    _lastStreamIsUserGroup = isUserGroup;
    _lastStreamIsDM = isDM;

    return _typingStream!;
  }

  // Send a new message with atomic local-first approach
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
    try {
      // Validate input
      if ((text?.trim().isEmpty ?? true) &&
          photos.isEmpty &&
          videos.isEmpty &&
          audio.isEmpty &&
          imageUrl == null &&
          videoUrl == null &&
          audioUrl == null &&
          pollId == null &&
          mediaFilePath == null) {
        return MessageSendResult.failure('Cannot send empty message');
      }

      final msgId = DateTime.now().millisecondsSinceEpoch.toString();
      final timestampMs = DateTime.now().millisecondsSinceEpoch;

      // Handle media upload first if present
      String? finalMediaUrl;
      if (mediaFilePath != null && mediaType != null) {
        try {
          finalMediaUrl =
              await _uploadMediaWithSignedUrl(mediaFilePath, mediaType);
        } catch (e) {
          debugPrint('Media upload failed: $e');
          return MessageSendResult.failure('Failed to upload media: $e');
        }
      }

      // Create message data
      final messageData = {
        'id': msgId,
        'senderUid': senderUid,
        'timestamp_ms': timestampMs,
        'text': text?.trim() ?? '',
        'imageUrl': imageUrl ??
            (mediaType?.startsWith('image') == true ? finalMediaUrl : null),
        'videoUrl': videoUrl ??
            (mediaType?.startsWith('video') == true ? finalMediaUrl : null),
        'audioUrl': audioUrl ??
            (mediaType?.startsWith('audio') == true ? finalMediaUrl : null),
        'photos': photos,
        'videos': videos,
        'audio': audio,
        'reactions': reactions,
        'pollId': pollId,
        'replyTo': replyTo,
        'delivered': false, // Initially pending
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
      };

      // Determine collection path
      String collectionPath;
      if (chatType == ChatType.userGroup) {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          return MessageSendResult.failure('User not authenticated');
        }
        collectionPath =
            'users/${currentUser.uid}/chat_groups/$chatGroupId/messages';
      } else if (chatType == ChatType.dm) {
        collectionPath = 'chats/$chatGroupId/messages';
      } else {
        final squadId = _getCachedSquadId(ref);
        if (squadId == null) {
          return MessageSendResult.failure('No squad selected');
        }
        collectionPath = 'squads/$squadId/messages';
      }

      // 1. Add to local SQLite as pending
      final pendingMessageData = Map<String, dynamic>.from(messageData);
      pendingMessageData['delivered'] = false;
      await _sqliteHelper.insertMessage(pendingMessageData,
          chatGroupId: chatGroupId);

      // 2. Attempt to send to Firestore
      try {
        await _firestore.collection(collectionPath).doc(msgId).set(messageData);

        // 3. Update local to sent on success
        final sentMessageData = Map<String, dynamic>.from(messageData);
        sentMessageData['delivered'] = true;
        await _sqliteHelper.insertMessage(sentMessageData,
            chatGroupId: chatGroupId);

        return MessageSendResult.success(msgId);
      } on FirebaseException catch (e) {
        // Firestore failed, but message is cached locally as pending
        debugPrint('Firestore send failed: ${e.message}');
        return MessageSendResult.offline(msgId);
      } catch (e) {
        // Firestore failed, but message is cached locally as pending
        debugPrint('Firestore send failed: $e');
        return MessageSendResult.offline(msgId);
      }
    } catch (e) {
      debugPrint('Send message failed: $e');
      return MessageSendResult.failure('Failed to send message: $e');
    }
  }

  // Upload media with signed URL from backend
  Future<String> _uploadMediaWithSignedUrl(
      String filePath, String mediaType) async {
    final file = File(filePath);
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';

    return await _mediaService.uploadMediaWithSignedUrl(file, fileName);
  }

  // Legacy method for backward compatibility
  Future<String> uploadMedia(File file, String fileName, bool isVideo) async {
    return _mediaService.uploadMedia(file, fileName, isVideo);
  }

  // Legacy method for backward compatibility
  Future<String> uploadAudio(File file, String fileName) async {
    return _mediaService.uploadAudio(file, fileName);
  }

  // Mark message as delivered
  Future<void> markAsDelivered(String docId) async {
    return _messageService.markAsDelivered(docId);
  }

  // Update typing status
  Future<void> updateTypingStatus(WidgetRef ref, String user, bool isTyping,
      {String? chatGroupId}) async {
    return _messageService.updateTypingStatus(ref, user, isTyping,
        chatGroupId: chatGroupId);
  }

  // Add reaction to a message
  Future<void> addReaction(WidgetRef ref, String msgId, String reaction,
      {String? chatGroupId, ChatType? chatType}) async {
    return _messageService.addReaction(ref, msgId, reaction,
        chatGroupId: chatGroupId, chatType: chatType);
  }

  // Fetch historical messages from PostgreSQL (removed 30-day limit)
  Future<List<Map<String, dynamic>>> loadMoreMessages({
    required int offset,
    required int limit,
    String? chatGroupId,
  }) async {
    return _messageService.loadMoreMessages(
        offset: offset, limit: limit, chatGroupId: chatGroupId);
  }

  // Get cached messages from SQLite
  Future<List<Map<String, dynamic>>> getCachedMessages(int offset, int limit,
      {String? chatGroupId}) async {
    return _messageService.getCachedMessages(offset, limit,
        chatGroupId: chatGroupId);
  }

  // TEMPORARILY DISABLED: Sync message to backend (non-blocking)
  /*
  Future<void> _syncToBackend(Map<String, dynamic> messageData) async {
    try {
      final messageDataForHttp = {
        ...messageData,
        'timestamp': messageData['timestamp_ms'], // Use timestamp_ms for HTTP
        'created_at': DateTime.now().toIso8601String(),
      };

      final response = await http.post(
        Uri.parse(
            'https://squadsync-backend-756172684661.us-central1.run.app/messages'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(messageDataForHttp),
      );

      if (response.statusCode != 200) {
        debugPrint('Backend sync failed: ${response.body}');
      }
    } catch (e) {
      debugPrint('Backend sync error: $e');
    }
  }
  */

  // Public method to retry sending offline messages
  Future<void> retryOfflineMessages() async {
    return _messageService.retryOfflineMessages();
  }

  // Get current offline queue status
  int get offlineMessageCount => _messageService.offlineMessageCount;
  bool get isOnline => _messageService.isOnline;

  // Cache messages from Firestore snapshot to SQLite
  Future<void> cacheMessagesFromSnapshot(
      QuerySnapshot snapshot, String? chatGroupId) async {
    return _messageService.cacheMessagesFromSnapshot(snapshot, chatGroupId);
  }

  Future<void> sendReply(String messageId, String text, String squadId,
      {String? chatGroupId}) async {
    return _messageService.sendReply(messageId, text, squadId,
        chatGroupId: chatGroupId);
  }

  Future<void> deleteMessage(String messageId, String squadId,
      {String? chatGroupId, required ChatType chatType}) async {
    return _messageService.deleteMessage(messageId, squadId,
        chatGroupId: chatGroupId, chatType: chatType);
  }

  Future<void> editMessage(String messageId, String newText, String squadId,
      {String? chatGroupId, required ChatType chatType}) async {
    return _messageService.editMessage(messageId, newText, squadId,
        chatGroupId: chatGroupId, chatType: chatType);
  }

  Future<void> pinMessage(
      String messageId, String? chatGroupId, ChatType chatType) async {
    String collectionPath;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    if (chatType == ChatType.userGroup) {
      collectionPath = 'users/$userId/chat_groups/$chatGroupId/messages';
    } else {
      collectionPath = 'chats/$chatGroupId/messages';
    }

    await _firestore.collection(collectionPath).doc(messageId).update({
      'pinned': true,
    });
  }

  Future<void> unpinMessage(
      String messageId, String? chatGroupId, ChatType chatType) async {
    String collectionPath;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    if (chatType == ChatType.userGroup) {
      collectionPath = 'users/$userId/chat_groups/$chatGroupId/messages';
    } else {
      collectionPath = 'chats/$chatGroupId/messages';
    }

    await _firestore.collection(collectionPath).doc(messageId).update({
      'pinned': false,
    });
  }

  Future<void> bumpMessage(
      String messageId, String? chatGroupId, ChatType chatType) async {
    String collectionPath;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    if (chatType == ChatType.userGroup) {
      collectionPath = 'users/$userId/chat_groups/$chatGroupId/messages';
    } else {
      collectionPath = 'chats/$chatGroupId/messages';
    }

    // Get the original message
    final originalDoc =
        await _firestore.collection(collectionPath).doc(messageId).get();
    if (!originalDoc.exists) return;

    final originalData = originalDoc.data()!;
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Create a new message copy with bumped metadata
    final bumpedMessage = {
      ...originalData,
      'isBumped': true,
      'originalId': messageId,
      'bumpedBy': currentUser.displayName ?? currentUser.email ?? 'Unknown',
      'timestamp': FieldValue.serverTimestamp(),
      'timestamp_ms': DateTime.now().millisecondsSinceEpoch,
      'id': null, // Let Firestore generate new ID
    };

    // Add the new bumped message
    await _firestore.collection(collectionPath).add(bumpedMessage);

    // TODO: Send notification to other users in the chat about the bumped message
    // This could be implemented by creating a system message or using push notifications
  }

  /// Get a single message by ID for reply previews
  Future<MessageData?> getMessageById(String messageId,
      {String? chatGroupId, ChatType? chatType, String? squadId}) async {
    try {
      String collectionPath;
      if (chatType == ChatType.squad && squadId != null) {
        collectionPath = 'squads/$squadId/messages';
      } else if (chatType == ChatType.userGroup && chatGroupId != null) {
        collectionPath =
            'users/${FirebaseAuth.instance.currentUser?.uid}/chat_groups/$chatGroupId/messages';
      } else if (chatType == ChatType.dm && chatGroupId != null) {
        collectionPath = 'chats/$chatGroupId/messages';
      } else {
        // Fallback - try the old logic
        collectionPath =
            chatGroupId != null ? 'chat_groups/$chatGroupId/messages' : 'chat';
      }

      final doc =
          await _firestore.collection(collectionPath).doc(messageId).get();

      if (!doc.exists) return null;

      return MessageData.fromDocument(doc);
    } catch (e) {
      debugPrint('Error getting message by ID: $e');
      return null;
    }
  }
}
