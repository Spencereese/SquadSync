import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final profile = await _remoteDataSource.getUserProfile(user.uid);
    final ratings = await _remoteDataSource.getUserRatings(user.uid);
    final complaints = await _remoteDataSource.getUserComplaints(user.uid);

    debugPrint(
        'UserRepository: profile loaded, userGroups: ${profile?['userGroups']?.length ?? 0}');

    if (profile == null) return null;

    return AppUser(
      uid: user.uid,
      displayName: profile['displayName'],
      profileImage: profile['profileImage'],
      preferredModes:
          Map<String, String?>.from(profile['preferredModes'] ?? {}),
      userBlocks:
          Map<String, Map<String, bool>>.from(profile['userBlocks'] ?? {}),
      pinnedGames:
          List<Map<String, dynamic>>.from(profile['pinnedGames'] ?? []),
      notificationSettings:
          Map<String, bool>.from(profile['notificationSettings'] ??
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
      dailyRatings:
          Map<String, Map<String, int>>.from(ratings?['dailyRatings'] ?? {}),
      allTimeRatings:
          Map<String, Map<String, int>>.from(ratings?['allTimeRatings'] ?? {}),
      currentStreaks: Map<String, int>.from(ratings?['currentStreaks'] ?? {}),
      complaints:
          Map<String, Map<String, int>>.from(complaints?['complaints'] ?? {}),
      bans: {}, // Need to load bans separately
      dailyBanVotes: {},
      blockedUsers: [], // Derived from userBlocks
      friends: List<String>.from(profile['friends'] ?? []),
      alerts: List<String>.from(profile['alerts'] ?? []),
      userGroups: List<Map<String, dynamic>>.from(profile['userGroups'] ?? []),
      alertCircles: List<String>.from(
          profile['alertCircles'] ?? ['Squad', 'Friends', 'Public']),
      publicGroups:
          List<Map<String, dynamic>>.from(profile['publicGroups'] ?? []),
      pinnedMessages: List<String>.from(profile['pinnedMessages'] ?? []),
    );
  }

  @override
  Future<void> updateProfileImage(String url) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Update Firebase Auth user profile
    await user.updateProfile(photoURL: url);

    // Update Firestore user document
    await _remoteDataSource.updateUserProfile(user.uid, {'profileImage': url});

    // Update local storage
    await _localDataSource.setProfileImage(url);
  }

  @override
  Future<void> updateDisplayName(String name) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Update Firebase Auth user profile
    await user.updateProfile(displayName: name);

    // Update Firestore user document
    await _remoteDataSource.updateUserProfile(user.uid, {'displayName': name});

    // Update local storage
    await _localDataSource.setDisplayName(name);
  }

  @override
  Future<void> blockUser(String userName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final currentBlocks = await _getUserBlocks();
    currentBlocks[user.uid] ??= {};
    currentBlocks[user.uid]![userName] = true;

    await _remoteDataSource
        .updateUserProfile(user.uid, {'userBlocks': currentBlocks});
  }

  @override
  Future<void> unblockUser(String userName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final currentBlocks = await _getUserBlocks();
    currentBlocks[user.uid]?.remove(userName);

    await _remoteDataSource
        .updateUserProfile(user.uid, {'userBlocks': currentBlocks});
  }

  @override
  Future<bool> isBlocked(String userName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final blocks = await _getUserBlocks();
    return blocks[user.uid]?[userName] ?? false;
  }

  Future<Map<String, Map<String, bool>>> _getUserBlocks() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};

    final profile = await _remoteDataSource.getUserProfile(user.uid);
    return Map<String, Map<String, bool>>.from(profile?['userBlocks'] ?? {});
  }

  @override
  Future<void> addBan(String userName, String reason) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final banData = {
      'userName': userName,
      'reason': reason,
      'bannedBy': user.uid,
      'timestamp': DateTime.now().toIso8601String(),
    };

    await _remoteDataSource.addBan(user.uid, banData);
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
    final currentPinned = await _localDataSource.getPinnedGames();
    currentPinned.add(game);
    await _localDataSource.setPinnedGames(currentPinned);
  }

  @override
  Future<void> removePinnedGame(String gameName) async {
    final currentPinned = await _localDataSource.getPinnedGames();
    currentPinned.removeWhere((g) => g['name'] == gameName);
    await _localDataSource.setPinnedGames(currentPinned);
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
