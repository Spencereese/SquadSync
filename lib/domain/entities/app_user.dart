import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_user.freezed.dart';
part 'app_user.g.dart';

@freezed // Disable DiagnosticableTreeMixin - has bugs in Freezed 3.0
class AppUser with _$AppUser {
  const factory AppUser({
    required String uid,
    required String? displayName,
    required String? profileImage,
    required Map<String, String?> preferredModes,
    required Map<String, Map<String, bool>> userBlocks,
    required List<Map<String, dynamic>> pinnedGames,
    required Map<String, bool> notificationSettings,
    required Map<String, bool> hasRatedGame,
    required Map<String, Map<String, int>> dailyRatings,
    required Map<String, Map<String, int>> allTimeRatings,
    required Map<String, int> currentStreaks,
    required Map<String, Map<String, int>> complaints,
    required Map<String, List<Map<String, dynamic>>> bans,
    required Map<String, Map<String, bool>> dailyBanVotes,
    required List<String> blockedUsers,
    required List<String> friends,
    required List<String> alerts,
    required List<Map<String, dynamic>> userGroups,
    required List<String> alertCircles,
    required List<Map<String, dynamic>> publicGroups,
    required List<String> pinnedMessages,
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
        notificationSettings: {
          'pushNotifications': true,
          'soundEnabled': true,
          'vibrationEnabled': true,
          'showPreviews': true,
          'quietHoursEnabled': false,
          'urgentAlertsOnly': false,
          'lobbyInvites': true,
          'friendRequests': true,
          'gameUpdates': false,
          'achievementAlerts': true,
          'showOnlineStatus': true,
        },
        hasRatedGame: {},
        dailyRatings: {},
        allTimeRatings: {},
        currentStreaks: {},
        complaints: {},
        bans: {},
        dailyBanVotes: {},
        blockedUsers: [],
        friends: [],
        alerts: [],
        userGroups: [],
        alertCircles: ['Lobby', 'Friends', 'Public'],
        publicGroups: [],
        pinnedMessages: [],
      );
}
