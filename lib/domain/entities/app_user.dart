import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_user.freezed.dart';
part 'app_user.g.dart';

@freezed
class AppUser with _$AppUser {
  const factory AppUser({
    required String uid,
    required String? displayName,
    required String? profileImage,
    required Map<String, String?> preferredModes,
    required Map<String, Map<String, bool>> userBlocks,
    required List<Map<String, dynamic>> pinnedGames,
    required Set<String> mutedGames,
    required Map<String, bool> hasRatedGame,
    required Map<String, Map<String, int>> dailyRatings,
    required Map<String, Map<String, int>> allTimeRatings,
    required Map<String, int> currentStreaks,
    required Map<String, Map<String, int>> complaints,
    required Map<String, List<Map<String, dynamic>>> bans,
    required Map<String, Map<String, bool>> dailyBanVotes,
    required List<String> blockedUsers,
  }) = _AppUser;

  factory AppUser.fromJson(Map<String, dynamic> json) =>
      _$AppUserFromJson(json);

  factory AppUser.empty() => const AppUser(
        uid: '',
        displayName: null,
        profileImage: null,
        preferredModes: {},
        userBlocks: {},
        pinnedGames: [],
        mutedGames: {},
        hasRatedGame: {},
        dailyRatings: {},
        allTimeRatings: {},
        currentStreaks: {},
        complaints: {},
        bans: {},
        dailyBanVotes: {},
        blockedUsers: [],
      );
}