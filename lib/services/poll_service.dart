import 'auth_service_supabase.dart';
import 'supabase_service.dart';
import 'package:logger/logger.dart';
import '../models/poll.dart';

class PollService {
  final Logger _logger = Logger();
  final AuthServiceSupabase _authService = AuthServiceSupabase();

  /// Create a new poll and return its ID
  Future<String?> createPoll({
    required String title,
    required List<String> options,
    required PollSettings settings,
    String? chatGroupId,
    String? creatorName,
  }) async {
    try {
      final user = _authService.currentUser;
      if (user == null) return null;

      final pollId = '${DateTime.now().millisecondsSinceEpoch}_${user.id}';

      // Create poll options
      final pollOptions = options.asMap().entries.map((entry) {
        return PollOption(
          id: 'option_${entry.key}',
          text: entry.value,
        );
      }).toList();

      await SupabaseService.client.from('polls').insert({
        'id': pollId,
        'title': title,
        'creator_uid': user.id,
        'creator_name':
            creatorName ?? user.userMetadata?['display_name'] ?? 'Anonymous',
        'options': pollOptions.map((o) => o.toMap()).toList(),
        'is_multiple_choice': settings.isMultipleChoice,
        'is_anonymous': settings.isAnonymous,
        'created_at': DateTime.now().toIso8601String(),
        'duration': settings.duration?.inMinutes,
        'chat_group_id': chatGroupId,
        'is_closed': false,
      });

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
      final user = _authService.currentUser;
      if (user == null) return false;

      // Get current poll data
      final pollData = await SupabaseService.client
          .from('polls')
          .select()
          .eq('id', pollId)
          .maybeSingle();

      if (pollData == null) return false;

      final poll = Poll.fromMap(pollData);
      if (poll.isClosed) return false;

      // Check if user already voted and handle multiple choice
      final userCurrentVotes = poll.getUserVotes(user.id);

      List<PollOption> updatedOptions;

      if (!poll.isMultipleChoice && userCurrentVotes.isNotEmpty) {
        // Single choice: remove previous vote
        updatedOptions = poll.options.map((option) {
          if (userCurrentVotes.contains(option.id)) {
            return option.copyWith(
              voteCount: option.voteCount - 1,
              voterUids:
                  option.voterUids.where((uid) => uid != user.id).toList(),
            );
          }
          return option;
        }).toList();

        // Apply new vote
        updatedOptions = updatedOptions.map((option) {
          if (optionIds.contains(option.id)) {
            return option.copyWith(
              voteCount: option.voteCount + 1,
              voterUids: poll.isAnonymous
                  ? option.voterUids
                  : [...option.voterUids, user.id],
            );
          }
          return option;
        }).toList();
      } else {
        // Multiple choice or first vote: add votes
        updatedOptions = poll.options.map((option) {
          if (optionIds.contains(option.id) &&
              !userCurrentVotes.contains(option.id)) {
            return option.copyWith(
              voteCount: option.voteCount + 1,
              voterUids: poll.isAnonymous
                  ? option.voterUids
                  : [...option.voterUids, user.id],
            );
          } else if (!optionIds.contains(option.id) &&
              userCurrentVotes.contains(option.id)) {
            // Remove vote for options not selected in multiple choice
            return option.copyWith(
              voteCount: option.voteCount - 1,
              voterUids:
                  option.voterUids.where((uid) => uid != user.id).toList(),
            );
          }
          return option;
        }).toList();
      }

      await SupabaseService.client.from('polls').update({
        'options': updatedOptions.map((o) => o.toMap()).toList()
      }).eq('id', pollId);

      return true;
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
      final user = _authService.currentUser;
      if (user == null) return false;

      // Get poll to verify creator
      final pollData = await SupabaseService.client
          .from('polls')
          .select()
          .eq('id', pollId)
          .maybeSingle();

      if (pollData == null) return false;

      final poll = Poll.fromMap(pollData);
      if (poll.creatorUid != user.id || poll.isClosed) return false;

      await SupabaseService.client.from('polls').update({
        'is_closed': true,
        'closed_at': DateTime.now().toIso8601String(),
      }).eq('id', pollId);

      return true;
    } catch (e) {
      _logger.e('Error closing poll: $e');
      return false;
    }
  }

  /// Get a stream of polls for a chat
  Stream<List<Poll>> getPollsStream({String? chatGroupId}) {
    final stream = chatGroupId != null
        ? SupabaseService.client
            .from('polls')
            .stream(primaryKey: ['id'])
            .eq('chat_group_id', chatGroupId)
            .order('created_at', ascending: false)
        : SupabaseService.client
            .from('polls')
            .stream(primaryKey: ['id']).order('created_at', ascending: false);

    return stream.map((data) {
      return data.map((json) => Poll.fromMap(json)).toList();
    });
  }

  /// Get a specific poll
  Future<Poll?> getPoll(String pollId, {String? chatGroupId}) async {
    try {
      final data = await SupabaseService.client
          .from('polls')
          .select()
          .eq('id', pollId)
          .maybeSingle();

      if (data != null) {
        return Poll.fromMap(data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get a stream for a specific poll
  Stream<Poll?> getPollStream(String pollId, {String? chatGroupId}) {
    return SupabaseService.client
        .from('polls')
        .stream(primaryKey: ['id'])
        .eq('id', pollId)
        .map((data) => data.isNotEmpty ? Poll.fromMap(data.first) : null);
  }
}
