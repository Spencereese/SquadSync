import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'chat_state.dart'; // Updated to local import

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<QuerySnapshot> getChatMessages() {
    return _firestore
        .collection('chat')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Stream<String?> getTypingUser() {
    return _firestore
        .collection('squad')
        .doc('state')
        .snapshots()
        .map((snapshot) {
      Map<String, dynamic>? data = snapshot.data() as Map<String, dynamic>?;
      if (data == null || data['typing'] == null) return null;
      Map<String, dynamic> typing = data['typing'] as Map<String, dynamic>;
      String? typingUser = typing.entries
          .where((entry) => entry.value == true)
          .map((entry) => entry.key)
          .firstOrNull;
      return typingUser;
    });
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

  Future<void> updateTypingStatus(String user, bool isTyping) async {
    await _firestore.collection('squad').doc('state').set({
      'typing': {user: isTyping},
    }, SetOptions(merge: true));
  }
}
