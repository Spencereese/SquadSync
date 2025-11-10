import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'squad_data_manager.dart';
import 'squad_persistence_manager.dart';

/// Service responsible for initializing and setting up the application state.
///
/// This service handles the complex initialization logic that was previously
/// embedded in SquadState, including user authentication setup, data loading,
/// squad initialization, and default value setup.
///
/// Key responsibilities:
/// - Initialize user data from SharedPreferences and Firestore
/// - Load and setup user squads with real-time listeners
/// - Initialize default data structures for all squad members
/// - Setup default game configuration
/// - Handle member display name loading and caching
class StateInitializer {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SquadDataManager _dataManager;
  final SquadPersistenceManager _persistenceManager;

  // Data structures that need initialization
  late Map<String, String> statuses;
  late Map<String, int> currentStreaks;
  late Map<String, int> highestStreaks;
  late Map<String, int> complaints;
  late Map<String, Map<String, dynamic>> achievements;
  late Map<String, Map<String, List<int>>> dailyRatings;
  late Map<String, Map<String, List<int>>> allTimeRatings;
  late Map<String, DateTime?> peacockTimers;
  late Map<String, bool> typing;
  late Map<String, String?> memberProfileImages;
  late Map<String, String?> preferredModes;
  late Map<String, String> globalStatuses;

  // Squad-related state
  late List<String> userSquadIds;
  late Map<String, Map<String, dynamic>> userSquads;
  late String? selectedSquadId;
  late Map<String, dynamic>? currentSquadData;
  late StreamSubscription<DocumentSnapshot>? _squadSubscription;

  // Callback for state updates
  final VoidCallback? onStateChanged;

  StateInitializer({
    required SquadDataManager dataManager,
    required SquadPersistenceManager persistenceManager,
    this.onStateChanged,
  })  : _dataManager = dataManager,
        _persistenceManager = persistenceManager {
    _initializeDataStructures();
  }

  void _initializeDataStructures() {
    statuses = {};
    currentStreaks = {};
    highestStreaks = {};
    complaints = {};
    achievements = {};
    dailyRatings = {};
    allTimeRatings = {};
    peacockTimers = {};
    typing = {};
    memberProfileImages = {};
    preferredModes = {};
    globalStatuses = {};
    userSquadIds = [];
    userSquads = {};
    selectedSquadId = null;
    currentSquadData = null;
    _squadSubscription = null;
  }

  /// Initialize user state from authentication and stored data
  Future<void> initializeUserState() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // First try to load from SharedPreferences (most reliable)
      final prefs = await SharedPreferences.getInstance();
      final prefsName = prefs.getString('yourName');

      // Then try to load from Firestore
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final displayNameFromDoc = userDoc.data()?['displayName'];

      // Prefer SharedPreferences if it has a valid name, otherwise use Firestore
      if (prefsName != null &&
          prefsName.trim().isNotEmpty &&
          prefsName != 'User') {
        _persistenceManager.displayName = prefsName.trim();
      } else if (displayNameFromDoc != null &&
          displayNameFromDoc.trim().isNotEmpty) {
        _persistenceManager.displayName = displayNameFromDoc.trim();
        // Sync back to SharedPreferences
        await prefs.setString('yourName', _persistenceManager.displayName!);
      } else {
        _persistenceManager.displayName = 'User';
      }

      _persistenceManager.profileImage = userDoc.data()?['profileImage'];

      onStateChanged?.call();
    }
  }

  /// Load existing squads for the current user
  Future<void> loadUserSquads(String uid) async {
    final query = await _firestore
        .collection('squads')
        .where('members', arrayContains: uid)
        .get();
    userSquadIds = query.docs.map((doc) => doc.id).toList();
    userSquads = {for (var doc in query.docs) doc.id: doc.data()};
    if (userSquadIds.isNotEmpty) {
      selectedSquadId = userSquadIds.first; // Select first squad
      currentSquadData = userSquads[selectedSquadId];
      // Update squad members from the squad document
      _dataManager.squadMemberUids =
          List<String>.from(currentSquadData?['members'] ?? []);
      _invalidateCache(); // Clear cached display names
      // Load display names for squad members
      await loadMemberDisplayNames();
    } else {
      // No squads yet
      selectedSquadId = null;
      currentSquadData = null;
      _dataManager.squadMemberUids = [];
      _invalidateCache();
    }
  }

  /// Listen to squad document changes for real-time updates
  void listenToSquadChanges() {
    if (selectedSquadId == null) return;
    _squadSubscription?.cancel(); // Cancel previous
    _squadSubscription = _firestore
        .collection('squads')
        .doc(selectedSquadId)
        .snapshots()
        .listen((doc) {
      if (doc.exists) {
        currentSquadData = doc.data();
        // Update squad members from the squad document
        _dataManager.squadMemberUids =
            List<String>.from(currentSquadData?['members'] ?? []);
        _invalidateCache(); // Clear cached display names
        // Load display names for squad members
        loadMemberDisplayNames();
        // Update derived properties (e.g., spots from subcollection)
        _syncSpotsFromSquad();
        onStateChanged?.call();
      }
    });
  }

  /// Load squad data and start listening for changes
  void loadSquadData(String squadId) {
    selectedSquadId = squadId;
    listenToSquadChanges();
  }

  /// Load display names for squad members
  Future<void> loadMemberDisplayNames() async {
    if (_dataManager.squadMemberUids.isEmpty) return;

    // Load display names in parallel for better performance
    final futures = _dataManager.squadMemberUids
        .where((uid) => !_dataManager.memberDisplayNames.containsKey(uid))
        .map((uid) async {
      try {
        final userDoc = await _firestore.collection('users').doc(uid).get();
        final displayName = userDoc.data()?['displayName'] ?? 'User';
        _dataManager.memberDisplayNames[uid] = displayName;
      } catch (e) {
        // If we can't load the display name, use a fallback
        _dataManager.memberDisplayNames[uid] = 'User';
      }
    });

    await Future.wait(futures);
    onStateChanged?.call();
  }

  /// Initialize default data structures for squad members
  void initializeData() {
    final squadMembers = _dataManager.squadMemberUids
        .map((uid) => _dataManager.memberDisplayNames[uid] ?? 'User')
        .toList();

    for (var player in squadMembers) {
      // Only set default values if not already set
      if (!statuses.containsKey(player)) {
        statuses[player] = 'Offline';
      }
      if (!currentStreaks.containsKey(player)) {
        currentStreaks[player] = 0;
      }
      if (!highestStreaks.containsKey(player)) {
        highestStreaks[player] = 0;
      }
      if (!complaints.containsKey(player)) {
        complaints[player] = 0;
      }
      if (!achievements.containsKey(player)) {
        achievements[player] = {};
      }
      if (!dailyRatings.containsKey(player)) {
        dailyRatings[player] = {
          "Vibes": [],
          "Comms": [],
          "Gunny": [],
          "Wingman": []
        };
      }
      if (!allTimeRatings.containsKey(player)) {
        allTimeRatings[player] = {
          "Vibes": [],
          "Comms": [],
          "Gunny": [],
          "Wingman": []
        };
      }
      if (!peacockTimers.containsKey(player)) {
        peacockTimers[player] = null;
      }
      if (!typing.containsKey(player)) {
        typing[player] = false;
      }
      if (!memberProfileImages.containsKey(player)) {
        memberProfileImages[player] = null;
      }
      if (!preferredModes.containsKey(player)) {
        preferredModes[player] = null;
      }
    }
    globalStatuses["Alex"] = "Walking";
    globalStatuses["Spencer"] = "Walking";

    // Set default game to Warzone if not already set
    if (_dataManager.currentGame == null) {
      _dataManager.currentGame = {
        'name': 'Warzone',
        'maxSpots': 4,
        'description': 'Call of Duty: Warzone - Battle Royale',
        'logo': 'assets/images/placeholder.png'
      };
      // Initialize default game spots
      final gameName = _dataManager.currentGame!['name'];
      if (!_dataManager.gameSquadSpots.containsKey(gameName)) {
        _dataManager.gameSquadSpots[gameName] =
            List.filled(_dataManager.currentGame!['maxSpots'], null);
        _dataManager.gameSpotTimers[gameName] =
            List.filled(_dataManager.currentGame!['maxSpots'], null);
      }
    }
  }

  /// Invalidate cached display names
  void _invalidateCache() {
    // Implementation depends on cache service - placeholder for now
    // This would typically clear any cached computed values
  }

  /// Sync spots data from squad document
  void _syncSpotsFromSquad() {
    // Implementation for syncing spots from squad subcollection
    // This would typically load spots data from Firestore subcollection
  }

  /// Clean up resources
  void dispose() {
    _squadSubscription?.cancel();
  }
}
