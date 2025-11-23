import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/firestore_service.dart';

part 'user_notifier.freezed.dart';
part 'user_notifier.g.dart';

@freezed
class UserState with _$UserState {
  const factory UserState({
    required String? profileImage,
    required String? displayName,
    required Map<String, String?> memberProfileImages,
    required Map<String, String?> preferredModes,
    required Map<String, Map<String, bool>> userBlocks,
    required List<String> alertCircles,
    required List<Map<String, dynamic>> pinnedGames,
    required Set<String> mutedGames,
    required Map<String, bool> hasRatedGame,
    required Map<String, Map<String, dynamic>> userProfileCache,
    required Map<String, Map<String, int>> dailyRatings,
    required Map<String, Map<String, int>> allTimeRatings,
    required Map<String, int> currentStreaks,
    required Map<String, Map<String, int>> complaints,
    required Map<String, List<Map<String, dynamic>>> bans,
    required Map<String, Map<String, bool>> dailyBanVotes,
    required List<String> blockedUsers,
    required bool isInitialized,
    String? errorMessage,
  }) = _UserState;

  factory UserState.initial() => const UserState(
        profileImage: null,
        displayName: null,
        memberProfileImages: {},
        preferredModes: {},
        userBlocks: {},
        alertCircles: ['Squad', 'Friends', 'Public'],
        pinnedGames: [],
        mutedGames: {},
        hasRatedGame: {},
        userProfileCache: {},
        dailyRatings: {},
        allTimeRatings: {},
        currentStreaks: {},
        complaints: {},
        bans: {},
        dailyBanVotes: {},
        blockedUsers: [],
        isInitialized: false,
        errorMessage: null,
      );
}

@riverpod
class UserNotifier extends _$UserNotifier {
  late final FirebaseFirestore _firestore;
  late final FirestoreService _firestoreService; // ignore: unused_field
  late final SharedPreferences _prefs;

  @override
  Future<UserState> build() async {
    _firestore = FirebaseFirestore.instance;
    _firestoreService = FirestoreService();
    _prefs = await SharedPreferences.getInstance();

    // Initialize from cache
    final cachedData = _loadFromCache();
    state = AsyncValue.data(cachedData);

    // Load from Firestore
    await _initializeUserData();

    return state.value!;
  }

  UserState _loadFromCache() {
    final profileImage = _prefs.getString('profileImage');
    final displayName = _prefs.getString('displayName');
    final pinnedGamesJson = _prefs.getString('pinnedGames');
    final pinnedGames = pinnedGamesJson != null
        ? List<Map<String, dynamic>>.from(json.decode(pinnedGamesJson))
        : <Map<String, dynamic>>[];

    return UserState.initial().copyWith(
      profileImage: profileImage,
      displayName: displayName,
      pinnedGames: pinnedGames,
      isInitialized: true,
    );
  }

  Future<void> _initializeUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Load user profile
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        state = AsyncValue.data(state.value!.copyWith(
          profileImage: data['profileImage'],
          displayName: data['displayName'],
          preferredModes:
              Map<String, String?>.from(data['preferredModes'] ?? {}),
          userBlocks:
              Map<String, Map<String, bool>>.from(data['userBlocks'] ?? {}),
          pinnedGames:
              List<Map<String, dynamic>>.from(data['pinnedGames'] ?? []),
          mutedGames: Set<String>.from(data['mutedGames'] ?? []),
        ));
      }

      // Load ratings and achievements
      await _loadRatingsAndAchievements(user.uid);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> _loadRatingsAndAchievements(String uid) async {
    try {
      final ratingsDoc =
          await _firestore.collection('user_ratings').doc(uid).get();
      if (ratingsDoc.exists) {
        final data = ratingsDoc.data()!;
        state = AsyncValue.data(state.value!.copyWith(
          dailyRatings:
              Map<String, Map<String, int>>.from(data['dailyRatings'] ?? {}),
          allTimeRatings:
              Map<String, Map<String, int>>.from(data['allTimeRatings'] ?? {}),
          currentStreaks: Map<String, int>.from(data['currentStreaks'] ?? {}),
        ));
      }

      final complaintsDoc =
          await _firestore.collection('complaints').doc(uid).get();
      if (complaintsDoc.exists) {
        final data = complaintsDoc.data()!;
        state = AsyncValue.data(state.value!.copyWith(
          complaints:
              Map<String, Map<String, int>>.from(data['complaints'] ?? {}),
        ));
      }
    } catch (e) {
      // Handle error silently for now
    }
  }

  // Profile management methods
  Future<void> updateProfileImage(String url) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await _firestore
          .collection('users')
          .doc(user.uid)
          .update({'profileImage': url});
      await _prefs.setString('profileImage', url);

      state = AsyncValue.data(state.value!.copyWith(profileImage: url));
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> updateDisplayName(String name) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await _firestore
          .collection('users')
          .doc(user.uid)
          .update({'displayName': name});
      await _prefs.setString('displayName', name);

      state = AsyncValue.data(state.value!.copyWith(displayName: name));
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  // Blocking methods
  Future<void> blockUser(String userName) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final currentBlocks =
          Map<String, Map<String, bool>>.from(state.value!.userBlocks);
      currentBlocks[user.uid] ??= {};
      currentBlocks[user.uid]![userName] = true;

      await _firestore
          .collection('users')
          .doc(user.uid)
          .update({'userBlocks': currentBlocks});

      final blockedUsers = List<String>.from(state.value!.blockedUsers);
      if (!blockedUsers.contains(userName)) {
        blockedUsers.add(userName);
      }

      state = AsyncValue.data(state.value!.copyWith(
        userBlocks: currentBlocks,
        blockedUsers: blockedUsers,
      ));
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> unblockUser(String userName) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final currentBlocks =
          Map<String, Map<String, bool>>.from(state.value!.userBlocks);
      currentBlocks[user.uid]?.remove(userName);

      await _firestore
          .collection('users')
          .doc(user.uid)
          .update({'userBlocks': currentBlocks});

      final blockedUsers = List<String>.from(state.value!.blockedUsers);
      blockedUsers.remove(userName);

      state = AsyncValue.data(state.value!.copyWith(
        userBlocks: currentBlocks,
        blockedUsers: blockedUsers,
      ));
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  bool isBlocked(String userName) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    return state.value!.userBlocks[user.uid]?[userName] ?? false;
  }

  // Ban methods
  Future<void> addBan(String userName, String reason) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final banEntry = {
        'userName': userName,
        'reason': reason,
        'bannedBy': user.uid,
        'timestamp': FieldValue.serverTimestamp(),
      };

      final currentBans =
          List<Map<String, dynamic>>.from(state.value!.bans[user.uid] ?? []);
      currentBans.add(banEntry);

      await _firestore.collection('bans').doc(user.uid).set({
        'bans': currentBans,
      }, SetOptions(merge: true));

      final allBans =
          Map<String, List<Map<String, dynamic>>>.from(state.value!.bans);
      allBans[user.uid] = currentBans;

      state = AsyncValue.data(state.value!.copyWith(bans: allBans));
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  bool isBanned(String userName) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final userBans = state.value!.bans[user.uid] ?? [];
    return userBans.any((ban) => ban['userName'] == userName);
  }

  int getBanCount(String userName) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;

    final userBans = state.value!.bans[user.uid] ?? [];
    return userBans.where((ban) => ban['userName'] == userName).length;
  }

  // Achievement methods

  // Game preferences
  Future<void> addPinnedGame(Map<String, dynamic> game) async {
    final currentPinned =
        List<Map<String, dynamic>>.from(state.value!.pinnedGames);
    currentPinned.add(game);

    await _prefs.setString('pinnedGames', json.encode(currentPinned));
    state = AsyncValue.data(state.value!.copyWith(pinnedGames: currentPinned));
  }

  Future<void> removePinnedGame(String gameName) async {
    final currentPinned =
        List<Map<String, dynamic>>.from(state.value!.pinnedGames);
    currentPinned.removeWhere((game) => game['name'] == gameName);

    await _prefs.setString('pinnedGames', json.encode(currentPinned));
    state = AsyncValue.data(state.value!.copyWith(pinnedGames: currentPinned));
  }

  // Cache management
  void updateMemberProfileImage(String uid, String? imageUrl) {
    final currentImages =
        Map<String, String?>.from(state.value!.memberProfileImages);
    currentImages[uid] = imageUrl;

    state = AsyncValue.data(
        state.value!.copyWith(memberProfileImages: currentImages));
  }

  void updateUserProfileCache(String uid, Map<String, dynamic> profile) {
    final currentCache =
        Map<String, Map<String, dynamic>>.from(state.value!.userProfileCache);
    currentCache[uid] = profile;

    state =
        AsyncValue.data(state.value!.copyWith(userProfileCache: currentCache));
  }
}
