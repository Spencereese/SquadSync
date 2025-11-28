import 'package:riverpod/riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/usecases/get_current_user.dart';
import '../../domain/usecases/update_profile_image.dart';
import '../../domain/usecases/update_display_name.dart';
import '../../domain/usecases/block_user.dart';
import '../../domain/usecases/unblock_user.dart';
import '../../domain/usecases/add_pinned_game.dart';
import '../../domain/usecases/remove_pinned_game.dart';
import '../../core/injection.dart' as di;

class UserNotifier extends AutoDisposeAsyncNotifier<AppUser?> {
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
    final currentState = state.value;
    if (currentState == null) return;

    final gameName = game['name'] as String?;
    if (gameName == null) return;

    final existingIndex = currentState.pinnedGames.indexWhere(
      (pinned) => pinned['name'] == gameName,
    );

    List<Map<String, dynamic>> updatedPinnedGames;
    if (existingIndex >= 0) {
      // Unpin: remove from list
      updatedPinnedGames = List.from(currentState.pinnedGames)
        ..removeAt(existingIndex);
    } else {
      // Pin: add to list
      updatedPinnedGames = List.from(currentState.pinnedGames)..add(game);
    }

    state =
        AsyncValue.data(currentState.copyWith(pinnedGames: updatedPinnedGames));
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
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return false;

      final firestore = FirebaseFirestore.instance;

      // First, try to find the group in the global chat_groups collection
      final groupDoc =
          await firestore.collection('chat_groups').doc(groupId).get();

      if (!groupDoc.exists) {
        // If not found in global collection, try user-specific collections
        // This handles the case where groupId might be a user-specific group
        final userCollections = await firestore
            .collectionGroup('chat_groups')
            .where('__name__', isEqualTo: 'chat_groups/$groupId')
            .get();

        if (userCollections.docs.isEmpty) {
          return false; // Group not found
        }

        // For user-specific groups, we need to find which user's collection it's in
        // This is more complex, so for now return false
        return false;
      }

      final groupData = groupDoc.data()!;
      final members = List<String>.from(groupData['members'] ?? []);
      final isPrivate = groupData['isPrivate'] ?? false;

      // Check if user is already a member
      if (members.contains(currentUser.uid)) {
        return false; // Already joined
      }

      // For private groups, check invite code if provided
      if (isPrivate && inviteCode != null) {
        final storedCode = groupData['inviteCode'];
        if (storedCode != inviteCode) {
          return false; // Invalid invite code
        }
      }

      // Add user to group members
      await firestore.collection('chat_groups').doc(groupId).update({
        'members': FieldValue.arrayUnion([currentUser.uid]),
        'memberCount': FieldValue.increment(1),
      });

      // Create group info for user's collections
      final groupInfo = {
        'id': groupId,
        'name': groupData['name'] ?? 'Unnamed Group',
        'imageUrl': groupData['imageUrl'],
        'isPublic': groupData['isPublic'] ?? false,
        'memberCount': (groupData['memberCount'] ?? 0) + 1,
        'createdBy': groupData['createdBy'],
        'lastMessage': groupData['lastMessage'] ?? '',
        'lastMessageTime': groupData['lastMessageTime'],
      };

      // Add to user's userGroups array
      await firestore.collection('users').doc(currentUser.uid).update({
        'userGroups': FieldValue.arrayUnion([groupInfo]),
      });

      // Add to user's chat_groups subcollection
      await firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('chat_groups')
          .doc(groupId)
          .set(groupInfo);

      // Update local state
      addUserGroup(groupInfo);

      return true;
    } catch (e) {
      debugPrint('Error joining group: $e');
      return false;
    }
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

final userNotifierProvider =
    AutoDisposeAsyncNotifierProvider<UserNotifier, AppUser?>(
  () => UserNotifier(),
);
