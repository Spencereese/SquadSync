import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:async';
import '../squad_state.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
    String? replyToMessageId, // Added for inline replies
    String? replyToContent, // Added for inline replies
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
      'replyToMessageId': replyToMessageId, // Store reply metadata
      'replyToContent': replyToContent,
    };

    try {
      await _retryOperation(() async {
        await _firestore.collection('chat').add(messageData);
      });
      HapticFeedback.mediumImpact();
    } catch (e) {
      await _cacheMessage(messageData);
      throw Exception('Failed to send message: $e. It will sync when online.');
    }
  }

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
      Provider.of<SquadState>(context, listen: false)
          .updateTypingStatus(user, isTyping);
    } catch (e) {
      throw Exception('Failed to update typing status: $e');
    }
  }

  Future<void> addReaction(String docId, String emoji) async {
    try {
      final user = FirebaseAuth.instance.currentUser!.displayName ??
          Provider.of<SquadState>(navigatorKey.currentContext!, listen: false)
              .displayName ??
          'User';
      debugPrint('Adding reaction: $emoji for docId: $docId by user: $user');
      await _retryOperation(() async {
        final querySnapshot = await _firestore
            .collection('chat')
            .doc(docId)
            .collection('reactions')
            .where('user', isEqualTo: user)
            .get();
        debugPrint(
            'Found ${querySnapshot.docs.length} existing reactions for $user');
        for (var doc in querySnapshot.docs) {
          await doc.reference.delete();
          debugPrint('Deleted existing reaction: ${doc.id}');
        }
        await _firestore
            .collection('chat')
            .doc(docId)
            .collection('reactions')
            .add({
          'emoji': emoji,
          'user': user,
          'timestamp': FieldValue.serverTimestamp(),
        });
        debugPrint('Reaction $emoji added successfully');
      });
      HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('Failed to add reaction: $e');
      if (!navigatorKey.currentContext!.mounted) return;
      ScaffoldMessenger.of(navigatorKey.currentContext!)
          .showSnackBar(SnackBar(content: Text('Failed to add reaction: $e')));
    }
  }

  Future<void> editMessage(String docId, String newText) async {
    try {
      await _retryOperation(() async {
        await _firestore
            .collection('chat')
            .doc(docId)
            .update({'text': newText, 'edited': true});
      });
    } catch (e) {
      if (!navigatorKey.currentContext!.mounted) return;
      ScaffoldMessenger.of(navigatorKey.currentContext!)
          .showSnackBar(SnackBar(content: Text('Failed to edit message: $e')));
    }
  }

  Future<void> deleteMessage(String docId) async {
    try {
      await _retryOperation(() async {
        await _firestore.collection('chat').doc(docId).delete();
      });
    } catch (e) {
      if (!navigatorKey.currentContext!.mounted) return;
      ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
          SnackBar(content: Text('Failed to delete message: $e')));
    }
  }

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

  Future<void> _cacheMessage(Map<String, dynamic> messageData) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> cachedMessages = prefs.getStringList('offline_messages') ?? [];
    cachedMessages.add(messageData.toString());
    await prefs.setStringList('offline_messages', cachedMessages);
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
