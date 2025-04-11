import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:async';
import '../squad_state.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  static const int _maxRetries = 3;
  static const Duration _initialBackoff = Duration(milliseconds: 500);

  Stream<QuerySnapshot> getChatMessages() {
    return _firestore
        .collection('chat')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Stream<String?> getTypingUser(BuildContext context) {
    return Stream.value(
        Provider.of<SquadState>(context, listen: true).getTypingUser());
  }

  Future<void> sendMessage({
    required String sender,
    required String text,
    String? imageUrl,
    String? videoUrl,
    String? audioUrl,
  }) async {
    final messageData = {
      'sender': sender,
      'text': text,
      'imageUrl': imageUrl,
      'videoUrl': videoUrl,
      'audioUrl': audioUrl,
      'timestamp': FieldValue.serverTimestamp(),
      'delivered': false,
      'read': false,
    };

    try {
      await _retryOperation(() async {
        await _firestore.collection('chat').add(messageData);
      });
      HapticFeedback.mediumImpact(); // iOS haptic feedback
    } catch (e) {
      await _cacheMessage(messageData); // Cache for offline sync
      throw Exception('Failed to send message: $e. It will sync when online.');
    }
  }

  Future<String> uploadMedia(File file, String fileName, bool isVideo) async {
    Reference ref = _storage.ref().child('chat_media/$fileName');
    try {
      await _retryOperation(() async {
        await ref.putFile(file);
      });
      HapticFeedback.lightImpact(); // iOS haptic feedback
      return await ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload media: $e');
    }
  }

  Future<String> uploadAudio(File file, String fileName) async {
    Reference ref = _storage.ref().child('chat_audio/$fileName');
    try {
      await _retryOperation(() async {
        await ref.putFile(file);
      });
      HapticFeedback.lightImpact(); // iOS haptic feedback
      return await ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload audio: $e');
    }
  }

  Future<void> markAsDelivered(String docId) async {
    try {
      await _retryOperation(() async {
        await _firestore
            .collection('chat')
            .doc(docId)
            .update({'delivered': true});
      });
    } catch (e) {
      throw Exception('Failed to mark as delivered: $e');
    }
  }

  Future<void> updateTypingStatus(
      BuildContext context, String user, bool isTyping) async {
    try {
      if (user.isEmpty) return; // Prevent empty user
      Provider.of<SquadState>(context, listen: false)
          .updateTypingStatus(user, isTyping);
      await _firestore.collection('chat_metadata').doc('typing_status').set({
        'typing': {user: isTyping}, // Non-empty map
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Failed to update typing status: $e');
      // Optionally rethrow if you want ChatScreen to handle it
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

  // Cache message for offline sync
  Future<void> _cacheMessage(Map<String, dynamic> messageData) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> cachedMessages = prefs.getStringList('offline_messages') ?? [];
    cachedMessages.add(messageData.toString());
    await prefs.setStringList('offline_messages', cachedMessages);
  }
}
