import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

/// Manages squad spots, assignments, and timers
class SquadManager with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Game-specific squad spots: Map<gameName, List<String?>>
  Map<String, List<String?>> gameSquadSpots = {};
  // Game-specific spot timers: Map<gameName, List<Map<String, dynamic>?>>
  Map<String, List<Map<String, dynamic>?>> gameSpotTimers = {};

  List<String?> get squadSpots {
    final gameName = currentGame?['name'] ?? '';
    if (!gameSquadSpots.containsKey(gameName)) {
      final maxSpots = currentGame?['maxSpots'] ?? 4;
      gameSquadSpots[gameName] = List.filled(maxSpots, null);
      gameSpotTimers[gameName] = List.filled(maxSpots, null);
    }
    return gameSquadSpots[gameName] ?? [];
  }

  List<Map<String, dynamic>?> get spotTimers {
    final gameName = currentGame?['name'] ?? '';
    if (!gameSpotTimers.containsKey(gameName)) {
      final maxSpots = currentGame?['maxSpots'] ?? 4;
      gameSpotTimers[gameName] = List.filled(maxSpots, null);
    }
    return gameSpotTimers[gameName] ?? [];
  }

  Map<String, dynamic>? currentGame;

  List<String?> getSquadSpots(String gameName) {
    if (!gameSquadSpots.containsKey(gameName)) {
      final maxSpots = currentGame?['maxSpots'] ?? 4;
      gameSquadSpots[gameName] = List.filled(maxSpots, null);
      gameSpotTimers[gameName] = List.filled(maxSpots, null);
    }
    return gameSquadSpots[gameName] ?? [];
  }

  List<Map<String, dynamic>?> getSpotTimers(String gameName) {
    if (!gameSpotTimers.containsKey(gameName)) {
      final maxSpots = currentGame?['maxSpots'] ?? 4;
      gameSpotTimers[gameName] = List.filled(maxSpots, null);
    }
    return gameSpotTimers[gameName] ?? [];
  }

  Map<String, String> getStatuses(
      String gameName, Map<String, String> globalStatuses) {
    // Merge global statuses with game-specific statuses
    final mergedStatuses = Map<String, String>.from(globalStatuses);
    // Global statuses take precedence over game-specific statuses
    return mergedStatuses;
  }

  void claimSpot(int index) {
    if (index >= 0 && index < squadSpots.length) {
      // Implementation from original SquadState
      notifyListeners();
    }
  }

  void assignSpot(int index, String player) {
    final gameName = currentGame?['name'] ?? '';
    if (gameSquadSpots.containsKey(gameName) &&
        index >= 0 &&
        index < gameSquadSpots[gameName]!.length) {
      gameSquadSpots[gameName]![index] = player;
      notifyListeners();
    }
  }

  void removeSpot(int index) {
    final gameName = currentGame?['name'] ?? '';
    if (gameSquadSpots.containsKey(gameName) &&
        index >= 0 &&
        index < gameSquadSpots[gameName]!.length) {
      gameSquadSpots[gameName]![index] = null;
      notifyListeners();
    }
  }

  void lockSpot(int index) {
    // Implementation from original SquadState
    notifyListeners();
  }

  void clearAllSpots() {
    final gameName = currentGame?['name'] ?? '';
    if (gameSquadSpots.containsKey(gameName)) {
      gameSquadSpots[gameName] =
          List.filled(gameSquadSpots[gameName]!.length, null);
      notifyListeners();
    }
  }

  void resetTimers() {
    final gameName = currentGame?['name'] ?? '';
    if (gameSpotTimers.containsKey(gameName)) {
      gameSpotTimers[gameName] =
          List.filled(gameSpotTimers[gameName]!.length, null);
      notifyListeners();
    }
  }

  void updateSpotTimers() {
    // Implementation from original SquadState
    notifyListeners();
  }

  String getSpotTimerDisplay(int index) {
    final gameName = currentGame?['name'] ?? '';
    if (gameSpotTimers.containsKey(gameName) &&
        index >= 0 &&
        index < gameSpotTimers[gameName]!.length) {
      final timerData = gameSpotTimers[gameName]![index];
      if (timerData != null && timerData['seconds'] != null) {
        return _formatTimer(timerData['seconds']);
      }
    }
    return '00:00';
  }

  String _formatTimer(int? seconds) {
    if (seconds == null || seconds <= 0) return '00:00';
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  // New: Create a squad and return the squadId
  Future<String> createSquad(String name) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final squadId =
        _firestore.collection('squads').doc().id; // Auto-generated ID
    final inviteCode = _generateInviteCode(); // 6-char random alphanumeric

    final squadData = {
      'name': name,
      'creatorUid': user.uid,
      'members': [user.uid], // Start with creator
      'maxSize': 8,
      'inviteCode': inviteCode,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': DateTime.now()
          .add(Duration(days: 30))
          .toIso8601String(), // Optional expiry
    };

    await _firestore.collection('squads').doc(squadId).set(squadData);
    // Auto-assign creator to spot 1 (index 0)
    await _assignSpot(squadId, 0, user.uid);
    return squadId;
  }

  // New: Join a squad by invite code
  Future<bool> joinSquad(String code) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final query = await _firestore
        .collection('squads')
        .where('inviteCode', isEqualTo: code)
        .limit(1)
        .get();

    if (query.docs.isEmpty) throw Exception('Invalid invite code');
    final squadDoc = query.docs.first;
    final data = squadDoc.data();
    final members = List<String>.from(data['members'] ?? []);
    final maxSize = data['maxSize'] ?? 8;

    if (members.contains(user.uid)) return true; // Already a member
    if (members.length >= maxSize) throw Exception('Squad is full');

    // Atomic add to members
    await _firestore.collection('squads').doc(squadDoc.id).update({
      'members': FieldValue.arrayUnion([user.uid]),
    });

    // Note: No longer auto-assigning spots on join - users can claim manually
    return true;
  }

  // New: Leave a squad (remove from members, clear spots)
  Future<void> leaveSquad(String squadId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _firestore.collection('squads').doc(squadId).update({
      'members': FieldValue.arrayRemove([user.uid]),
    });
    // Clear user's spots
    final spots = await _getSpots(squadId);
    for (int i = 0; i < spots.length; i++) {
      if (spots[i]['uid'] == user.uid) {
        await _assignSpot(squadId, i, null);
      }
    }
  }

  // Helper: Generate random 6-char invite code
  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return String.fromCharCodes(
      Iterable.generate(
          6, (_) => chars.codeUnitAt(Random().nextInt(chars.length))),
    );
  }

  // Helper: Assign spot in subcollection
  Future<void> _assignSpot(String squadId, int index, String? uid) async {
    await _firestore
        .collection('squads')
        .doc(squadId)
        .collection('spots')
        .doc(index.toString())
        .set({'uid': uid, 'assignedGame': '', 'timer': 0},
            SetOptions(merge: true));
  }

  // Helper: Get spots array from subcollection
  Future<List<Map<String, dynamic>>> _getSpots(String squadId) async {
    final snapshot = await _firestore
        .collection('squads')
        .doc(squadId)
        .collection('spots')
        .get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }
}
