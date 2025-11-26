import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:squad_sync/domain/entities/message.dart';
import 'package:squad_sync/domain/entities/chat_group.dart';
import 'package:squad_sync/data/datasources/chat_remote_datasource.dart';

class ChatRemoteDataSourceImpl implements ChatRemoteDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  ChatRemoteDataSourceImpl(this._firestore, this._storage);

  @override
  Future<Message> sendMessage(
      String chatGroupId, Message message, ChatType chatType) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    String collectionPath;
    if (chatType == ChatType.userGroup) {
      collectionPath =
          'users/${currentUser.uid}/chat_groups/$chatGroupId/messages';
    } else if (chatType == ChatType.dm) {
      collectionPath = 'chats/$chatGroupId/messages';
    } else {
      // For squad chats, use the original path
      collectionPath = 'chat/$chatGroupId/messages';
    }

    final docRef = _firestore.collection(collectionPath).doc(message.id);
    await docRef.set(message.toJson());
    return message;
  }

  @override
  Future<List<Message>> fetchMessages(String chatGroupId,
      {int limit = 50, DateTime? before}) async {
    Query query = _firestore
        .collection('chat')
        .doc(chatGroupId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(limit);

    if (before != null) {
      query = query.where('timestamp', isLessThan: before);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => Message.fromJson(doc.data() as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> deleteMessage(String chatGroupId, String messageId) async {
    await _firestore
        .collection('chat')
        .doc(chatGroupId)
        .collection('messages')
        .doc(messageId)
        .delete();
  }

  @override
  Future<void> editMessage(
      String chatGroupId, String messageId, String newText) async {
    await _firestore
        .collection('chat')
        .doc(chatGroupId)
        .collection('messages')
        .doc(messageId)
        .update({
      'text': newText,
      'isEdited': true,
      'editedAt': FieldValue.serverTimestamp()
    });
  }

  @override
  Stream<List<Message>> watchMessages(String chatGroupId) {
    return _firestore
        .collection('chat')
        .doc(chatGroupId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Message.fromJson(doc.data())).toList());
  }

  @override
  Stream<Map<String, Set<String>>> watchTypingIndicators(String chatGroupId) {
    return _firestore
        .collection('chat')
        .doc(chatGroupId)
        .collection('typing')
        .snapshots()
        .map((snapshot) {
      final typing = <String, Set<String>>{};
      for (final doc in snapshot.docs) {
        final userId = doc.id;
        final indicators = (doc.data()['indicators'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toSet() ??
            {};
        typing[userId] = indicators;
      }
      return typing;
    });
  }

  @override
  Stream<Map<String, int>> watchUnreadCounts(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('unread_counts')
        .snapshots()
        .map((snapshot) {
      final counts = <String, int>{};
      for (final doc in snapshot.docs) {
        counts[doc.id] = doc.data()['count'] as int? ?? 0;
      }
      return counts;
    });
  }

  @override
  Future<void> addReaction(String chatGroupId, String messageId, String userId,
      String reaction) async {
    await _firestore
        .collection('chat')
        .doc(chatGroupId)
        .collection('messages')
        .doc(messageId)
        .update({
      'reactions.$userId': reaction,
    });
  }

  @override
  Future<void> removeReaction(String chatGroupId, String messageId,
      String userId, String reaction) async {
    await _firestore
        .collection('chat')
        .doc(chatGroupId)
        .collection('messages')
        .doc(messageId)
        .update({
      'reactions.$userId': FieldValue.delete(),
    });
  }

  @override
  Future<Map<String, int>> getMessageReactions(
      String chatGroupId, String messageId) async {
    final doc = await _firestore
        .collection('chat')
        .doc(chatGroupId)
        .collection('messages')
        .doc(messageId)
        .get();

    final reactions = doc.data()?['reactions'] as Map<String, dynamic>? ?? {};
    final reactionCounts = <String, int>{};

    for (final reaction in reactions.values) {
      reactionCounts[reaction as String] = (reactionCounts[reaction] ?? 0) + 1;
    }

    return reactionCounts;
  }

  @override
  Future<Poll> createPoll(String chatGroupId, Poll poll) async {
    final docRef = _firestore
        .collection('chat')
        .doc(chatGroupId)
        .collection('polls')
        .doc(poll.id);

    await docRef.set(poll.toJson());
    return poll;
  }

  @override
  Future<void> votePoll(
      String chatGroupId, String pollId, String option, String voterId) async {
    await _firestore
        .collection('chat')
        .doc(chatGroupId)
        .collection('polls')
        .doc(pollId)
        .update({
      'votes.$voterId': option,
    });
  }

  @override
  Future<void> closePoll(String chatGroupId, String pollId) async {
    await _firestore
        .collection('chat')
        .doc(chatGroupId)
        .collection('polls')
        .doc(pollId)
        .update({
      'isClosed': true,
    });
  }

  @override
  Future<String> uploadMedia(
      File file, String mediaType, String chatGroupId) async {
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
    final ref = _storage.ref().child('chat_media/$fileName');

    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  @override
  Future<void> deleteMedia(String mediaUrl) async {
    final uri = Uri.parse(mediaUrl);
    final path = uri.pathSegments.skip(1).join('/');
    await _storage.ref().child(path).delete();
  }

  @override
  Future<ChatGroup> createGroup(ChatGroup group) async {
    await _firestore
        .collection('chat_groups')
        .doc(group.id)
        .set(group.toJson());
    return group;
  }

  @override
  Future<void> joinGroup(String groupId, String userId) async {
    await _firestore.collection('chat_groups').doc(groupId).update({
      'memberIds': FieldValue.arrayUnion([userId]),
    });
  }

  @override
  Future<void> leaveGroup(String groupId, String userId) async {
    await _firestore.collection('chat_groups').doc(groupId).update({
      'memberIds': FieldValue.arrayRemove([userId]),
    });
  }

  @override
  Future<List<ChatGroup>> discoverGroups(
      {String? query, int limit = 20}) async {
    Query queryRef = _firestore.collection('chat_groups');

    if (query != null && query.isNotEmpty) {
      queryRef = queryRef
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThan: query + 'z');
    }

    final snapshot = await queryRef.limit(limit).get();
    return snapshot.docs
        .map((doc) => ChatGroup.fromJson(doc.data() as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> updateGroupSettings(
      String groupId, Map<String, dynamic> settings) async {
    await _firestore.collection('chat_groups').doc(groupId).update(settings);
  }

  @override
  Future<void> updateTypingIndicator(
      String chatGroupId, String userId, bool isTyping) async {
    if (!isTyping) {
      await _firestore
          .collection('chat')
          .doc(chatGroupId)
          .collection('typing')
          .doc(userId)
          .delete();
    } else {
      await _firestore
          .collection('chat')
          .doc(chatGroupId)
          .collection('typing')
          .doc(userId)
          .set({
        'isTyping': true,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Future<void> pinMessage(String chatGroupId, String messageId) async {
    await _firestore
        .collection('chat')
        .doc(chatGroupId)
        .collection('messages')
        .doc(messageId)
        .update({
      'isPinned': true,
      'pinnedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> unpinMessage(String chatGroupId, String messageId) async {
    await _firestore
        .collection('chat')
        .doc(chatGroupId)
        .collection('messages')
        .doc(messageId)
        .update({
      'isPinned': false,
    });
  }

  @override
  Future<String> getAiResponse(String message, String context) async {
    return "This is a placeholder AI response.";
  }

  @override
  Future<List<Message>> fetchMessagesSince(
      String chatGroupId, DateTime since) async {
    final snapshot = await _firestore
        .collection('chat')
        .doc(chatGroupId)
        .collection('messages')
        .where('timestamp', isGreaterThan: since)
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs.map((doc) => Message.fromJson(doc.data())).toList();
  }

  @override
  Future<void> batchSyncMessages(
      String chatGroupId, List<Message> messages) async {
    final batch = _firestore.batch();

    for (final message in messages) {
      final docRef = _firestore
          .collection('chat')
          .doc(chatGroupId)
          .collection('messages')
          .doc(message.id);
      batch.set(docRef, message.toJson());
    }

    await batch.commit();
  }

  @override
  Future<void> trackMessageEvent(String chatGroupId, String messageId,
      String event, Map<String, dynamic> data) async {
    // TODO: Implement analytics tracking
  }

  @override
  Future<void> startVoiceChat(
      String chatGroupId, List<String> participantIds) async {
    await _firestore.collection('voice_chats').doc(chatGroupId).set({
      'participants': participantIds,
      'startedAt': FieldValue.serverTimestamp(),
      'isActive': true,
    });
  }

  @override
  Future<void> endVoiceChat(String chatGroupId) async {
    await _firestore.collection('voice_chats').doc(chatGroupId).update({
      'isActive': false,
      'endedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> updateVoiceChatParticipants(
      String chatGroupId, List<String> participantIds) async {
    await _firestore.collection('voice_chats').doc(chatGroupId).update({
      'participants': participantIds,
    });
  }
}
