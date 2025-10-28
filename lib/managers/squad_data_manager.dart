import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../notification_service.dart';

class SquadDataManager {
  // Game-specific squad spots: Map<gameName, List<String?>>
  Map<String, List<String?>> gameSquadSpots = {};
  // Game-specific spot timers: Map<gameName, List<Map<String, dynamic>?>>
  Map<String, List<Map<String, dynamic>?>> gameSpotTimers = {};
  // Game-specific statuses: Map<gameName, Map<String, String>>
  Map<String, Map<String, String>> gameStatuses = {};
  // Global statuses that persist across games (Walking, Strutting, etc.)
  Map<String, String> globalStatuses = {};

  // New: Store member UIDs and provide display names dynamically
  List<String> squadMemberUids = [];
  Map<String, String> memberDisplayNames = {}; // Cache display names by UID

  // Keep properties that are still needed directly
  List<Map<String, dynamic>> gameHistory = [];
  Map<String, String?> preferredModes = {};

  // Blocked users map per user
  Map<String, Map<String, bool>> userBlocks = {};

  // Daily ban votes: Map<targetPlayer, Map<voter, timestamp>>
  Map<String, Map<String, int>> dailyBanVotes = {};

  // Local currentGame for backward compatibility
  Map<String, dynamic>? _currentGame;

  // Multiple squad tracking
  List<String> userSquadIds = [];
  String? selectedSquadId;
  Map<String, Map<String, dynamic>> userSquads =
      {}; // Store squad data for all user squads
  Map<String, dynamic>? _currentSquadData;
  Map<String, dynamic>? get currentSquadData => _currentSquadData;
  set currentSquadData(Map<String, dynamic>? value) =>
      _currentSquadData = value;

  // Game-related data
  List<Map<String, dynamic>> availableGames = [];
  Map<String, List<Map<String, dynamic>>> gameLobbies = {};
  Set<String> preferredPeacockGames = {};
  Set<String> mutedGames = {};
  Set<String> hiddenGames = {};

  // Achievement data
  Map<String, int> currentStreaks = {};
  Map<String, int> highestStreaks = {};
  Map<String, Set<String>> achievements = {};
  Map<String, Map<String, List<int>>> dailyRatings = {};
  Map<String, Map<String, List<int>>> allTimeRatings = {};
  Map<String, int> complaints = {};
  Map<String, List<Map<String, dynamic>>> bans = {};

  // Scheduling data
  List<Map<String, dynamic>> scheduledTimes = [];

  // Peacock data
  Map<String, Map<String, dynamic>?> peacockTimers = {};
  List<String> peacockQueue = [];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Getters for computed properties
  List<String?> get squadSpots {
    final gameName = currentGame?['name'] ?? '';
    final rawSpots = gameSquadSpots[gameName] ?? [];
    return rawSpots
        .map((uid) => uid != null ? getDisplayNameForUid(uid) : null)
        .toList();
  }

  List<Map<String, dynamic>?> get spotTimers {
    final gameName = currentGame?['name'] ?? '';
    if (!gameSpotTimers.containsKey(gameName)) {
      final maxSpots = currentGame?['maxSpots'] ?? 4;
      gameSpotTimers[gameName] = List.filled(maxSpots, null);
    }
    return gameSpotTimers[gameName] ?? [];
  }

  Map<String, String> get statuses {
    final rawStatuses = gameStatuses[currentGame?['name'] ?? ''] ?? {};
    // Convert UID keys to display name keys
    return Map.fromEntries(
      rawStatuses.entries.map((entry) => MapEntry(
            getDisplayNameForUid(entry.key),
            entry.value,
          )),
    );
  }

  List<String> get squadMembers {
    return squadMemberUids.map((uid) => getDisplayNameForUid(uid)).toList();
  }

  Map<String, dynamic>? get currentGame => _currentGame;
  set currentGame(Map<String, dynamic>? game) => _currentGame = game;

  bool get isCreator =>
      selectedSquadId != null &&
      FirebaseAuth.instance.currentUser?.uid ==
          _currentSquadData?['creatorUid'];

  // Display name methods
  String getDisplayNameForUid(String uid) {
    if (memberDisplayNames.containsKey(uid)) {
      return memberDisplayNames[uid]!;
    }
    return 'User';
  }

  String? getUidForDisplayName(String displayName) {
    return memberDisplayNames.entries
            .firstWhere((entry) => entry.value == displayName,
                orElse: () => MapEntry('', ''))
            .key
            .isEmpty
        ? null
        : memberDisplayNames.entries
            .firstWhere((entry) => entry.value == displayName)
            .key;
  }

  // Data manipulation methods
  void claimSpot(int index, String userName, String userUid) {
    final gameName = currentGame?['name'] ?? '';

    if (!gameSquadSpots.containsKey(gameName)) {
      final maxSpots = currentGame?['maxSpots'] ?? 4;
      gameSquadSpots[gameName] = List.filled(maxSpots, null);
      gameSpotTimers[gameName] = List.filled(maxSpots, null);
    }

    // If user is already assigned to a different spot, remove them from it first
    final currentSpotIndex = squadSpots.indexOf(userName);
    if (currentSpotIndex != -1 && currentSpotIndex != index) {
      gameSquadSpots[gameName]![currentSpotIndex] = null;
      gameSpotTimers[gameName]![currentSpotIndex] = null;
    }

    gameSquadSpots[gameName]![index] = userUid;
    gameSpotTimers[gameName]![index] = {
      'startTime': DateTime.now().millisecondsSinceEpoch,
      'duration': 300,
      'calling': true,
    };
    globalStatuses[userName] = 'Calling'; // Set status to calling
  }

  void callSpotForGame(
      int index, String userName, String userUid, String gameName,
      {int? maxSpots}) {
    if (!gameSquadSpots.containsKey(gameName)) {
      final spotsCount = maxSpots ?? 4;
      gameSquadSpots[gameName] = List.filled(spotsCount, null);
      gameSpotTimers[gameName] = List.filled(spotsCount, null);
    }

    // If user is already assigned to a different spot in this game, remove them from it first
    final currentSpotIndex = gameSquadSpots[gameName]?.indexOf(userUid);
    if (currentSpotIndex != null &&
        currentSpotIndex != -1 &&
        currentSpotIndex != index) {
      gameSquadSpots[gameName]![currentSpotIndex] = null;
      gameSpotTimers[gameName]![currentSpotIndex] = null;
    }

    // Set calling status - spot is reserved but not locked yet
    gameSquadSpots[gameName]![index] =
        '${userUid}_calling'; // Temporary calling state
    gameSpotTimers[gameName]![index] = {
      'startTime': DateTime.now().millisecondsSinceEpoch,
      'duration': 300, // 5 minute calling timer
      'calling': true,
    };
    globalStatuses[userName] = 'Calling'; // Set status to calling
  }

  void lockCalledSpot(
      String gameName, int index, String userName, String userUid) {
    // Convert calling spot to locked spot
    final currentSpot = gameSquadSpots[gameName]?[index];
    if (currentSpot == '${userUid}_calling' || currentSpot == userUid) {
      gameSquadSpots[gameName]![index] = userUid;
      gameSpotTimers[gameName]![index] = {
        'startTime': DateTime.now().millisecondsSinceEpoch,
        'duration': -1, // Count up to show time in lobby
      };
      globalStatuses[userName] = 'Ready'; // Set status to ready for walking
    }
  }

  void assignSpot(int index, String player) {
    final playerUid = getUidForDisplayName(player);
    final gameName = currentGame?['name'] ?? '';

    if (playerUid != null) {
      if (!gameSquadSpots.containsKey(gameName)) {
        final maxSpots = currentGame?['maxSpots'] ?? 4;
        gameSquadSpots[gameName] = List.filled(maxSpots, null);
        gameSpotTimers[gameName] = List.filled(maxSpots, null);
      }

      gameSquadSpots[gameName]![index] = playerUid;
      gameSpotTimers[gameName]![index] = {
        'startTime': DateTime.now().millisecondsSinceEpoch,
        'duration': 300,
      };
      globalStatuses[player] = 'Ready';
    }
  }

  void leaveSpot(int index) {
    final gameName = currentGame?['name'] ?? '';
    if (gameSquadSpots.containsKey(gameName) &&
        index < gameSquadSpots[gameName]!.length) {
      gameSquadSpots[gameName]![index] = null;
      gameSpotTimers[gameName]![index] = null;
    }
  }

  void setStatus(String player, String status) {
    final gameName = currentGame?['name'] ?? '';
    if (!gameStatuses.containsKey(gameName)) {
      gameStatuses[gameName] = {};
    }
    gameStatuses[gameName]![player] = status;
  }

  void addPreferredPeacockGame(String gameName) {
    preferredPeacockGames.add(gameName);
  }

  void removePreferredPeacockGame(String gameName) {
    preferredPeacockGames.remove(gameName);
  }

  void muteGame(String gameName) {
    mutedGames.add(gameName);
  }

  void unmuteGame(String gameName) {
    mutedGames.remove(gameName);
  }

  void hideGame(String gameName) {
    hiddenGames.add(gameName);
    muteGame(gameName);
  }

  void unhideGame(String gameName) {
    hiddenGames.remove(gameName);
    unmuteGame(gameName);
  }

  bool isGameHidden(String gameName) {
    return hiddenGames.contains(gameName);
  }

  bool isGameMuted(String gameName) {
    return mutedGames.contains(gameName);
  }

  void startSoloGame(String userName, [String? gameName]) {
    if (gameName != null) {
      globalStatuses[userName] = 'Playing: $gameName (Solo)';
    } else {
      globalStatuses[userName] = 'Playing Solo';
    }
  }

  void stopSoloGame(String userName) {
    globalStatuses.remove(userName);
  }

  bool isPlayingSolo(String playerName) {
    final status = globalStatuses[playerName];
    return status != null &&
        (status.contains('(Solo)') || status == 'Playing Solo');
  }

  void joinLobby(String lobbyId, String playerName) {
    Map<String, dynamic>? targetLobby;
    String? targetGame;

    for (final gameEntry in gameLobbies.entries) {
      final lobby = gameEntry.value.firstWhere(
        (l) => l['id'] == lobbyId,
        orElse: () => <String, dynamic>{},
      );
      if (lobby.isNotEmpty) {
        targetLobby = lobby;
        targetGame = gameEntry.key;
        break;
      }
    }

    if (targetLobby != null && targetGame != null) {
      final players = List<String>.from(targetLobby['players'] ?? []);
      if (!players.contains(playerName)) {
        players.add(playerName);
        targetLobby['players'] = players;
        _firestore
            .collection('lobbies')
            .doc(targetGame)
            .collection('lobbies')
            .doc(lobbyId)
            .update({'players': players});
      }
    }
  }

  void addGame(Map<String, dynamic> game) {
    if (!availableGames.any((g) => g['name'] == game['name'])) {
      availableGames.add(game);
      _firestore.collection('games').add(game);
    }
  }

  void editGame(int index, Map<String, dynamic> updatedGame) {
    if (index >= 0 && index < availableGames.length) {
      availableGames[index] = updatedGame;
      _firestore.collection('games').doc(updatedGame['name']).set(updatedGame);
    }
  }

  void deleteGame(int index) {
    if (index >= 0 && index < availableGames.length) {
      if (availableGames[index]['name'] == _currentGame?['name']) {
        return;
      }
      availableGames.removeAt(index);
    }
  }

  Map<String, dynamic>? getPlayerLobby(String playerName) {
    for (final gameLobbies in gameLobbies.values) {
      for (final lobby in gameLobbies) {
        final players = List<String>.from(lobby['players'] ?? []);
        if (players.contains(playerName)) {
          return lobby;
        }
      }
    }
    return null;
  }

  bool hasBlockedPlayersInLobby(
      Map<String, dynamic> lobby, String currentUserId) {
    final userBlocks = this.userBlocks[currentUserId] ?? {};
    final players = List<String>.from(lobby['players'] ?? []);
    return players
        .any((player) => userBlocks.containsKey(player) && userBlocks[player]!);
  }

  String? getPlayerPreferredGame(String playerName) {
    return null;
  }

  List<Map<String, dynamic>> getVisibleLobbies(String gameName) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final userBlocks = this.userBlocks[uid] ?? {};

    return gameLobbies[gameName]?.where((lobby) {
          final players = List<String>.from(lobby['players'] ?? []);
          return !players.any((player) =>
              userBlocks.containsKey(player) && userBlocks[player]!);
        }).toList() ??
        [];
  }

  Future<void> removeFromPeacock(String player) async {
    if (peacockTimers.containsKey(player)) {
      peacockTimers.remove(player);
    } else if (peacockQueue.contains(player)) {
      peacockQueue.remove(player);
    }
  }

  Future<void> submitComplaint({
    required String targetMember,
    required String reason,
    required String category,
    required String submittedBy,
  }) async {
    if (!squadMembers.contains(targetMember)) {
      throw Exception('Invalid member: $targetMember');
    }

    try {
      await _firestore
          .collection('squad')
          .doc('state')
          .collection('complaints')
          .add({
        'targetMember': targetMember,
        'reason': reason,
        'category': category,
        'submittedBy': submittedBy,
        'timestamp': FieldValue.serverTimestamp(),
      });

      complaints[targetMember] = (complaints[targetMember] ?? 0) + 1;

      await NotificationService.sendNotificationToUser(
        recipientDisplayName: targetMember,
        title: 'New Complaint',
        body: 'You received a complaint: $reason ($category).',
      );
    } catch (e) {
      debugPrint('Failed to submit complaint: $e');
      rethrow;
    }
  }

  Future<void> submitRatings({
    required String targetMember,
    required Map<String, int?> ratings,
    required String submittedBy,
  }) async {
    if (!squadMembers.contains(targetMember)) {
      throw Exception('Invalid member: $targetMember');
    }

    try {
      final targetUid = getUidForDisplayName(targetMember);
      if (targetUid == null) return;

      final now = DateTime.now();
      final todayKey = '${now.year}-${now.month}-${now.day}';

      // Initialize if needed
      dailyRatings[targetUid] ??= {};
      allTimeRatings[targetUid] ??= {};

      ratings.forEach((category, rating) {
        if (rating != null) {
          // Daily ratings
          dailyRatings[targetUid]![todayKey] ??= [];
          dailyRatings[targetUid]![todayKey]!.add(rating);

          // All-time ratings
          allTimeRatings[targetUid]![category] ??= [];
          allTimeRatings[targetUid]![category]!.add(rating);
        }
      });

      // Update streaks
      final submitterUid = getUidForDisplayName(submittedBy);
      if (submitterUid != null) {
        currentStreaks[submitterUid] = (currentStreaks[submitterUid] ?? 0) + 1;
        if (currentStreaks[submitterUid]! >
            (highestStreaks[submitterUid] ?? 0)) {
          highestStreaks[submitterUid] = currentStreaks[submitterUid]!;
        }
      }

      await _firestore.collection('squad').doc('state').set({
        'dailyRatings': dailyRatings,
        'allTimeRatings': allTimeRatings,
        'currentStreaks': currentStreaks,
        'highestStreaks': highestStreaks,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to submit ratings: $e');
      rethrow;
    }
  }

  // Squad management
  Future<String> createSquad(String name) async {
    final squadId = _firestore.collection('squads').doc().id;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _firestore.collection('squads').doc(squadId).set({
        'name': name,
        'creatorUid': user.uid,
        'members': [user.uid],
        'inviteCode': squadId.substring(0, 6).toUpperCase(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      userSquadIds.add(squadId);
      selectedSquadId = squadId;
      userSquads[squadId] = {
        'name': name,
        'creatorUid': user.uid,
        'members': [user.uid],
        'inviteCode': squadId.substring(0, 6).toUpperCase(),
      };
      _currentSquadData = userSquads[squadId];
    }
    return squadId;
  }

  Future<bool> joinSquad(String code) async {
    final query = await _firestore
        .collection('squads')
        .where('inviteCode', isEqualTo: code)
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) {
      final squadId = query.docs.first.id;
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !userSquadIds.contains(squadId)) {
        final squadData = query.docs.first.data();
        final members = List<String>.from(squadData['members'] ?? []);
        if (!members.contains(user.uid)) {
          members.add(user.uid);
          await _firestore.collection('squads').doc(squadId).update({
            'members': members,
          });
        }
        userSquadIds.add(squadId);
        selectedSquadId = squadId;
        userSquads[squadId] = squadData;
        _currentSquadData = userSquads[squadId];
        return true;
      }
    }
    return false;
  }

  Future<void> leaveSquad(String squadId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final squadData = userSquads[squadId];
      if (squadData != null) {
        final members = List<String>.from(squadData['members'] ?? []);
        members.remove(user.uid);
        if (members.isEmpty) {
          await _firestore.collection('squads').doc(squadId).delete();
        } else {
          await _firestore.collection('squads').doc(squadId).update({
            'members': members,
          });
        }
      }
      userSquadIds.remove(squadId);
      if (selectedSquadId == squadId) {
        selectedSquadId = userSquadIds.isNotEmpty ? userSquadIds.first : null;
        _currentSquadData =
            selectedSquadId != null ? userSquads[selectedSquadId] : null;
      }
    }
  }

  void selectSquad(String squadId) {
    if (userSquadIds.contains(squadId) && userSquads.containsKey(squadId)) {
      selectedSquadId = squadId;
      _currentSquadData = userSquads[squadId];
    }
  }

  Map<String, dynamic>? getSquadById(String squadId) {
    return userSquads[squadId];
  }
}
