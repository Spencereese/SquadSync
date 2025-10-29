import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
// import 'package:http/http.dart' as http; // TEMPORARILY DISABLED
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'dart:async';
import 'sqlite_helper.dart';
import '../squad_state.dart';
import '../services/grok_service.dart';
import 'package:flutter/material.dart';

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

/// Represents a cancellable media upload task
class MediaUploadTask {
  final String taskId;
  final UploadTask _uploadTask;
  final Function(double progress)? onProgress;
  final Function(String url)? onComplete;
  final Function(String error)? onError;

  bool _isCancelled = false;

  MediaUploadTask(
    this.taskId,
    this._uploadTask, {
    this.onProgress,
    this.onComplete,
    this.onError,
  }) {
    // Listen to upload progress
    _uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
      if (_isCancelled) return;

      final progress = snapshot.bytesTransferred / snapshot.totalBytes;
      onProgress?.call(progress);

      if (snapshot.state == TaskState.success) {
        snapshot.ref.getDownloadURL().then((url) {
          if (!_isCancelled) {
            onComplete?.call(url);
          }
        }).catchError((error) {
          if (!_isCancelled) {
            onError?.call('Failed to get download URL: $error');
          }
        });
      } else if (snapshot.state == TaskState.error) {
        if (!_isCancelled) {
          onError?.call('Upload failed: ${snapshot.state}');
        }
      }
    });
  }

  void cancel() {
    _isCancelled = true;
    _uploadTask.cancel();
  }

  bool get isCancelled => _isCancelled;
}

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final SQLiteHelper _sqliteHelper = SQLiteHelper();
  final GrokService _grokService = GrokService();
  static const int _maxRetries = 3;
  static const Duration _initialBackoff = Duration(milliseconds: 500);

  // Improved caching with invalidation
  String? _cachedSquadId;
  BuildContext? _cachedContext;
  int _cacheTimestamp = 0;
  static const int _cacheValidityMs = 5000; // 5 second cache validity

  // Stream cache to avoid recreating streams unnecessarily
  Stream<QuerySnapshot>? _messagesStream;
  Stream<String?>? _typingStream;
  String? _lastStreamSquadId;
  String? _lastStreamGroupId;

  // Offline message queue
  final List<Map<String, dynamic>> _offlineMessageQueue = [];
  bool _isOnline = true;

  // Check connectivity by attempting a lightweight Firestore operation
  Future<bool> _checkConnectivity() async {
    try {
      // Try to get current user as a lightweight connectivity check
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
      _isOnline = true;
      return true;
    } catch (e) {
      _isOnline = false;
      return false;
    }
  }

  // Process offline message queue when connection is restored
  Future<void> _processOfflineQueue() async {
    if (_offlineMessageQueue.isEmpty || !_isOnline) return;

    final queueCopy = List<Map<String, dynamic>>.from(_offlineMessageQueue);
    _offlineMessageQueue.clear();

    for (final messageData in queueCopy) {
      try {
        final collectionPath = messageData['chatGroupId'] != null
            ? 'squads/${messageData['squadId']}/chat_groups/${messageData['chatGroupId']}/messages'
            : 'squads/${messageData['squadId']}/chat';

        await _retryOperation(() async {
          await _firestore
              .collection(collectionPath)
              .doc(messageData['id'])
              .set(messageData, SetOptions(merge: true));
        });

        // Update group metadata if this is a group chat
        if (messageData['chatGroupId'] != null) {
          await _updateGroupMetadata(
              messageData['squadId'],
              messageData['chatGroupId'],
              messageData['text'] ?? '',
              messageData['timestamp_ms']);
        }

        debugPrint('Successfully sent queued message: ${messageData['id']}');
      } catch (e) {
        debugPrint('Failed to send queued message, re-queuing: $e');
        _offlineMessageQueue.add(messageData);
      }
    }
  }

  // Get cached squad ID with automatic invalidation
  String? _getCachedSquadId(BuildContext context) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_cachedContext == context &&
        _cachedSquadId != null &&
        (now - _cacheTimestamp) < _cacheValidityMs) {
      return _cachedSquadId;
    }

    // Update cache
    _cachedContext = context;
    final squadState = Provider.of<SquadState>(context, listen: false);
    _cachedSquadId = squadState.selectedSquadId;
    _cacheTimestamp = now;
    return _cachedSquadId;
  }

  // Stream for real-time messages from Firestore (updated for squad and groups)
  Stream<QuerySnapshot> getChatMessages(BuildContext context,
      {String? chatGroupId}) {
    // Check if user is authenticated
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      debugPrint("Skipping chat messages stream - user not authenticated");
      return Stream.empty();
    }

    final squadId = _getCachedSquadId(context);
    if (squadId == null) return Stream.empty();

    // Check if we can reuse the cached stream
    if (_messagesStream != null &&
        _lastStreamSquadId == squadId &&
        _lastStreamGroupId == chatGroupId) {
      return _messagesStream!;
    }

    // Create new stream
    final collectionPath = chatGroupId != null
        ? 'squads/$squadId/chat_groups/$chatGroupId/messages'
        : 'squads/$squadId/chat';

    _messagesStream = _firestore
        .collection(collectionPath)
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots();

    _lastStreamSquadId = squadId;
    _lastStreamGroupId = chatGroupId;

    return _messagesStream!;
  }

  // Stream for typing status
  Stream<String?> getTypingUser(BuildContext context, {String? chatGroupId}) {
    // Check if user is authenticated
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      debugPrint("Skipping typing status stream - user not authenticated");
      return Stream.value(null);
    }

    final squadId = _getCachedSquadId(context);
    if (squadId == null) return Stream.value(null);

    // Check if we can reuse the cached typing stream
    if (_typingStream != null &&
        _lastStreamSquadId == squadId &&
        _lastStreamGroupId == chatGroupId) {
      return _typingStream!;
    }

    // Use different typing status paths for squad vs group chats
    final typingPath = chatGroupId != null
        ? 'squads/$squadId/chat_groups/$chatGroupId/typing_status/status'
        : 'squads/$squadId/chat_metadata/typing_status';

    _typingStream = _firestore.doc(typingPath).snapshots().map((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        final typing = data['typing'] as Map<String, dynamic>?;
        if (typing != null) {
          final typingUsers = typing.entries
              .where((entry) => entry.value == true)
              .map((entry) => entry.key)
              .toList();
          final currentUser =
              Provider.of<SquadState>(context, listen: false).displayName;
          typingUsers.removeWhere((user) => user == currentUser);
          return typingUsers.isNotEmpty ? typingUsers.first : null;
        }
      }
      return null;
    });

    _lastStreamSquadId = squadId;
    _lastStreamGroupId = chatGroupId;

    return _typingStream!;
  }

  // Send a new message with improved error handling
  Future<MessageSendResult> sendMessage(
    BuildContext context, {
    required String senderUid,
    String? text,
    String? imageUrl,
    String? videoUrl,
    String? audioUrl,
    List<Map<String, dynamic>> photos = const [],
    List<Map<String, dynamic>> videos = const [],
    List<Map<String, dynamic>> audio = const [],
    List<Map<String, dynamic>> reactions = const [],
    String? replyTo,
    String? pollId,
    String? chatGroupId,
  }) async {
    // Validate input
    if ((text?.trim().isEmpty ?? true) &&
        photos.isEmpty &&
        videos.isEmpty &&
        audio.isEmpty &&
        imageUrl == null &&
        videoUrl == null &&
        audioUrl == null &&
        pollId == null) {
      return MessageSendResult.failure('Cannot send empty message');
    }

    final msgId = Uuid().v4();
    final timestampMs = DateTime.now().millisecondsSinceEpoch;

    // Simplified message data for Firestore
    final messageData = {
      'id': msgId,
      'senderUid': senderUid,
      'timestamp_ms': timestampMs,
      'text': text?.trim() ?? '',
      'imageUrl': imageUrl,
      'videoUrl': videoUrl,
      'audioUrl': audioUrl,
      'photos': photos,
      'videos': videos,
      'audio': audio,
      'reactions': reactions,
      'reply_to': replyTo,
      'pollId': pollId,
      'delivered': false,
      'read': false,
      'timestamp': FieldValue.serverTimestamp(),
    };

    // Get squadId from context (use cached value)
    final squadId = _getCachedSquadId(context);
    if (squadId == null) {
      return MessageSendResult.failure('No squad selected');
    }

    // Determine collection path based on whether it's a group chat
    final collectionPath = chatGroupId != null
        ? 'squads/$squadId/chat_groups/$chatGroupId/messages'
        : 'squads/$squadId/chat';

    try {
      // Check connectivity before attempting to send
      final isConnected = await _checkConnectivity();
      if (!isConnected) {
        // Queue message for offline sending
        final offlineMessageData = {
          ...messageData,
          'squadId': squadId,
          'chatGroupId': chatGroupId,
        };
        _offlineMessageQueue.add(offlineMessageData);

        // Still cache locally for immediate display
        await _sqliteHelper.insertMessage(messageData,
            chatGroupId: chatGroupId);

        return MessageSendResult.offline(msgId);
      }

      // Write to Firestore with retry
      await _retryOperation(() async {
        await _firestore.collection(collectionPath).doc(msgId).set(messageData);
      });

      // Update group metadata if this is a group chat
      if (chatGroupId != null) {
        await _updateGroupMetadata(
            squadId, chatGroupId, text ?? '', timestampMs);
      }

      // Cache locally for offline viewing
      await _sqliteHelper.insertMessage(messageData, chatGroupId: chatGroupId);

      // Check if this is a message for Grok and generate AI response
      if (text != null && _grokService.isMessageForGrok(text)) {
        _generateGrokResponse(context, text, senderUid, squadId, chatGroupId);
      }

      // TEMPORARILY DISABLED: Backend sync
      // _syncToBackend(messageData).catchError((e) {
      //   debugPrint('Backend sync failed, but message saved locally: $e');
      // });

      // Process any queued offline messages
      _processOfflineQueue();

      return MessageSendResult.success(msgId);
    } catch (e) {
      debugPrint('Failed to send message: $e');

      // Try to cache locally even if Firestore failed
      try {
        await _sqliteHelper.insertMessage(messageData,
            chatGroupId: chatGroupId);
      } catch (cacheError) {
        debugPrint('Failed to cache message locally: $cacheError');
      }

      return MessageSendResult.failure(_getErrorMessage(e));
    }
  }

  // Upload media to Firebase Storage with progress tracking
  MediaUploadTask uploadMediaWithProgress(
    File file,
    String fileName, {
    Function(double progress)? onProgress,
    Function(String url)? onComplete,
    Function(String error)? onError,
  }) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      onError?.call('User must be authenticated to upload media');
      throw Exception('User must be authenticated to upload media');
    }

    final taskId = 'media_${DateTime.now().millisecondsSinceEpoch}';
    Reference ref = _storage.ref().child('chat_media/$fileName');

    final uploadTask = ref.putFile(file);
    return MediaUploadTask(
      taskId,
      uploadTask,
      onProgress: onProgress,
      onComplete: (url) {
        HapticFeedback.lightImpact();
        onComplete?.call(url);
      },
      onError: onError,
    );
  }

  // Legacy method for backward compatibility
  Future<String> uploadMedia(File file, String fileName, bool isVideo) async {
    final completer = Completer<String>();
    String? error;

    final task = uploadMediaWithProgress(
      file,
      fileName,
      onComplete: (url) => completer.complete(url),
      onError: (err) {
        error = err;
        completer.completeError(Exception(err));
      },
    );

    try {
      return await completer.future;
    } catch (e) {
      throw Exception(error ?? 'Failed to upload media: $e');
    }
  }

  // Upload audio to Firebase Storage with progress tracking
  MediaUploadTask uploadAudioWithProgress(
    File file,
    String fileName, {
    Function(double progress)? onProgress,
    Function(String url)? onComplete,
    Function(String error)? onError,
  }) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      onError?.call('User must be authenticated to upload audio');
      throw Exception('User must be authenticated to upload audio');
    }

    final taskId = 'audio_${DateTime.now().millisecondsSinceEpoch}';
    Reference ref = _storage.ref().child('chat_audio/$fileName');

    final uploadTask = ref.putFile(file);
    return MediaUploadTask(
      taskId,
      uploadTask,
      onProgress: onProgress,
      onComplete: (url) {
        HapticFeedback.lightImpact();
        onComplete?.call(url);
      },
      onError: onError,
    );
  }

  // Legacy method for backward compatibility
  Future<String> uploadAudio(File file, String fileName) async {
    final completer = Completer<String>();
    String? error;

    uploadAudioWithProgress(
      file,
      fileName,
      onComplete: (url) => completer.complete(url),
      onError: (err) {
        error = err;
        completer.completeError(Exception(err));
      },
    );

    try {
      return await completer.future;
    } catch (e) {
      throw Exception(error ?? 'Failed to upload audio: $e');
    }
  }

  // Mark message as delivered
  Future<void> markAsDelivered(String docId) async {
    try {
      await _retryOperation(() async {
        await _firestore
            .collection('chat')
            .doc(docId)
            .update({'delivered': true});
      });
    } catch (e) {
      debugPrint('Failed to mark as delivered: $e');
    }
  }

  // Update typing status
  Future<void> updateTypingStatus(
      BuildContext context, String user, bool isTyping,
      {String? chatGroupId}) async {
    try {
      if (user.isEmpty) return;
      Provider.of<SquadState>(context, listen: false)
          .updateTypingStatus(user, isTyping);

      final squadId = _getCachedSquadId(context);
      if (squadId == null) return;

      // Use different typing status paths for squad vs group chats
      final typingPath = chatGroupId != null
          ? 'squads/$squadId/chat_groups/$chatGroupId/typing_status'
          : 'squads/$squadId/chat_metadata/typing_status';

      await _firestore.collection(typingPath).doc('status').set({
        'typing': {user: isTyping},
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to update typing status: $e');
    }
  }

  // Add reaction to a message
  Future<void> addReaction(BuildContext context, String msgId, String reaction,
      {String? chatGroupId}) async {
    try {
      final squadId = _getCachedSquadId(context);
      if (squadId == null) return;

      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      // Determine collection path based on whether it's a group chat
      final collectionPath = chatGroupId != null
          ? 'squads/$squadId/chat_groups/$chatGroupId/messages'
          : 'squads/$squadId/chat';

      final docRef = _firestore.collection(collectionPath).doc(msgId);
      final snapshot = await docRef.get();
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        final currentReactions =
            List<Map<String, dynamic>>.from(data['reactions'] ?? []);

        // Check if user already reacted with this emoji
        final existingReactionIndex = currentReactions.indexWhere(
          (r) => r['userId'] == userId && r['reaction'] == reaction,
        );

        if (existingReactionIndex != -1) {
          // User already reacted with this emoji, remove it
          final reactionToRemove = currentReactions[existingReactionIndex];
          await docRef.update({
            'reactions': FieldValue.arrayRemove([reactionToRemove])
          });
          await _sqliteHelper.updateMessage(msgId,
              {'reactions': currentReactions..removeAt(existingReactionIndex)});
        } else {
          // User hasn't reacted with this emoji, add it
          final newReaction = {
            'userId': userId,
            'reaction': reaction,
            'timestamp': FieldValue.serverTimestamp(),
          };
          await docRef.update({
            'reactions': FieldValue.arrayUnion([newReaction])
          });
          await _sqliteHelper.updateMessage(
              msgId, {'reactions': currentReactions..add(newReaction)});
        }
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      debugPrint('Failed to update reaction: $e');
    }
  }

  // Fetch historical messages from PostgreSQL (removed 30-day limit)
  Future<List<Map<String, dynamic>>> loadMoreMessages({
    required int offset,
    required int limit,
  }) async {
    // TEMPORARILY DISABLED: Backend message loading - only use SQLite cache
    try {
      final cachedMessages = await _sqliteHelper.getMessages(offset, limit);
      debugPrint(
          'Loaded ${cachedMessages.length} messages from SQLite cache (backend disabled): ${cachedMessages.map((m) => m['id']).toList()}');
      return cachedMessages;
    } catch (e) {
      debugPrint('Failed to load cached messages: $e');
      return [];
    }
  }

  // Get cached messages from SQLite
  Future<List<Map<String, dynamic>>> getCachedMessages(int offset, int limit,
      {String? chatGroupId}) async {
    return await _sqliteHelper.getMessages(offset, limit,
        chatGroupId: chatGroupId);
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
    await _checkConnectivity();
    await _processOfflineQueue();
  }

  // Get current offline queue status
  int get offlineMessageCount => _offlineMessageQueue.length;
  bool get isOnline => _isOnline;

  // Convert exceptions to user-friendly error messages
  String _getErrorMessage(dynamic error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'You don\'t have permission to send messages in this chat';
        case 'unavailable':
          return 'Service temporarily unavailable. Message will be sent when connection is restored';
        case 'cancelled':
          return 'Message sending was cancelled';
        case 'deadline-exceeded':
          return 'Request timed out. Please try again';
        default:
          return 'Failed to send message: ${error.message ?? 'Unknown error'}';
      }
    } else if (error is TimeoutException) {
      return 'Request timed out. Please check your connection and try again';
    } else if (error is SocketException) {
      return 'Network connection error. Please check your internet connection';
    } else {
      return 'An unexpected error occurred. Please try again';
    }
  }

  // Update group metadata when a message is sent
  Future<void> _updateGroupMetadata(String squadId, String groupId,
      String lastMessage, int timestampMs) async {
    try {
      await _firestore
          .collection('squads')
          .doc(squadId)
          .collection('chat_groups')
          .doc(groupId)
          .update({
        'lastMessage': lastMessage,
        'lastMessageTime': Timestamp.fromMillisecondsSinceEpoch(timestampMs),
        'messageCount': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('Failed to update group metadata: $e');
    }
  }

  // Generate AI response from Grok for messages directed at it
  Future<void> _generateGrokResponse(BuildContext context, String userMessage,
      String senderUid, String squadId, String? chatGroupId) async {
    try {
      // Clean the message by removing Grok mentions
      final cleanMessage = _grokService.cleanGrokMessage(userMessage);

      // Get context about the current squad/game
      final squadState = Provider.of<SquadState>(context, listen: false);
      final currentGame = squadState.currentGame;
      final gameContext = currentGame != null
          ? 'Currently playing: ${currentGame['name']} (${currentGame['genres']?.join(', ') ?? 'Unknown genre'})'
          : 'No specific game selected';

      // Get recent messages for context (last 5 messages)
      final recentMessages =
          await _getRecentMessages(squadId, chatGroupId, limit: 5);

      // Generate Grok response
      final grokResponse = await _grokService.getGrokResponse(
        cleanMessage,
        context: gameContext,
        recentMessages: recentMessages,
      );

      // Create Grok's response message
      final grokMsgId = Uuid().v4();
      final timestampMs = DateTime.now().millisecondsSinceEpoch;

      final grokMessageData = {
        'id': grokMsgId,
        'senderUid': 'grok-ai', // Special UID for Grok
        'timestamp_ms': timestampMs,
        'text': grokResponse,
        'imageUrl': null,
        'videoUrl': null,
        'audioUrl': null,
        'photos': [],
        'videos': [],
        'audio': [],
        'reactions': [],
        'reply_to': null,
        'pollId': null,
        'delivered': true,
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
        'isAiResponse': true, // Flag to identify AI responses
      };

      // Determine collection path
      final collectionPath = chatGroupId != null
          ? 'squads/$squadId/chat_groups/$chatGroupId/messages'
          : 'squads/$squadId/chat';

      // Send Grok's response
      await _firestore
          .collection(collectionPath)
          .doc(grokMsgId)
          .set(grokMessageData);

      // Cache locally
      await _sqliteHelper.insertMessage(grokMessageData,
          chatGroupId: chatGroupId);
    } catch (e) {
      debugPrint('Failed to generate Grok response: $e');
      // Don't show error to user, just log it
    }
  }

  // Get recent messages for context
  Future<List<String>> _getRecentMessages(String squadId, String? chatGroupId,
      {int limit = 5}) async {
    try {
      final collectionPath = chatGroupId != null
          ? 'squads/$squadId/chat_groups/$chatGroupId/messages'
          : 'squads/$squadId/chat';

      final snapshot = await _firestore
          .collection(collectionPath)
          .orderBy('timestamp_ms', descending: true)
          .limit(limit * 2) // Get more to filter out AI responses
          .get();

      final messages = snapshot.docs
          .where((doc) =>
              !(doc.data()['isAiResponse'] ?? false)) // Exclude AI responses
          .take(limit)
          .map((doc) => doc.data()['text'] as String?)
          .where((text) => text != null && text.isNotEmpty)
          .cast<String>()
          .toList();

      return messages.reversed.toList(); // Return in chronological order
    } catch (e) {
      debugPrint('Failed to get recent messages: $e');
      return [];
    }
  }
}
