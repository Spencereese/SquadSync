import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/interfaces.dart';

/// Manages user profiles, blocking, and preferences
class UserManager with ChangeNotifier implements IUserManager {
  String? _profileImage;
  String? _displayName;
  Map<String, String?> memberProfileImages = {};
  Map<String, String?> preferredModes = {};

  // Blocked users map per user
  Map<String, Map<String, bool>> userBlocks = {};

  // Alert circles for notifications
  List<String> alertCircles = ['Squad', 'Friends', 'Public'];

  // Pinned games for quick access
  List<Map<String, dynamic>> pinnedGames = [];

  // Muted games for quiet mode
  Set<String> mutedGames = {};

  // Game rating tracking
  Map<String, bool> hasRatedGame = {};

  // Cache for user profiles to avoid repeated Firestore calls
  Map<String, Map<String, dynamic>> _userProfileCache = {};

  // Cache for pending request sender details futures
  Map<String, Future<Map<String, dynamic>?>> _senderDetailFutures = {};

  String? get profileImage => _profileImage;
  String? get displayName => _displayName;

  void updateProfileImage(String url) {
    _profileImage = url;
    notifyListeners();
  }

  void updateDisplayName(String name) {
    _displayName = name;
    notifyListeners();
  }

  void updatePreferredMode(String user, String? mode) {
    preferredModes[user] = mode;
    notifyListeners();
  }

  bool isUserBlocked(String user) {
    final currentUser = FirebaseAuth.instance.currentUser?.uid ?? '';
    return userBlocks[currentUser]?.containsKey(user) ?? false;
  }

  @override
  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    // Implementation for updating user profile
    // This would typically update Firestore
  }

  @override
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    // Check cache first
    if (_userProfileCache.containsKey(uid)) {
      return _userProfileCache[uid];
    }

    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (doc.exists) {
        final data = doc.data()!;
        final profile = {
          'displayName': data['displayName'] ?? 'User',
          'profileImage': data['profileImage'],
        };
        _userProfileCache[uid] = profile;
        return profile;
      }
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getCachedSenderDetails(String senderId) {
    if (_senderDetailFutures.containsKey(senderId)) {
      return _senderDetailFutures[senderId]!;
    }

    final future = getUserProfile(senderId);
    _senderDetailFutures[senderId] = future;
    return future;
  }

  @override
  Future<void> blockUser(String blockerUid, String blockedUid) async {
    userBlocks[blockerUid] ??= {};
    userBlocks[blockerUid]![blockedUid] = true;
    notifyListeners();
  }

  @override
  Future<void> unblockUser(String blockerUid, String blockedUid) async {
    userBlocks[blockerUid]?.remove(blockedUid);
    notifyListeners();
  }

  @override
  Future<Map<String, bool>> getBlockedUsers(String uid) async {
    return Map<String, bool>.from(userBlocks[uid] ?? {});
  }

  void markGameAsRated(String gameName) {
    hasRatedGame[gameName] = true;
    notifyListeners();
  }

  Future<void> fetchPinnedGames() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data();
      if (data != null && data['pinnedGames'] != null) {
        pinnedGames = List<Map<String, dynamic>>.from(data['pinnedGames']);

        // Enrich games that don't have coverUrl from cached IGDB data
        for (int i = 0; i < pinnedGames.length; i++) {
          final game = pinnedGames[i];
          if (game['coverUrl'] == null) {
            try {
              // First try by slug if available
              if (game['slug'] != null) {
                final cachedGame = await FirebaseFirestore.instance
                    .collection('games')
                    .doc(game['slug'])
                    .get();
                if (cachedGame.exists) {
                  final cachedData = cachedGame.data();
                  if (cachedData != null) {
                    if (cachedData['coverUrl'] != null) {
                      game['coverUrl'] = cachedData['coverUrl'];
                    }
                    if (cachedData['summary'] != null &&
                        game['summary'] == null) {
                      game['summary'] = cachedData['summary'];
                    }
                  }
                }
              } else {
                // Fallback: search by name
                final query = game['name']?.toString().toLowerCase() ?? '';
                if (query.isNotEmpty) {
                  final snapshot = await FirebaseFirestore.instance
                      .collection('games')
                      .where('name', isGreaterThanOrEqualTo: query)
                      .where('name', isLessThanOrEqualTo: '$query\uf8ff')
                      .limit(1)
                      .get();

                  if (snapshot.docs.isNotEmpty) {
                    final cachedData = snapshot.docs.first.data();
                    if (cachedData['coverUrl'] != null) {
                      game['coverUrl'] = cachedData['coverUrl'];
                    }
                    if (cachedData['summary'] != null &&
                        game['summary'] == null) {
                      game['summary'] = cachedData['summary'];
                    }
                  }
                }
              }
            } catch (e) {
              // Ignore enrichment errors
              print('Error enriching pinned game ${game['name']}: $e');
            }
          }
        }

        // Sort by lastPlayed descending (most recent first)
        pinnedGames.sort((a, b) {
          final aTime = a['lastPlayed'] as Timestamp?;
          final bTime = b['lastPlayed'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });
        notifyListeners();
      }
    } catch (e) {
      // Handle error
    }
  }

  Future<void> addPinnedGame(Map<String, dynamic> game) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Check if already pinned
    if (pinnedGames.any((g) => g['name'] == game['name'])) return;

    // Max 10
    if (pinnedGames.length >= 10) return;

    pinnedGames.add(game);
    notifyListeners();

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'pinnedGames': pinnedGames,
      }, SetOptions(merge: true));
    } catch (e) {
      // Handle error
    }
  }

  Future<void> removePinnedGame(String gameName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Find and remove the game
    final index = pinnedGames.indexWhere((g) => g['name'] == gameName);
    if (index == -1) return; // Game not found

    pinnedGames.removeAt(index);
    notifyListeners();

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'pinnedGames': pinnedGames,
      }, SetOptions(merge: true));
    } catch (e) {
      // Handle error
    }
  }

  Future<void> updateGameLastPlayed(String gameName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final index = pinnedGames.indexWhere((g) => g['name'] == gameName);
    if (index != -1) {
      pinnedGames[index]['lastPlayed'] = Timestamp.now();
      // Re-sort after update
      pinnedGames.sort((a, b) {
        final aTime = a['lastPlayed'] as Timestamp?;
        final bTime = b['lastPlayed'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });
      notifyListeners();

      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'pinnedGames': pinnedGames,
        }, SetOptions(merge: true));
      } catch (e) {
        // Handle error
      }
    }
  }

  // Muted games management
  Future<void> fetchMutedGames() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data();
      if (data != null && data['mutedGames'] != null) {
        mutedGames = Set<String>.from(data['mutedGames']);
        notifyListeners();
      }
    } catch (e) {
      // Handle error
    }
  }

  Future<void> muteGame(String gameSlug) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    mutedGames.add(gameSlug);
    notifyListeners();

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'mutedGames': mutedGames.toList(),
      }, SetOptions(merge: true));
    } catch (e) {
      // Handle error
    }
  }

  Future<void> unmuteGame(String gameSlug) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    mutedGames.remove(gameSlug);
    notifyListeners();

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'mutedGames': mutedGames.toList(),
      }, SetOptions(merge: true));
    } catch (e) {
      // Handle error
    }
  }

  bool isGameMuted(String gameSlug) {
    return mutedGames.contains(gameSlug);
  }

  Future<void> clearMutedGames() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    mutedGames.clear();
    notifyListeners();

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'mutedGames': []});
    } catch (e) {
      debugPrint('Error clearing muted games: $e');
    }
  }

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return [];

      // Search users by display name (case insensitive)
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('displayName', isGreaterThanOrEqualTo: query)
          .where('displayName', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(10)
          .get();

      return snapshot.docs
          .map((doc) => {'uid': doc.id, ...doc.data()})
          .where((user) => user['uid'] != currentUser.uid)
          .toList();
    } catch (e) {
      debugPrint('Error searching users: $e');
      return [];
    }
  }

  Future<String?> startDMThread(String otherUserId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return null;

      // Create sorted UIDs for consistent chat ID
      final uids = [currentUser.uid, otherUserId]..sort();
      final chatId = uids.join('_');

      // Check if DM already exists
      final existingChat = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .get();

      if (!existingChat.exists) {
        // Create new DM chat
        await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
          'participants': uids,
          'type': 'dm',
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessageTime': FieldValue.serverTimestamp(),
          'lastMessage': '',
        });
      }

      return chatId;
    } catch (e) {
      debugPrint('Error starting DM thread: $e');
      return null;
    }
  }

  // Offline caching for friends list
  static const String _friendsCacheKey = 'cached_friends_list';

  Future<void> _cacheFriendsList(List<Map<String, dynamic>> friends) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final friendsJson = jsonEncode(friends);
      await prefs.setString(_friendsCacheKey, friendsJson);
    } catch (e) {
      debugPrint('Error caching friends list: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _getCachedFriendsList() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final friendsJson = prefs.getString(_friendsCacheKey);
      if (friendsJson != null) {
        final friendsList = jsonDecode(friendsJson) as List<dynamic>;
        return friendsList
            .map((friend) => Map<String, dynamic>.from(friend))
            .toList();
      }
    } catch (e) {
      debugPrint('Error retrieving cached friends list: $e');
    }
    return [];
  }

  // Friends management methods
  Stream<List<Map<String, dynamic>>> streamFriends() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return Stream.value([]);

    // First emit cached data immediately if available
    return Stream.fromFuture(_getCachedFriendsList())
        .asyncExpand((cachedFriends) {
      return FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .snapshots()
          .asyncMap((doc) async {
        try {
          final data = doc.data();
          if (data == null || !data.containsKey('friends')) {
            return cachedFriends;
          }

          final friendsUids = List<String>.from(data['friends'] ?? []);
          if (friendsUids.isEmpty) {
            // Cache empty list and return
            await _cacheFriendsList([]);
            return [];
          }

          // Get friend details
          final snapshot = await FirebaseFirestore.instance
              .collection('users')
              .where(FieldPath.documentId, whereIn: friendsUids)
              .get();

          final friendsList = snapshot.docs.map((friendDoc) {
            final friendData = friendDoc.data();
            return {
              'uid': friendDoc.id,
              'displayName': friendData['displayName'] ?? 'User',
              'profileImage': friendData['profileImage'],
              'isOnline': friendData['isOnline'] ?? false,
              'lastSeen': friendData['lastSeen'],
            };
          }).toList();

          // Cache the friends list for offline use
          await _cacheFriendsList(friendsList);
          return friendsList;
        } catch (e) {
          debugPrint('Error fetching friends from Firestore: $e');
          // Return cached data when offline
          return cachedFriends;
        }
      });
    });
  }

  Stream<List<Map<String, dynamic>>> streamPendingRequests() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return Stream.value([]);

    return FirebaseFirestore.instance
        .collection('friendRequests')
        .where('receiverId', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
      // Process synchronously to avoid asyncMap delays
      final requests = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final senderId = data['senderId'] as String;

        // For now, just use senderId - display name will be fetched when needed
        // This prevents the flashing issue caused by async operations
        requests.add({
          'requestId': doc.id,
          'senderId': senderId,
          'senderName': 'Loading...', // Will be updated when tile is built
          'senderImage': null,
          'timestamp': data['timestamp'],
        });
      }

      return requests;
    });
  }

  Future<void> acceptFriendRequest(String requesterId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final batch = FirebaseFirestore.instance.batch();

    // Update request status
    final requestQuery = await FirebaseFirestore.instance
        .collection('friendRequests')
        .where('senderId', isEqualTo: requesterId)
        .where('receiverId', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: 'pending')
        .get();

    for (final doc in requestQuery.docs) {
      batch.update(doc.reference, {'status': 'accepted'});
    }

    // Add to both users' friends lists
    final currentUserRef =
        FirebaseFirestore.instance.collection('users').doc(currentUser.uid);
    final requesterRef =
        FirebaseFirestore.instance.collection('users').doc(requesterId);

    // Get current friends lists
    final currentUserDoc = await currentUserRef.get();
    final requesterDoc = await requesterRef.get();

    final currentFriends =
        List<String>.from(currentUserDoc.data()?['friends'] ?? []);
    final requesterFriends =
        List<String>.from(requesterDoc.data()?['friends'] ?? []);

    if (!currentFriends.contains(requesterId)) {
      currentFriends.add(requesterId);
    }
    if (!requesterFriends.contains(currentUser.uid)) {
      requesterFriends.add(currentUser.uid);
    }

    batch.update(currentUserRef, {'friends': currentFriends});
    batch.update(requesterRef, {'friends': requesterFriends});

    await batch.commit();
  }

  Future<void> declineFriendRequest(String requesterId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Update request status
    final requestQuery = await FirebaseFirestore.instance
        .collection('friendRequests')
        .where('senderId', isEqualTo: requesterId)
        .where('receiverId', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: 'pending')
        .get();

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in requestQuery.docs) {
      batch.update(doc.reference, {'status': 'declined'});
    }

    await batch.commit();
  }

  Future<void> sendFriendRequest(String receiverId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Check if request already exists
    final existingRequest = await FirebaseFirestore.instance
        .collection('friendRequests')
        .where('senderId', isEqualTo: currentUser.uid)
        .where('receiverId', isEqualTo: receiverId)
        .where('status', isEqualTo: 'pending')
        .get();

    if (existingRequest.docs.isNotEmpty) {
      // Request already exists
      return;
    }

    // Create new friend request
    await FirebaseFirestore.instance.collection('friendRequests').add({
      'senderId': currentUser.uid,
      'receiverId': receiverId,
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeFriend(String friendId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final batch = FirebaseFirestore.instance.batch();

    // Remove from both users' friends lists
    final currentUserRef =
        FirebaseFirestore.instance.collection('users').doc(currentUser.uid);
    final friendRef =
        FirebaseFirestore.instance.collection('users').doc(friendId);

    // Get current friends lists
    final currentUserDoc = await currentUserRef.get();
    final friendDoc = await friendRef.get();

    final currentFriends =
        List<String>.from(currentUserDoc.data()?['friends'] ?? []);
    final friendFriends = List<String>.from(friendDoc.data()?['friends'] ?? []);

    currentFriends.remove(friendId);
    friendFriends.remove(currentUser.uid);

    batch.update(currentUserRef, {'friends': currentFriends});
    batch.update(friendRef, {'friends': friendFriends});

    await batch.commit();
  }
}
