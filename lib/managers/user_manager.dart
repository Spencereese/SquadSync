import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  // Game rating tracking
  Map<String, bool> hasRatedGame = {};

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
    // Implementation for getting user profile
    // This would typically fetch from Firestore
    return null;
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

  // Friend management methods
  Stream<List<Map<String, dynamic>>> streamFriends() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('friends')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Stream<List<Map<String, dynamic>>> streamPendingRequests() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('friendRequests')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Future<String> startDMThread(String friendId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Create or get existing DM thread
    final threadId = [user.uid, friendId]..sort();
    final threadDocId = threadId.join('_');

    // Ensure thread exists in Firestore
    await FirebaseFirestore.instance
        .collection('dm_threads')
        .doc(threadDocId)
        .set({
      'participants': threadId,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return threadDocId;
  }

  Future<void> removeFriend(String friendId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Remove from both users' friend lists
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('friends')
        .doc(friendId)
        .delete();

    await FirebaseFirestore.instance
        .collection('users')
        .doc(friendId)
        .collection('friends')
        .doc(user.uid)
        .delete();
  }

  Future<void> acceptFriendRequest(String requesterId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Move from friendRequests to friends
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('friends')
        .doc(requesterId)
        .set({'addedAt': FieldValue.serverTimestamp()});

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('friendRequests')
        .doc(requesterId)
        .delete();

    // Also add to requester's friends list
    await FirebaseFirestore.instance
        .collection('users')
        .doc(requesterId)
        .collection('friends')
        .doc(user.uid)
        .set({'addedAt': FieldValue.serverTimestamp()});
  }

  Future<void> declineFriendRequest(String requesterId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Remove from friendRequests
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('friendRequests')
        .doc(requesterId)
        .delete();
  }
}
