import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/thread_data.dart';
import '../models/message_data.dart';

/// Service for managing chat threads
class ThreadService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create a new thread from a root message
  Future<String> createThread({
    required String rootMessageId,
    required String chatGroupId,
    required String creatorUid,
    required String creatorName,
    required String title,
    ThreadType type = ThreadType.reply,
  }) async {
    final threadData = ThreadData(
      id: '', // Will be set by Firestore
      rootMessageId: rootMessageId,
      chatGroupId: chatGroupId,
      title: title,
      creatorUid: creatorUid,
      creatorName: creatorName,
      createdAt: DateTime.now(),
      lastActivityAt: DateTime.now(),
      replyCount: 0,
      participantUids: [creatorUid],
      type: type,
    );

    final docRef =
        await _firestore.collection('threads').add(threadData.toMap());
    return docRef.id;
  }

  /// Add a message to an existing thread
  Future<void> addMessageToThread({
    required String threadId,
    required String messageId,
    required String senderUid,
    int depth = 1,
    String? parentMessageId,
  }) async {
    final batch = _firestore.batch();

    // Update thread metadata
    final threadRef = _firestore.collection('threads').doc(threadId);
    batch.update(threadRef, {
      'lastActivityAt': Timestamp.now(),
      'replyCount': FieldValue.increment(1),
      'participantUids': FieldValue.arrayUnion([senderUid]),
    });

    // Add thread message data
    final threadMessageRef =
        _firestore.collection('thread_messages').doc(messageId);
    batch.set(threadMessageRef, {
      'messageId': messageId,
      'threadId': threadId,
      'depth': depth,
      'parentMessageId': parentMessageId,
      'childMessageIds': [],
      'createdAt': Timestamp.now(),
    });

    // Update parent message if it exists
    if (parentMessageId != null) {
      final parentRef =
          _firestore.collection('thread_messages').doc(parentMessageId);
      batch.update(parentRef, {
        'childMessageIds': FieldValue.arrayUnion([messageId]),
      });
    }

    await batch.commit();
  }

  /// Get thread data by ID
  Future<ThreadData?> getThread(String threadId) async {
    final doc = await _firestore.collection('threads').doc(threadId).get();
    if (!doc.exists) return null;
    return ThreadData.fromDocument(doc);
  }

  /// Get all threads for a chat group
  Stream<List<ThreadData>> getThreadsForChatGroup(String chatGroupId) {
    return _firestore
        .collection('threads')
        .where('chatGroupId', isEqualTo: chatGroupId)
        .where('isArchived', isEqualTo: false)
        .orderBy('lastActivityAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ThreadData.fromDocument(doc)).toList());
  }

  /// Get messages in a thread
  Future<List<MessageData>> getThreadMessages(String threadId) async {
    // First get all thread message data
    final threadMessagesSnapshot = await _firestore
        .collection('thread_messages')
        .where('threadId', isEqualTo: threadId)
        .orderBy('createdAt')
        .get();

    if (threadMessagesSnapshot.docs.isEmpty) return [];

    // Get message IDs
    final messageIds = threadMessagesSnapshot.docs
        .map((doc) => doc.data()['messageId'] as String)
        .toList();

    // Fetch actual messages
    final messages = <MessageData>[];
    for (final messageId in messageIds) {
      final messageDoc =
          await _firestore.collection('messages').doc(messageId).get();

      if (messageDoc.exists) {
        messages.add(MessageData.fromDocument(messageDoc));
      }
    }

    return messages;
  }

  /// Archive a thread
  Future<void> archiveThread(String threadId) async {
    await _firestore.collection('threads').doc(threadId).update({
      'isArchived': true,
    });
  }

  /// Mute/unmute a thread
  Future<void> toggleThreadMute(String threadId, bool isMuted) async {
    await _firestore.collection('threads').doc(threadId).update({
      'isMuted': isMuted,
    });
  }

  /// Update thread title
  Future<void> updateThreadTitle(String threadId, String newTitle) async {
    await _firestore.collection('threads').doc(threadId).update({
      'title': newTitle,
    });
  }

  /// Get thread statistics for a chat group
  Future<Map<String, dynamic>> getThreadStats(String chatGroupId) async {
    final threadsSnapshot = await _firestore
        .collection('threads')
        .where('chatGroupId', isEqualTo: chatGroupId)
        .where('isArchived', isEqualTo: false)
        .get();

    int totalThreads = threadsSnapshot.docs.length;
    int activeThreads = threadsSnapshot.docs
        .where((doc) => (doc.data()['replyCount'] ?? 0) > 0)
        .length;

    int totalReplies = threadsSnapshot.docs
        .map((doc) => (doc.data()['replyCount'] ?? 0) as int)
        .reduce((a, b) => a + b);

    return {
      'totalThreads': totalThreads,
      'activeThreads': activeThreads,
      'totalReplies': totalReplies,
    };
  }
}
