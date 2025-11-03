import 'achievement_manager.dart';

/// Service for handling achievement-related operations like ratings and complaints
class AchievementService {
  final AchievementManager _achievementManager;

  AchievementService(this._achievementManager);

  /// Submit a complaint about a squad member
  Future<void> submitComplaint({
    required String targetMember,
    required String reason,
    required String category,
    required String submittedBy,
    required List<String> squadMembers,
  }) async {
    await _achievementManager.submitComplaint(
      submittedBy: submittedBy,
      targetMember: targetMember,
      reason: reason,
      category: category,
      squadMembers: squadMembers,
    );
  }

  /// Submit ratings for a squad member
  Future<void> submitRatings({
    required String targetMember,
    required Map<String, int?> ratings,
    required String submittedBy,
    required List<String> squadMembers,
    required List<Map<String, dynamic>> gameHistory,
  }) async {
    await _achievementManager.submitRatings(
      submittedBy: submittedBy,
      targetMember: targetMember,
      ratings: ratings,
      squadMembers: squadMembers,
      gameHistory: gameHistory,
    );
  }

  /// Check if a member has already been rated by the submitter in their latest shared game
  Future<bool> hasRatedMember(String targetMember, String submittedBy,
      List<Map<String, dynamic>> gameHistory) async {
    final sharedGames = gameHistory
        .where((game) =>
            (game['players'] as List).contains(targetMember) &&
            (game['players'] as List).contains(submittedBy) &&
            (game['result'] == 'Win' || game['result'] == 'Loss'))
        .toList();
    if (sharedGames.isEmpty) return false;
    final latestGame = sharedGames.last;
    final ratings = latestGame['ratings'] as Map? ?? {};
    final submittedRatings = ratings[submittedBy] as Map? ?? {};
    return submittedRatings.containsKey(targetMember);
  }

  /// Check if a member can be rated (has played games together)
  Future<bool> canRateMember(String targetMember, String submittedBy,
      List<Map<String, dynamic>> gameHistory) async {
    return gameHistory.any((game) =>
        (game['players'] as List).contains(targetMember) &&
        (game['players'] as List).contains(submittedBy) &&
        (game['result'] == 'Win' || game['result'] == 'Loss'));
  }

  /// Get average rating for a member in a specific category
  double getAverageRating(
      String member, String category, List<Map<String, dynamic>> gameHistory) {
    final memberGames = gameHistory.where((game) =>
        (game['players'] as List).contains(member) &&
        (game['result'] == 'Win' || game['result'] == 'Loss'));

    final ratings = <int>[];
    for (final game in memberGames) {
      final gameRatings = game['ratings'] as Map? ?? {};
      for (final playerRatings in gameRatings.values) {
        if (playerRatings is Map && playerRatings.containsKey(member)) {
          final memberRating = playerRatings[member];
          if (memberRating is Map && memberRating.containsKey(category)) {
            final rating = memberRating[category];
            if (rating is int) {
              ratings.add(rating);
            }
          }
        }
      }
    }

    if (ratings.isEmpty) return 0.0;
    return ratings.reduce((a, b) => a + b) / ratings.length;
  }
}
