import 'dart:async';

/// Service responsible for managing ban voting operations including
/// adding votes, calculating vote counts, determining bans, and scheduling resets.
class BanVotingService {
  final Map<String, Map<String, int>> Function() getDailyBanVotes;
  final Map<String, int> Function() getBans;
  final List<String> Function() getSquadMembers;
  final Map<String, bool> Function(String) getUserBlocks;

  Timer? _dailyResetTimer;

  final void Function() _markFieldChanged;
  final void Function() _notifyListeners;

  BanVotingService({
    required this.getDailyBanVotes,
    required this.getBans,
    required this.getSquadMembers,
    required this.getUserBlocks,
    required void Function() markFieldChanged,
    required void Function() notifyListeners,
  })  : _markFieldChanged = markFieldChanged,
        _notifyListeners = notifyListeners {
    _scheduleDailyReset();
  }

  /// Adds a ban vote from a voter to a target player
  void addBan(String player, String voter) {
    final dailyBanVotes = getDailyBanVotes();
    // Initialize daily ban votes if not exists
    if (!dailyBanVotes.containsKey(player)) {
      dailyBanVotes[player] = {};
    }
    // Add vote (will overwrite if already voted today)
    dailyBanVotes[player]![voter] = DateTime.now().millisecondsSinceEpoch;
    _markFieldChanged();
    _notifyListeners();
  }

  /// Gets the total ban vote count for a player
  int getBanVoteCount(String player) {
    final dailyBanVotes = getDailyBanVotes();
    final squadMembers = getSquadMembers();

    // Count explicit votes (excluding self-votes)
    int explicitVotes = 0;
    final playerVotes = dailyBanVotes[player];
    if (playerVotes != null) {
      // Only count votes from other players
      explicitVotes = playerVotes.keys.where((voter) => voter != player).length;
    }

    // Add votes from blocked users (mutual blocking counts as a vote for each other)
    for (final member in squadMembers) {
      if (member != player && // Exclude self
          isUserBlockedBy(player, member) &&
          isUserBlockedBy(member, player)) {
        // Mutual block - each counts as a vote for the other
        explicitVotes += 1;
      }
    }

    return explicitVotes;
  }

  /// Checks if a player is currently banned
  bool isBanned(String player) {
    final squadMembers = getSquadMembers();
    final totalEligibleVoters =
        squadMembers.length - 1; // Exclude the player themselves
    final voteCount = getBanVoteCount(player);
    // Banned if more than half the other squad members vote for ban
    return totalEligibleVoters > 0 && voteCount > (totalEligibleVoters / 2);
  }

  /// Gets the ban duration for a player in milliseconds
  int getBanDuration(String player) {
    final squadMembers = getSquadMembers();
    final totalEligibleVoters =
        squadMembers.length - 1; // Exclude the player themselves
    final voteCount = getBanVoteCount(player);

    if (voteCount >= totalEligibleVoters) {
      // All other users voted - 48 hour ban
      return 48 * 3600 * 1000;
    } else if (voteCount > (totalEligibleVoters / 2)) {
      // More than half voted - 24 hour ban
      return 24 * 3600 * 1000;
    }
    return 0;
  }

  /// Gets the number of bans a player has received
  int getBanCount(String player) {
    final bans = getBans();
    return bans[player] ?? 0;
  }

  /// Checks if user A is blocked by user B
  bool isUserBlockedBy(String targetUser, String blocker) {
    final userBlocks = getUserBlocks(blocker);
    return userBlocks[targetUser] ?? false;
  }

  /// Resets daily ban votes (called automatically at midnight)
  void _resetDailyBanVotes() {
    final dailyBanVotes = getDailyBanVotes();
    dailyBanVotes.clear();
    _markFieldChanged();
    _notifyListeners();
  }

  /// Schedules the daily reset of ban votes at midnight
  void _scheduleDailyReset() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final timeUntilMidnight = tomorrow.difference(now);

    _dailyResetTimer?.cancel();
    _dailyResetTimer = Timer(timeUntilMidnight, () {
      _resetDailyBanVotes();
      // Schedule next reset
      _scheduleDailyReset();
    });
  }

  /// Disposes of the service and cancels timers
  void dispose() {
    _dailyResetTimer?.cancel();
  }
}
