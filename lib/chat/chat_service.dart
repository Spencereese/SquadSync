import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'sqlite_helper.dart';
import '../squad_state.dart';
import 'package:flutter/material.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final SQLiteHelper _sqliteHelper = SQLiteHelper();
  static const int _maxRetries = 3;
  static const Duration _initialBackoff = Duration(milliseconds: 500);

  // Cache for frequently accessed data
  String? _cachedSquadId;
  BuildContext? _cachedContext;

  // Stream for real-time messages from Firestore (updated for squad and groups)
  Stream<QuerySnapshot> getChatMessages(BuildContext context,
      {String? chatGroupId}) {
    // Cache context and squadId to avoid repeated Provider.of calls
    if (_cachedContext != context) {
      _cachedContext = context;
      final squadState = Provider.of<SquadState>(context, listen: false);
      _cachedSquadId = squadState.selectedSquadId;
    }

    final squadId = _cachedSquadId;
    if (squadId == null) return Stream.empty();

    // If chatGroupId is provided, get messages from the group, otherwise from squad chat
    final collectionPath = chatGroupId != null
        ? 'squads/$squadId/chat_groups/$chatGroupId/messages'
        : 'squads/$squadId/chat';

    return _firestore
        .collection(collectionPath)
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots();
  }

  // Stream for typing status
  Stream<String?> getTypingUser(BuildContext context, {String? chatGroupId}) {
    // Use cached squadId if available
    final squadState = Provider.of<SquadState>(context, listen: false);
    final squadId = _cachedSquadId ?? squadState.selectedSquadId;
    if (squadId == null) return Stream.value(null);

    // Use different typing status paths for squad vs group chats
    final typingPath = chatGroupId != null
        ? 'squads/$squadId/chat_groups/$chatGroupId/typing_status/status'
        : 'squads/$squadId/chat_metadata/typing_status';

    return _firestore.doc(typingPath).snapshots().map((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        final typing = data['typing'] as Map<String, dynamic>?;
        if (typing != null) {
          final typingUsers = typing.entries
              .where((entry) => entry.value == true)
              .map((entry) => entry.key)
              .toList();
          final currentUser = squadState.displayName;
          typingUsers.removeWhere((user) => user == currentUser);
          return typingUsers.isNotEmpty ? typingUsers.first : null;
        }
      }
      return null;
    });
  }

  // Send a new message
  Future<void> sendMessage(
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
    String? chatGroupId,
  }) async {
    if ((text?.trim().isEmpty ?? true) &&
        photos.isEmpty &&
        videos.isEmpty &&
        audio.isEmpty &&
        imageUrl == null &&
        videoUrl == null &&
        audioUrl == null) {
      debugPrint('Skipping empty message');
      return;
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
      'timestamp': FieldValue.serverTimestamp(),
    };

    // Get squadId from context (assume passed or injected)
    final squadState = Provider.of<SquadState>(context, listen: false);
    final squadId = squadState.selectedSquadId;
    if (squadId == null) return;

    // Determine collection path based on whether it's a group chat
    final collectionPath = chatGroupId != null
        ? 'squads/$squadId/chat_groups/$chatGroupId/messages'
        : 'squads/$squadId/chat';

    try {
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

      // Try to sync to backend if available (don't fail if it doesn't work)
      _syncToBackend(messageData).catchError((e) {
        debugPrint('Backend sync failed, but message saved locally: $e');
      });
    } catch (e) {
      debugPrint('Failed to send message: $e');
    }
  }

  // Upload media to Firebase Storage
  Future<String> uploadMedia(File file, String fileName, bool isVideo) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User must be authenticated to upload media');
    }

    Reference ref = _storage.ref().child('chat_media/$fileName');
    try {
      await _retryOperation(() async {
        await ref.putFile(file);
      });
      HapticFeedback.lightImpact();
      return await ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload media: $e');
    }
  }

  // Upload audio to Firebase Storage
  Future<String> uploadAudio(File file, String fileName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User must be authenticated to upload audio');
    }

    Reference ref = _storage.ref().child('chat_audio/$fileName');
    try {
      await _retryOperation(() async {
        await ref.putFile(file);
      });
      HapticFeedback.lightImpact();
      return await ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload audio: $e');
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

      final squadState = Provider.of<SquadState>(context, listen: false);
      final squadId = squadState.selectedSquadId;
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
      final squadState = Provider.of<SquadState>(context, listen: false);
      final squadId = squadState.selectedSquadId;
      if (squadId == null) return;

      // Determine collection path based on whether it's a group chat
      final collectionPath = chatGroupId != null
          ? 'squads/$squadId/chat_groups/$chatGroupId/messages'
          : 'squads/$squadId/chat';

      final docRef = _firestore.collection(collectionPath).doc(msgId);
      final snapshot = await docRef.get();
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        final reactions =
            List<Map<String, dynamic>>.from(data['reactions'] ?? []);
        reactions.add({'user': data['sender'], 'reaction': reaction});
        await docRef.update({'reactions': reactions});
        await _sqliteHelper.updateMessage(msgId, {'reactions': reactions});
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      debugPrint('Failed to add reaction: $e');
    }
  }

  // Fetch historical messages from PostgreSQL (removed 30-day limit)
  Future<List<Map<String, dynamic>>> loadMoreMessages({
    required int offset,
    required int limit,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://squadsync-backend-756172684661.us-central1.run.app/messages?offset=$offset&limit=$limit'),
      );
      debugPrint('Backend response: ${response.statusCode} ${response.body}');
      if (response.statusCode == 200) {
        final messages =
            List<Map<String, dynamic>>.from(json.decode(response.body));
        debugPrint(
            'Loaded ${messages.length} messages from backend: ${messages.map((m) => m['id']).toList()}');
        for (var msg in messages) {
          await _sqliteHelper.insertMessage(msg);
        }
        return messages;
      } else {
        throw Exception(
            'Failed to load historical messages: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('Failed to load messages from backend: $e');
      final cachedMessages = await _sqliteHelper.getMessages(offset, limit);
      debugPrint(
          'Loaded ${cachedMessages.length} messages from SQLite cache: ${cachedMessages.map((m) => m['id']).toList()}');
      return cachedMessages;
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

  // Sync message to backend (non-blocking)
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
}
