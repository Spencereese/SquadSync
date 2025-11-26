import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/usecases/get_current_user.dart';
import '../../domain/usecases/update_profile_image.dart';
import '../../domain/usecases/update_display_name.dart';
import '../../domain/usecases/block_user.dart';
import '../../domain/usecases/unblock_user.dart';
import '../../domain/usecases/add_pinned_game.dart';
import '../../domain/usecases/remove_pinned_game.dart';
import '../../core/injection.dart' as di;

part 'user_notifier.g.dart';

@riverpod
class UserNotifier extends _$UserNotifier {
  late final GetCurrentUser _getCurrentUser;
  late final UpdateProfileImage _updateProfileImage;
  late final UpdateDisplayName _updateDisplayName;
  late final BlockUser _blockUser;
  late final UnblockUser _unblockUser;
  late final AddPinnedGame _addPinnedGame;
  late final RemovePinnedGame _removePinnedGame;

  @override
  Future<AppUser?> build() async {
    // Get dependencies from get_it
    _getCurrentUser = di.getIt<GetCurrentUser>();
    _updateProfileImage = di.getIt<UpdateProfileImage>();
    _updateDisplayName = di.getIt<UpdateDisplayName>();
    _blockUser = di.getIt<BlockUser>();
    _unblockUser = di.getIt<UnblockUser>();
    _addPinnedGame = di.getIt<AddPinnedGame>();
    _removePinnedGame = di.getIt<RemovePinnedGame>();

    // Return basic user immediately if authenticated
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      final basicUser = AppUser(
        uid: firebaseUser.uid,
        displayName: firebaseUser.displayName,
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
        alertCircles: [],
        publicGroups: [],
        pinnedMessages: [],
      );

      // Load full user data in background
      Future.microtask(() async {
        try {
          final fullUser = await _getCurrentUser();
          debugPrint(
              'UserNotifier: loaded full user, userGroups length: ${fullUser?.userGroups.length ?? 0}');
          if (fullUser?.userGroups.isNotEmpty == true) {
            debugPrint(
                'UserNotifier: first group: ${fullUser!.userGroups.first}');
          }
          state = AsyncData(fullUser ?? basicUser);
        } catch (e) {
          debugPrint('Error loading full user: $e');
          // Keep basic user
        }
      });

      return basicUser;
    }

    // Load user in background for non-authenticated case
    Future.microtask(() async {
      try {
        final user = await _getCurrentUser();
        state = AsyncData(user);
      } catch (e) {
        debugPrint('Error loading user: $e');
        state = const AsyncData(null);
      }
    });

    return null;
  }

  Future<void> updateProfileImage(String url) async {
    await _updateProfileImage(url);
    state = await AsyncValue.guard(() => _getCurrentUser());
  }

  Future<void> updateDisplayName(String name) async {
    await _updateDisplayName(name);
    state = await AsyncValue.guard(() => _getCurrentUser());
  }

  Future<void> blockUser(String userName) async {
    await _blockUser(userName);
    state = await AsyncValue.guard(() => _getCurrentUser());
  }

  Future<void> unblockUser(String userName) async {
    await _unblockUser(userName);
    state = await AsyncValue.guard(() => _getCurrentUser());
  }

  Future<void> addPinnedGame(Map<String, dynamic> game) async {
    await _addPinnedGame(game);
    state = await AsyncValue.guard(() => _getCurrentUser());
  }

  Future<void> removePinnedGame(String gameName) async {
    await _removePinnedGame(gameName);
    state = await AsyncValue.guard(() => _getCurrentUser());
  }

  Future<void> submitFeedback({
    required String type,
    required String page,
    required String content,
    required String severity,
  }) async {
    // TODO: Implement feedback submission to backend
    // For now, this is a placeholder
  }

  // Social features - TODO: Implement proper usecases
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    // TODO: Implement user search
    return [];
  }

  Stream<List<Map<String, dynamic>>> streamFriends() {
    // TODO: Implement friends streaming
    return Stream.value([]);
  }

  Future<void> sendFriendRequest(String userId) async {
    // TODO: Implement friend request sending
  }

  Stream<List<Map<String, dynamic>>> streamPendingRequests() {
    // TODO: Implement pending requests streaming
    return Stream.value([]);
  }

  Future<void> clearMutedGames() async {
    // TODO: Implement clearMutedGames
  }

  Future<void> muteGame(String gameSlug) async {
    // TODO: Implement muteGame
  }

  Future<void> unmuteGame(String gameSlug) async {
    // TODO: Implement unmuteGame
  }

  Future<void> startDMThread(String friendId) async {
    // TODO: Implement DM thread starting
  }

  Future<void> removeFriend(String friendId) async {
    // TODO: Implement friend removal
  }

  Future<void> acceptFriendRequest(String requesterId) async {
    // TODO: Implement friend request acceptance
  }

  Future<void> declineFriendRequest(String requesterId) async {
    // TODO: Implement friend request decline
  }

  Future<void> updateGameLastPlayed(String gameName) async {
    // TODO: Implement game last played update
  }

  Future<void> markGameAsRated(String gameName) async {
    // TODO: Implement game rating marking
  }

  Future<void> pinGame(Map<String, dynamic> game) async {
    // TODO: Implement game pinning
  }

  Future<void> removeAlert(String alert) async {
    // TODO: Implement alert removal
  }

  String? getDisplayNameForUid(String? uid) {
    // TODO: Implement display name lookup for UID
    // This should probably look up from a cache or service
    return uid; // Placeholder: return UID as fallback
  }

  Future<String?> createGroup({
    required String name,
    required bool isPublic,
    String? gameId,
    String? squadId,
  }) async {
    // TODO: Implement group creation
    return null; // Placeholder
  }

  Future<void> unpinMessage(String messageId) async {
    // TODO: Implement message unpinning
  }

  Future<bool> voteOnPoll({
    required String pollId,
    required List<String> optionIds,
    String? chatGroupId,
  }) async {
    // TODO: Implement poll voting
    return false; // Placeholder
  }

  Future<bool> joinGroup(String groupId, {String? inviteCode}) async {
    // TODO: Implement group joining
    return false; // Placeholder
  }

  void addUserGroup(Map<String, dynamic> groupInfo) {
    state = state.maybeWhen(
      data: (user) {
        if (user == null) return state;
        final updatedGroups = List<Map<String, dynamic>>.from(user.userGroups);
        // Check if group already exists
        final existingIndex =
            updatedGroups.indexWhere((g) => g['id'] == groupInfo['id']);
        if (existingIndex == -1) {
          updatedGroups.add(groupInfo);
        } else {
          updatedGroups[existingIndex] = groupInfo;
        }
        return AsyncData(user.copyWith(userGroups: updatedGroups));
      },
      orElse: () => state,
    );
  }

  Future<Map<String, dynamic>?> getCachedSenderDetails(String senderId) async {
    // TODO: Implement cached sender details lookup
    // This should return cached user details for the given senderId
    return {
      'displayName': 'Unknown', // Placeholder
      'profileImage': null, // Placeholder
    };
  }
}
