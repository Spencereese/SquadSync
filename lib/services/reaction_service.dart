import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../domain/entities/message.dart';

/// Service for managing message reactions
class ReactionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Add a reaction to a message
  Future<void> addReaction({
    required String chatGroupId,
    required String messageId,
    required String emoji,
    required ChatType chatType,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    String collectionPath;
    if (chatType == ChatType.userGroup) {
      collectionPath = 'users/${user.uid}/chat_groups/$chatGroupId/messages';
    } else if (chatType == ChatType.dm) {
      collectionPath = 'chats/$chatGroupId/messages';
    } else {
      return;
    }

    final reactionId = '${user.uid}_$emoji';

    await _firestore
        .collection(collectionPath)
        .doc(messageId)
        .collection('reactions')
        .doc(reactionId)
        .set({
      'userId': user.uid,
      'emoji': emoji,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Remove a reaction from a message
  Future<void> removeReaction({
    required String chatGroupId,
    required String messageId,
    required String emoji,
    required ChatType chatType,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    String collectionPath;
    if (chatType == ChatType.userGroup) {
      collectionPath = 'users/${user.uid}/chat_groups/$chatGroupId/messages';
    } else if (chatType == ChatType.dm) {
      collectionPath = 'chats/$chatGroupId/messages';
    } else {
      return;
    }

    final reactionId = '${user.uid}_$emoji';

    await _firestore
        .collection(collectionPath)
        .doc(messageId)
        .collection('reactions')
        .doc(reactionId)
        .delete();
  }

  /// Get reactions for a message
  Stream<Map<String, List<String>>> getMessageReactions({
    required String chatGroupId,
    required String messageId,
    required ChatType chatType,
  }) {
    final user = _auth.currentUser;
    if (user == null) return Stream.value({});

    String collectionPath;
    if (chatType == ChatType.userGroup) {
      collectionPath = 'users/${user.uid}/chat_groups/$chatGroupId/messages';
    } else if (chatType == ChatType.dm) {
      collectionPath = 'chats/$chatGroupId/messages';
    } else {
      return Stream.value({});
    }

    return _firestore
        .collection(collectionPath)
        .doc(messageId)
        .collection('reactions')
        .snapshots()
        .map((snapshot) {
      final reactions = <String, List<String>>{};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final emoji = data['emoji'] as String;
        final userId = data['userId'] as String;

        if (!reactions.containsKey(emoji)) {
          reactions[emoji] = [];
        }
        reactions[emoji]!.add(userId);
      }

      return reactions;
    });
  }

  /// Check if current user has reacted with specific emoji
  Future<bool> hasUserReacted({
    required String chatGroupId,
    required String messageId,
    required String emoji,
    required ChatType chatType,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    String collectionPath;
    if (chatType == ChatType.userGroup) {
      collectionPath = 'users/${user.uid}/chat_groups/$chatGroupId/messages';
    } else if (chatType == ChatType.dm) {
      collectionPath = 'chats/$chatGroupId/messages';
    } else {
      return false;
    }

    final reactionId = '${user.uid}_$emoji';

    final doc = await _firestore
        .collection(collectionPath)
        .doc(messageId)
        .collection('reactions')
        .doc(reactionId)
        .get();

    return doc.exists;
  }
}
