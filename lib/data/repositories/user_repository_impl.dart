import '../../services/auth_service_supabase.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:squad_sync/domain/entities/app_user.dart';
import 'package:squad_sync/domain/repositories/user_repository.dart';
import 'package:squad_sync/data/datasources/user_local_datasource.dart';
import 'package:squad_sync/data/datasources/user_remote_datasource.dart';

class UserRepositoryImpl implements UserRepository {
  final UserLocalDataSource _localDataSource;
  final UserRemoteDataSource _remoteDataSource;

  UserRepositoryImpl(this._localDataSource, this._remoteDataSource);

  @override
  Future<AppUser?> getCurrentUser() async {
    try {
      final user = AuthServiceSupabase().currentUser;
      if (user == null) {
        debugPrint('UserRepository: No authenticated user');
        return null;
      }

      debugPrint('UserRepository: Loading profile for user ${user.id}');

      final profile = await _remoteDataSource.getUserProfile(user.id);

      // TODO: Re-enable when complaints/user_ratings tables are created
      // final ratings = await _remoteDataSource.getUserRatings(user.id);
      // final complaints = await _remoteDataSource.getUserComplaints(user.id);

      debugPrint('UserRepository: profile = $profile');
      debugPrint('UserRepository: display_name = ${profile?['display_name']}');

      if (profile == null) {
        debugPrint(
            'UserRepository: ❌ Profile not found in database for ${user.id}');
        return null;
      }

      debugPrint('UserRepository: ✅ Profile loaded successfully');

      final pinnedGames =
          List<Map<String, dynamic>>.from(profile['pinned_games'] ?? []);

      debugPrint('UserRepository: Pinned games count: ${pinnedGames.length}');

      // Sync remote pinned games to local storage
      await _localDataSource.setPinnedGames(pinnedGames);
      debugPrint('UserRepository: Pinned games synced to local storage');

      // Load user groups from chat_groups table
      final userGroups = await _remoteDataSource.getUserGroups(user.id);
      debugPrint('UserRepository: User groups count: ${userGroups.length}');

      return AppUser(
        uid: user.id,
        displayName: profile['display_name'],
        profileImage: profile['photo_url'], // Changed from profile_image
        preferredModes:
            Map<String, String?>.from(profile['preferred_modes'] ?? {}),
        userBlocks: {}, // Migrated to blocked_users array - load separately if needed
        pinnedGames: pinnedGames,
        notificationSettings:
            Map<String, bool>.from(profile['notification_settings'] ??
                {
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
                }),
        hasRatedGame: {},
        dailyRatings: {}, // TODO: Load from user_ratings table when created
        allTimeRatings: {}, // TODO: Load from user_ratings table when created
        currentStreaks: {}, // TODO: Load from user_ratings table when created
        complaints: {}, // TODO: Load from complaints table when created
        bans: {}, // Need to load bans separately
        dailyBanVotes: {},
        blockedUsers: List<String>.from(
            profile['blocked_users'] ?? []), // Now uses blocked_users array
        friends: [], // Now loaded from friends table via FriendsService
        alerts: List<String>.from(profile['alerts'] ?? []),
        userGroups: userGroups,
        alertCircles: List<String>.from(
            profile['alert_circles'] ?? ['Lobby', 'Friends', 'Public']),
        publicGroups:
            List<Map<String, dynamic>>.from(profile['public_groups'] ?? []),
        pinnedMessages: List<String>.from(profile['pinned_messages'] ?? []),
      );
    } catch (e, stackTrace) {
      debugPrint('UserRepository: ❌ ERROR getting current user: $e');
      debugPrint('UserRepository: Stack trace: $stackTrace');
      rethrow;
    }
  }

  @override
  Future<void> updateProfileImage(String url) async {
    final user = AuthServiceSupabase().currentUser;
    if (user == null) return;

    // Update Supabase user metadata
    await Supabase.instance.client.auth.updateUser(
      UserAttributes(data: {'photo_url': url}),
    );

    // Update Supabase users table (uses photo_url now)
    await _remoteDataSource.updateUserProfile(user.id, {'photo_url': url});

    // Update local storage
    await _localDataSource.setProfileImage(url);
  }

  @override
  Future<void> updateDisplayName(String name) async {
    final user = AuthServiceSupabase().currentUser;
    if (user == null) return;

    // Update Supabase user metadata
    await Supabase.instance.client.auth.updateUser(
      UserAttributes(data: {'display_name': name}),
    );

    // Update Supabase user document
    await _remoteDataSource.updateUserProfile(user.id, {'display_name': name});

    // Update local storage
    await _localDataSource.setDisplayName(name);
  }

  @override
  Future<void> blockUser(String userName) async {
    final user = AuthServiceSupabase().currentUser;
    if (user == null) return;

    final currentBlocks = await _getUserBlocks();
    currentBlocks[user.id] ??= {};
    currentBlocks[user.id]![userName] = true;

    await _remoteDataSource
        .updateUserProfile(user.id, {'userBlocks': currentBlocks});
  }

  @override
  Future<void> unblockUser(String userName) async {
    final user = AuthServiceSupabase().currentUser;
    if (user == null) return;

    final currentBlocks = await _getUserBlocks();
    currentBlocks[user.id]?.remove(userName);

    await _remoteDataSource
        .updateUserProfile(user.id, {'userBlocks': currentBlocks});
  }

  @override
  Future<bool> isBlocked(String userName) async {
    final user = AuthServiceSupabase().currentUser;
    if (user == null) return false;

    final blocks = await _getUserBlocks();
    return blocks[user.id]?[userName] ?? false;
  }

  Future<Map<String, Map<String, bool>>> _getUserBlocks() async {
    final user = AuthServiceSupabase().currentUser;
    if (user == null) return {};

    final profile = await _remoteDataSource.getUserProfile(user.id);
    return Map<String, Map<String, bool>>.from(profile?['userBlocks'] ?? {});
  }

  @override
  Future<void> addBan(String userName, String reason) async {
    final user = AuthServiceSupabase().currentUser;
    if (user == null) return;

    final banData = {
      'userName': userName,
      'reason': reason,
      'bannedBy': user.id,
      'timestamp': DateTime.now().toIso8601String(),
    };

    await _remoteDataSource.addBan(user.id, banData);
  }

  @override
  Future<bool> isBanned(String userName) async {
    // This would require loading bans from Firestore
    // For simplicity, assuming bans are loaded in getCurrentUser
    return false; // Placeholder
  }

  @override
  Future<int> getBanCount(String userName) async {
    // Placeholder
    return 0;
  }

  @override
  Future<void> addPinnedGame(Map<String, dynamic> game) async {
    final user = AuthServiceSupabase().currentUser;
    if (user == null) return;

    // Update local storage
    final currentPinned = await _localDataSource.getPinnedGames();

    // Check for duplicates by name or id
    final gameName = game['name'];
    final gameId = game['id'];
    final isDuplicate = currentPinned.any((pinnedGame) =>
        (gameName != null && pinnedGame['name'] == gameName) ||
        (gameId != null && pinnedGame['id'] == gameId));

    if (!isDuplicate) {
      currentPinned.add(game);
      await _localDataSource.setPinnedGames(currentPinned);

      // Update remote storage with correct snake_case column name
      await _remoteDataSource.updateUserProfile(user.id, {
        'pinned_games': currentPinned,
      });
    }
  }

  @override
  Future<void> removePinnedGame(String gameName) async {
    final user = AuthServiceSupabase().currentUser;
    if (user == null) return;

    // Update local storage
    final currentPinned = await _localDataSource.getPinnedGames();
    currentPinned.removeWhere((g) => g['name'] == gameName);
    await _localDataSource.setPinnedGames(currentPinned);

    // Update remote storage with correct snake_case column name
    await _remoteDataSource.updateUserProfile(user.id, {
      'pinned_games': currentPinned,
    });
  }

  @override
  Future<void> updateMemberProfileImage(String uid, String? imageUrl) async {
    // This might be cached locally or in memory
  }

  @override
  Future<void> updateUserProfileCache(
      String uid, Map<String, dynamic> profile) async {
    // Cache management
  }

  @override
  Future<Map<String, String?>> getMemberProfileImages() async {
    // Return cached images
    return {};
  }

  @override
  Future<Map<String, Map<String, dynamic>>> getUserProfileCache() async {
    return {};
  }
}
