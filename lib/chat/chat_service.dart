import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart'; // Added for BuildContext
import 'package:provider/provider.dart';
import 'dart:io';
import '../squad_state.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<QuerySnapshot> getChatMessages() {
    return _firestore
        .collection('chat')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Stream<String?> getTypingUser() {
    throw UnimplementedError(
        'Use Provider.of<SquadState>.getTypingUser() instead');
  }

  Future<void> sendMessage({
    required String sender,
    required String text,
    String? imageUrl,
    String? videoUrl,
    String? audioUrl,
  }) async {
    await _firestore.collection('chat').add({
      'sender': sender,
      'text': text,
      'imageUrl': imageUrl,
      'videoUrl': videoUrl,
      'audioUrl': audioUrl,
      'timestamp': FieldValue.serverTimestamp(),
      'delivered': false,
      'read': false,
    });
  }

  Future<String> uploadMedia(File file, String fileName, bool isVideo) async {
    Reference ref =
        FirebaseStorage.instance.ref().child('chat_media/$fileName');
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  Future<String> uploadAudio(File file, String fileName) async {
    Reference ref =
        FirebaseStorage.instance.ref().child('chat_audio/$fileName');
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  Future<void> markAsDelivered(String docId) async {
    await _firestore.collection('chat').doc(docId).update({'delivered': true});
  }

  Future<void> updateTypingStatus(
      BuildContext context, String user, bool isTyping) async {
    Provider.of<SquadState>(context, listen: false)
        .updateTypingStatus(user, isTyping);
  }
}
