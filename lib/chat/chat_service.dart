import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  // Stream for real-time messages from Firestore
  Stream<QuerySnapshot> getChatMessages() {
    return _firestore
        .collection('chat')
        .orderBy('timestamp_ms', descending: true)
        .snapshots();
  }

  // Stream for typing status
  Stream<String?> getTypingUser(BuildContext context) {
    return Stream.value(
        Provider.of<SquadState>(context, listen: true).getTypingUser());
  }

  // Send a new message
  Future<void> sendMessage({
    required String sender,
    required String text,
    String? imageUrl,
    String? videoUrl,
    String? audioUrl,
    List<Map<String, dynamic>> photos = const [],
    List<Map<String, dynamic>> videos = const [],
    List<Map<String, dynamic>> audio = const [],
    List<Map<String, dynamic>> reactions = const [],
    String? replyTo,
  }) async {
    final msgId = Uuid().v4();
    final timestampMs = DateTime.now().millisecondsSinceEpoch;
    final messageData = {
      'id': msgId,
      'sender': sender,
      'sender_name': sender,
      'timestamp_ms': timestampMs,
      'text': text,
      'content': text,
      'imageUrl': imageUrl,
      'videoUrl': videoUrl,
      'audioUrl': audioUrl,
      'photos': photos,
      'videos': videos,
      'audio': audio,
      'reactions': reactions,
      'is_geoblocked_for_viewer': false,
      'is_unsent_image_by_messenger_kid_parent': false,
      'delivered': false,
      'read': false,
      'reply_to': replyTo,
      'timestamp': FieldValue.serverTimestamp(),
    };

    try {
      await _retryOperation(() async {
        await _firestore.collection('chat').doc(msgId).set(messageData);
      });
      // Cache in SQLite
      await _sqliteHelper.insertMessage(messageData);
      // Store in PostgreSQL via backend
      final response = await http.post(
        Uri.parse('https://your-backend-url/messages'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          ...messageData,
          'created_at': DateTime.now().toIso8601String(),
        }),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to save message to PostgreSQL');
      }
      HapticFeedback.mediumImpact();
    } catch (e) {
      await _cacheMessage(messageData);
      throw Exception('Failed to send message: $e. It will sync when online.');
    }
  }

  // Upload media to Firebase Storage
  Future<String> uploadMedia(File file, String fileName, bool isVideo) async {
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
      BuildContext context, String user, bool isTyping) async {
    try {
      if (user.isEmpty) return;
      Provider.of<SquadState>(context, listen: false)
          .updateTypingStatus(user, isTyping);
      await _firestore.collection('chat_metadata').doc('typing_status').set({
        'typing': {user: isTyping},
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to update typing status: $e');
    }
  }

  // Add reaction to a message
  Future<void> addReaction(String msgId, String reaction) async {
    try {
      final docRef = _firestore.collection('chat').doc(msgId);
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

  // Fetch historical messages from PostgreSQL
  Future<List<Map<String, dynamic>>> loadMoreMessages({
    required int offset,
    required int limit,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://your-backend-url/messages?offset=$offset&limit=$limit'),
      );
      if (response.statusCode == 200) {
        final messages =
            List<Map<String, dynamic>>.from(json.decode(response.body));
        // Cache in SQLite
        for (var msg in messages) {
          await _sqliteHelper.insertMessage(msg);
        }
        return messages;
      } else {
        throw Exception('Failed to load historical messages');
      }
    } catch (e) {
      debugPrint('Failed to load messages from backend: $e');
      // Fallback to SQLite
      return await _sqliteHelper.getMessages(offset, limit);
    }
  }

  // Get cached messages from SQLite
  Future<List<Map<String, dynamic>>> getCachedMessages(
      int offset, int limit) async {
    return await _sqliteHelper.getMessages(offset, limit);
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

  // Cache message for offline sync
  Future<void> _cacheMessage(Map<String, dynamic> messageData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> cachedMessages =
          prefs.getStringList('offline_messages') ?? [];
      cachedMessages.add(json.encode(messageData));
      await prefs.setStringList('offline_messages', cachedMessages);
    } catch (e) {
      debugPrint('Failed to cache message: $e');
    }
  }
}
