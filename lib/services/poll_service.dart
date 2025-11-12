import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/poll.dart';

class PollService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Create a new poll and return its ID
  Future<String?> createPoll({
    required String title,
    required List<String> options,
    required PollSettings settings,
    String? chatGroupId,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final pollId = '${DateTime.now().millisecondsSinceEpoch}_${user.uid}';

      // Create poll options
      final pollOptions = options.asMap().entries.map((entry) {
        return PollOption(
          id: 'option_${entry.key}',
          text: entry.value,
        );
      }).toList();

      final poll = Poll(
        id: pollId,
        title: title,
        creatorUid: user.uid,
        creatorName: user.displayName ?? 'Anonymous',
        options: pollOptions,
        isMultipleChoice: settings.isMultipleChoice,
        isAnonymous: settings.isAnonymous,
        createdAt: DateTime.now(),
        duration: settings.duration,
      );

      // Determine collection path based on chat type
      final collectionPath =
          chatGroupId != null ? 'chat_groups/$chatGroupId/polls' : 'polls';

      await _firestore.collection(collectionPath).doc(pollId).set(poll.toMap());

      return pollId;
    } catch (e) {
      return null;
    }
  }

  /// Vote on a poll option
  Future<bool> voteOnPoll({
    required String pollId,
    required List<String> optionIds,
    String? chatGroupId,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Determine collection path
      final collectionPath =
          chatGroupId != null ? 'chat_groups/$chatGroupId/polls' : 'polls';

      final pollRef = _firestore.collection(collectionPath).doc(pollId);

      return await _firestore.runTransaction((transaction) async {
        final pollDoc = await transaction.get(pollRef);
        if (!pollDoc.exists) return false;

        final poll = Poll.fromMap(pollDoc.data()!);
        if (poll.isClosed) return false;

        // Check if user already voted and handle multiple choice
        final userCurrentVotes = poll.getUserVotes(user.uid);

        if (!poll.isMultipleChoice && userCurrentVotes.isNotEmpty) {
          // Single choice: remove previous vote
          final updatedOptions = poll.options.map((option) {
            if (userCurrentVotes.contains(option.id)) {
              return option.copyWith(
                voteCount: option.voteCount - 1,
                voterUids:
                    option.voterUids.where((uid) => uid != user.uid).toList(),
              );
            }
            return option;
          }).toList();

          // Apply new vote
          final finalOptions = updatedOptions.map((option) {
            if (optionIds.contains(option.id)) {
              return option.copyWith(
                voteCount: option.voteCount + 1,
                voterUids: poll.isAnonymous
                    ? option.voterUids
                    : [...option.voterUids, user.uid],
              );
            }
            return option;
          }).toList();

          transaction.update(pollRef, {
            'options': finalOptions.map((option) => option.toMap()).toList(),
          });
        } else {
          // Multiple choice or first vote: add votes
          final updatedOptions = poll.options.map((option) {
            if (optionIds.contains(option.id) &&
                !userCurrentVotes.contains(option.id)) {
              return option.copyWith(
                voteCount: option.voteCount + 1,
                voterUids: poll.isAnonymous
                    ? option.voterUids
                    : [...option.voterUids, user.uid],
              );
            } else if (!optionIds.contains(option.id) &&
                userCurrentVotes.contains(option.id)) {
              // Remove vote for options not selected in multiple choice
              return option.copyWith(
                voteCount: option.voteCount - 1,
                voterUids:
                    option.voterUids.where((uid) => uid != user.uid).toList(),
              );
            }
            return option;
          }).toList();

          transaction.update(pollRef, {
            'options': updatedOptions.map((option) => option.toMap()).toList(),
          });
        }

        return true;
      });
    } catch (e) {
      return false;
    }
  }

  /// Close a poll (only creator can do this)
  Future<bool> closePoll({
    required String pollId,
    String? chatGroupId,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final collectionPath =
          chatGroupId != null ? 'chat_groups/$chatGroupId/polls' : 'polls';

      final pollRef = _firestore.collection(collectionPath).doc(pollId);

      return await _firestore.runTransaction((transaction) async {
        final pollDoc = await transaction.get(pollRef);
        if (!pollDoc.exists) return false;

        final poll = Poll.fromMap(pollDoc.data()!);
        if (poll.creatorUid != user.uid || poll.isClosed) return false;

        transaction.update(pollRef, {
          'isClosed': true,
          'closedAt': Timestamp.fromDate(DateTime.now()),
        });

        return true;
      });
    } catch (e) {
      print('Error closing poll: $e');
      return false;
    }
  }

  /// Get a stream of polls for a chat
  Stream<List<Poll>> getPollsStream({String? chatGroupId}) {
    final collectionPath =
        chatGroupId != null ? 'chat_groups/$chatGroupId/polls' : 'polls';

    return _firestore
        .collection(collectionPath)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Poll.fromMap(doc.data())).toList();
    });
  }

  /// Get a specific poll
  Future<Poll?> getPoll(String pollId, {String? chatGroupId}) async {
    try {
      final collectionPath =
          chatGroupId != null ? 'chat_groups/$chatGroupId/polls' : 'polls';

      final doc = await _firestore.collection(collectionPath).doc(pollId).get();
      if (doc.exists) {
        return Poll.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get a stream for a specific poll
  Stream<Poll?> getPollStream(String pollId, {String? chatGroupId}) {
    final collectionPath =
        chatGroupId != null ? 'chat_groups/$chatGroupId/polls' : 'polls';

    return _firestore
        .collection(collectionPath)
        .doc(pollId)
        .snapshots()
        .map((doc) => doc.exists ? Poll.fromMap(doc.data()!) : null);
  }
}
