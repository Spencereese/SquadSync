import 'package:riverpod/riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../domain/entities/app_user.dart';
import '../../services/auth_service_supabase.dart';
import '../../services/supabase_service.dart';
import '../../domain/usecases/get_current_user.dart';
import '../../domain/usecases/update_profile_image.dart';
import '../../domain/usecases/update_display_name.dart';
import '../../domain/usecases/block_user.dart';
import '../../domain/usecases/unblock_user.dart';
import '../../domain/usecases/add_pinned_game.dart';
import '../../domain/usecases/remove_pinned_game.dart';
import '../../core/injection.dart' as di;
import '../../services/friends_service.dart';

class UserNotifier extends AutoDisposeAsyncNotifier<AppUser?> {
  final AuthServiceSupabase _authService = AuthServiceSupabase();
  late final GetCurrentUser _getCurrentUser;
  late final UpdateProfileImage _updateProfileImage;
  late final UpdateDisplayName _updateDisplayName;
  late final BlockUser _blockUser;
  late final UnblockUser _unblockUser;
  late final AddPinnedGame _addPinnedGame;
  late final RemovePinnedGame _removePinnedGame;
  late final FriendsService _friendsService;

  UserNotifier() {
    debugPrint('🔵 UserNotifier: Constructor called - instance created');
  }

  @override
  Future<AppUser?> build() async {
    try {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('UserNotifier: build() called');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      // Get dependencies from get_it
      _getCurrentUser = di.getIt<GetCurrentUser>();
      _updateProfileImage = di.getIt<UpdateProfileImage>();
      _updateDisplayName = di.getIt<UpdateDisplayName>();
      _blockUser = di.getIt<BlockUser>();
      _unblockUser = di.getIt<UnblockUser>();
      _addPinnedGame = di.getIt<AddPinnedGame>();
      _removePinnedGame = di.getIt<RemovePinnedGame>();
      _friendsService = di.getIt<FriendsService>();

      // Return basic user immediately if authenticated
      final supabaseUser = _authService.currentUser;
      debugPrint('UserNotifier: Current user from auth: ${supabaseUser?.id}');

      if (supabaseUser != null) {
        final basicUser = AppUser(
          uid: supabaseUser.id,
          displayName: supabaseUser.userMetadata?['display_name'] as String?,
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
            debugPrint('UserNotifier: Loading full user profile...');
            final fullUser = await _getCurrentUser();
            debugPrint(
                'UserNotifier: Full user loaded - displayName: ${fullUser?.displayName}, pinnedGames: ${fullUser?.pinnedGames.length ?? 0}, userGroups: ${fullUser?.userGroups.length ?? 0}');
            if (fullUser != null) {
              debugPrint('UserNotifier: Full user UID: ${fullUser.uid}');
              debugPrint(
                  'UserNotifier: Profile image: ${fullUser.profileImage}');
              debugPrint('UserNotifier: Friends: ${fullUser.friends.length}');
            }
            if (fullUser?.userGroups.isNotEmpty == true) {
              debugPrint(
                  'UserNotifier: first group: ${fullUser!.userGroups.first}');
            }
            state = AsyncData(fullUser ?? basicUser);
            debugPrint('UserNotifier: State updated with full user data');
          } catch (e, stackTrace) {
            debugPrint('UserNotifier: ❌ ERROR loading full user: $e');
            debugPrint('UserNotifier: Stack trace: $stackTrace');
            // Keep basic user on error
            state = AsyncData(basicUser);
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
    } catch (e, stackTrace) {
      debugPrint('UserNotifier: ❌ CRITICAL ERROR in build(): $e');
      debugPrint('UserNotifier: Stack trace: $stackTrace');
      rethrow;
    }
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

  // Social features - Supabase friends system
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final currentState = state.value;
    if (currentState == null) return [];

    return await _friendsService.searchUsers(query);
  }

  Stream<List<Map<String, dynamic>>> streamFriends() {
    final currentState = state.value;
    if (currentState == null) return Stream.value([]);

    return _friendsService.streamFriends(currentState.uid);
  }

  Future<void> sendFriendRequest(String userId) async {
    final currentState = state.value;
    if (currentState == null) return;

    await _friendsService.sendFriendRequest(currentState.uid, userId);
  }

  Stream<List<Map<String, dynamic>>> streamPendingRequests() {
    final currentState = state.value;
    if (currentState == null) return Stream.value([]);

    return _friendsService.streamPendingRequests(currentState.uid);
  }

  Future<void> clearMutedGames() async {
    final currentState = state.value;
    if (currentState == null) return;

    await _friendsService.clearMutedGames(currentState.uid);
  }

  Future<void> muteGame(String gameSlug) async {
    final currentState = state.value;
    if (currentState == null) return;

    // gameName can be null for now, could be enhanced to store game name
    await _friendsService.muteGame(currentState.uid, gameSlug, null);
  }

  Future<void> unmuteGame(String gameSlug) async {
    final currentState = state.value;
    if (currentState == null) return;

    await _friendsService.unmuteGame(currentState.uid, gameSlug);
  }

  Future<void> startDMThread(String friendId) async {
    final currentState = state.value;
    if (currentState == null) return;

    await _friendsService.startDMThread(currentState.uid, friendId);
  }

  Future<void> removeFriend(String friendId) async {
    final currentState = state.value;
    if (currentState == null) return;

    await _friendsService.removeFriend(currentState.uid, friendId);
  }

  Future<void> acceptFriendRequest(String requestId) async {
    final currentState = state.value;
    if (currentState == null) return;

    await _friendsService.acceptFriendRequest(requestId);
  }

  Future<void> declineFriendRequest(String requestId) async {
    final currentState = state.value;
    if (currentState == null) return;

    await _friendsService.declineFriendRequest(requestId);
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
      final currentUser = _authService.currentUser;
      if (currentUser == null) return false;
      final userId = currentUser.id;

      final supabase = SupabaseService.client;

      // Find the group in chat_groups table
      final groupData = await supabase
          .from('chat_groups')
          .select()
          .eq('id', groupId)
          .maybeSingle();

      if (groupData == null) {
        return false; // Group not found
      }

      final members = List<String>.from(groupData['member_uids'] ?? []);
      final isPrivate = groupData['is_private'] ?? false;

      // Check if user is already a member
      if (members.contains(userId)) {
        return false; // Already joined
      }

      // For private groups, check invite code if provided
      if (isPrivate && inviteCode != null) {
        final storedCode = groupData['invite_code'];
        if (storedCode != inviteCode) {
          return false; // Invalid invite code
        }
      }

      // Add user to group members
      members.add(userId);
      await supabase.from('chat_groups').update({
        'member_uids': members,
        'member_count': (groupData['member_count'] ?? 0) + 1,
      }).eq('id', groupId);

      // Create group info for user's collections
      final groupInfo = {
        'id': groupId,
        'name': groupData['name'] ?? 'Unnamed Group',
        'image_url': groupData['image_url'],
        'is_public': groupData['is_public'] ?? false,
        'member_count': (groupData['member_count'] ?? 0) + 1,
        'created_by': groupData['created_by'],
        'last_message': groupData['last_message'] ?? '',
        'last_message_time': groupData['last_message_time'],
      };

      // Add to user's user_groups array
      final userData = await supabase
          .from('users')
          .select('user_groups')
          .eq('uid', userId)
          .maybeSingle();

      final userGroups =
          List<Map<String, dynamic>>.from(userData?['user_groups'] ?? []);
      userGroups.add(groupInfo);

      await supabase.from('users').update({
        'user_groups': userGroups,
      }).eq('uid', userId);

      // Note: chat_groups subcollection not needed in Supabase (denormalized data in user_groups)

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
