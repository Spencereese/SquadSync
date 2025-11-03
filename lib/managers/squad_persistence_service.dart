import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../managers/squad_data_manager.dart';
import '../managers/squad_ui_manager.dart';
import '../managers/squad_persistence_manager.dart';
import '../services/firestore_service.dart';
import '../services/cache_service.dart';

/// Service responsible for all Firestore persistence operations in the squad system.
///
/// This service handles:
/// - Data synchronization from Firestore to local state
/// - Real-time listeners for squad changes
/// - CRUD operations for games, lobbies, and squad data
/// - Firestore document updates and batch operations
/// - Migration of legacy data structures
class SquadPersistenceService with ChangeNotifier {
  final SquadDataManager dataManager;
  final SquadUIManager uiManager;
  final SquadPersistenceManager persistenceManager;
  final FirestoreService firestoreService;
  final CacheService cacheService;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<DocumentSnapshot>? _squadSubscription;

  SquadPersistenceService({
    required this.dataManager,
    required this.uiManager,
    required this.persistenceManager,
    required this.firestoreService,
    required this.cacheService,
  });

  /// Initialize the persistence service
  void initialize() {
    _setupListeners();
  }

  /// Dispose of the persistence service
  @override
  void dispose() {
    _squadSubscription?.cancel();
    super.dispose();
  }

  /// Sync squad data from Firestore
  void syncWithFirestore() {
    _firestore.collection('squad').doc('state').snapshots().listen((snapshot) {
      if (snapshot.exists) {
        var data = snapshot.data()!;
        debugPrint("Raw Firestore data: ${data.toString()}");

        // Handle game-specific data or migrate legacy data
        if (data['gameSquadSpots'] != null) {
          dataManager.globalStatuses = Map<String, String>.fromEntries(
              (data['globalStatuses'] as Map<String, dynamic>? ?? {})
                  .entries
                  .where((entry) => entry.key.isNotEmpty && entry.value != null)
                  .map((entry) => MapEntry(entry.key, entry.value as String)));
        } else {
          // Migrate legacy data to current game
          dataManager.globalStatuses = Map<String, String>.fromEntries(
              (data['globalStatuses'] as Map<String, dynamic>? ?? {})
                  .entries
                  .where((entry) => entry.key.isNotEmpty && entry.value != null)
                  .map((entry) => MapEntry(entry.key, entry.value as String)));
        }

        dataManager.squadMemberUids = List<String>.from(data['members'] ?? []);

        // Handle migration: if members contain old hardcoded names instead of UIDs,
        // treat them as display names and map to current user UID for now
        final currentUserUid = FirebaseAuth.instance.currentUser?.uid;
        if (currentUserUid != null &&
            dataManager.squadMemberUids.any((uid) => uid.length < 20)) {
          dataManager.squadMemberUids = [currentUserUid];
          dataManager.memberDisplayNames[currentUserUid] =
              persistenceManager.displayName ?? 'User';
        }

        _loadMemberDisplayNames();

        // Load additional data fields
        _loadAdditionalDataFields(data);

        cacheService.invalidateAll();
        notifyListeners();
      }
    });
  }

  /// Listen to squad changes and set up real-time listeners
  void listenToSquadChanges(String? selectedSquadId) {
    if (selectedSquadId == null) return;

    // Listen to squad document changes
    _firestore
        .collection('squads')
        .doc(selectedSquadId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data()!;
        _handleSquadDataUpdate(data);
      }
    });

    // Listen to chat messages
    _firestore.collection('chat').snapshots().listen((snapshot) {
      bool hasNew = snapshot.docChanges.any((change) =>
          change.type == DocumentChangeType.added &&
          (change.doc.data()?['read'] ?? true) == false &&
          change.doc.data()?['sender_name'] != null &&
          change.doc.data()?['content'] != null);
      if (hasNew) {
        uiManager.hasUnreadMessages = true;
        // TODO: Send notification
      }
      notifyListeners();
    });

    // Listen to chat group messages
    _firestore
        .collection('squads')
        .doc(selectedSquadId)
        .collection('chat_groups')
        .snapshots()
        .listen((groupsSnapshot) async {
      for (var groupDoc in groupsSnapshot.docs) {
        final groupData = groupDoc.data();
        final isPublic = groupData['isPublic'] ?? false;
        final members = List<String>.from(groupData['members'] ?? []);

        if (isPublic ||
            members.contains(FirebaseAuth.instance.currentUser?.uid)) {
          _firestore
              .collection('squads')
              .doc(selectedSquadId)
              .collection('chat_groups')
              .doc(groupDoc.id)
              .collection('messages')
              .snapshots()
              .listen((messagesSnapshot) {
            bool hasNew = messagesSnapshot.docChanges.any((change) =>
                change.type == DocumentChangeType.added &&
                (change.doc.data()?['read'] ?? true) == false &&
                change.doc.data()?['sender_name'] != null &&
                change.doc.data()?['content'] != null);
            if (hasNew) {
              uiManager.hasUnreadMessages = true;
              // TODO: Send notification for group
            }
            notifyListeners();
          });
        }
      }
    });

    // Listen to lobbies for all games
    for (final game in dataManager.availableGames) {
      final gameName = game['name'] as String;
      _firestore
          .collection('lobbies')
          .doc(gameName)
          .collection('lobbies')
          .snapshots()
          .listen((snapshot) {
        dataManager.gameLobbies[gameName] = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
        notifyListeners();
      });
    }
  }

  /// Update Firestore with current state
  void updateFirestore({bool force = false}) {
    firestoreService.updateFirestore(
      displayNameCache: dataManager.memberDisplayNames,
      force: force,
    );
  }

  /// Mark a field as changed for batch updates
  void markFieldChanged(String field) {
    firestoreService.markFieldChanged(field);
  }

  /// Sync spots from squad subcollection
  Future<void> syncSpotsFromSquad(String? selectedSquadId) async {
    if (selectedSquadId == null) return;
    final spotsSnapshot = await _firestore
        .collection('squads')
        .doc(selectedSquadId)
        .collection('spots')
        .get();

    final gameName = dataManager.currentGame?['name'] ?? '';
    dataManager.gameSquadSpots[gameName] = List<String?>.filled(8, null);

    for (var doc in spotsSnapshot.docs) {
      final index = int.tryParse(doc.id);
      if (index != null && index < 8) {
        dataManager.gameSquadSpots[gameName]![index] = doc.data()['uid'];
      }
    }

    // Auto-assign creator to first spot if no spots are assigned yet
    if (spotsSnapshot.docs.isEmpty &&
        dataManager.currentSquadData?['creatorUid'] ==
            FirebaseAuth.instance.currentUser?.uid) {
      final userName = persistenceManager.displayName;
      if (userName != null && dataManager.currentGame != null) {
        // TODO: Call spot claiming through timer service
      }
    }
  }

  /// Add a new game to Firestore
  Future<void> addGame(Map<String, dynamic> game) async {
    await _firestore.collection('games').add(game);

    // Set up lobbies listener for the new game
    final gameName = game['name'] as String;
    _firestore
        .collection('lobbies')
        .doc(gameName)
        .collection('lobbies')
        .snapshots()
        .listen((snapshot) {
      dataManager.gameLobbies[gameName] = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      notifyListeners();
    });
  }

  /// Edit an existing game in Firestore
  Future<void> editGame(Map<String, dynamic> updatedGame) async {
    await _firestore
        .collection('games')
        .doc(updatedGame['name'])
        .set(updatedGame);
  }

  /// Join a lobby
  Future<void> joinLobby(String lobbyId, String playerName) async {
    // Find the lobby across all games
    Map<String, dynamic>? targetLobby;
    String? targetGame;

    for (final gameEntry in dataManager.gameLobbies.entries) {
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

        // Update Firestore
        await _firestore
            .collection('lobbies')
            .doc(targetGame)
            .collection('lobbies')
            .doc(lobbyId)
            .update({'players': players});

        notifyListeners();
      }
    }
  }

  /// Update user profile image
  Future<void> updateProfileImage(String url) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set({'profileImage': url}, SetOptions(merge: true));
    }
  }

  /// Update user display name
  Future<void> updateDisplayName(String name) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set({'displayName': name}, SetOptions(merge: true));
    }
  }

  /// Get active alerts for chat list
  Future<List<Map<String, dynamic>>> getActiveAlerts() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('circles')
          .where('status', isEqualTo: 'active')
          .get();

      final alerts = <Map<String, dynamic>>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final gameName = data['gameName'] as String?;
        if (gameName != null) {
          final hostName = data['hostName'] ?? 'Unknown';
          final maxSpots = data['maxSpots'] ?? 4;
          final chatGroupId = data['chatGroupId'] ?? '';
          alerts.add({
            'gameName': gameName,
            'hostName': hostName,
            'maxSpots': maxSpots,
            'chatGroupId': chatGroupId,
          });
        }
      }
      return alerts;
    } catch (e) {
      debugPrint('Error fetching active alerts: $e');
      return [];
    }
  }

  /// Enrich games with IGDB data
  Future<void> enrichGamesWithIgdbData(List<Map<String, dynamic>> games) async {
    // This would delegate to gameManager.enrichGamesWithIgdbData
    // For now, just update Firestore with enriched data
    if (dataManager.selectedSquadId != null) {
      await _firestore
          .collection('squads')
          .doc(dataManager.selectedSquadId)
          .set({
        'availableGames': games,
      }, SetOptions(merge: true));
    }
  }

  // Private helper methods

  void _setupListeners() {
    // Any additional setup can go here
  }

  void _loadMemberDisplayNames() {
    // Load display names for all squad members
    for (final uid in dataManager.squadMemberUids) {
      if (!dataManager.memberDisplayNames.containsKey(uid)) {
        // Load from Firestore or cache
        _firestore.collection('users').doc(uid).get().then((doc) {
          if (doc.exists) {
            final displayName = doc.data()?['displayName'] as String?;
            if (displayName != null) {
              dataManager.memberDisplayNames[uid] = displayName;
              notifyListeners();
            }
          }
        });
      }
    }
  }

  void _loadAdditionalDataFields(Map<String, dynamic> data) {
    // Load additional data fields from Firestore
    dataManager.currentStreaks = Map<String, int>.from(
        data['currentStreaks'] ?? dataManager.currentStreaks);
    dataManager.highestStreaks = Map<String, int>.from(
        data['highestStreaks'] ?? dataManager.highestStreaks);
    dataManager.complaints =
        Map<String, int>.from(data['complaints'] ?? dataManager.complaints);
    dataManager.achievements =
        (data['achievements'] as Map<dynamic, dynamic>? ?? {}).map(
      (k, v) => MapEntry(
          k.toString(), Set<String>.from(v.map((item) => item.toString()))),
    );
    // Load other fields...
  }

  void _handleSquadDataUpdate(Map<String, dynamic> data) {
    // Handle squad document updates
    dataManager.currentSquadData = data;
    dataManager.availableGames =
        List<Map<String, dynamic>>.from(data['availableGames'] ?? []);

    // Handle other squad-level data updates
    notifyListeners();
  }
}
