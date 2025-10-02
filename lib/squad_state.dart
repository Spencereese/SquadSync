import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../notification_service.dart';

class SquadState with ChangeNotifier {
  // Game-specific squad spots: Map<gameName, List<String?>>
  Map<String, List<String?>> gameSquadSpots = {};
  // Game-specific spot timers: Map<gameName, List<Map<String, dynamic>?>>
  Map<String, List<Map<String, dynamic>?>> gameSpotTimers = {};
  // Game-specific statuses: Map<gameName, Map<String, String>>
  Map<String, Map<String, String>> gameStatuses = {};
  // Global statuses that persist across games (Walking, Strutting, etc.)
  Map<String, String> globalStatuses = {};

  // Legacy properties for backward compatibility (computed from current game)
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

  Map<String, String> get statuses {
    final gameName = currentGame?['name'] ?? '';
    if (!gameStatuses.containsKey(gameName)) {
      gameStatuses[gameName] = {};
    }
    // Merge global statuses with game-specific statuses
    final gameStatusMap = gameStatuses[gameName] ?? {};
    final mergedStatuses = Map<String, String>.from(gameStatusMap);
    // Global statuses take precedence over game-specific statuses
    globalStatuses.forEach((player, status) {
      mergedStatuses[player] = status;
    });
    return mergedStatuses;
  }

  List<String> squadMembers = [
    "Alex",
    "Spencer",
    "Landon",
    "Drew",
    "John",
    "Dalton",
    "Levi",
    "Daniel"
  ];
  Map<String, int> currentStreaks = {};
  Map<String, int> highestStreaks = {};
  Map<String, Map<String, dynamic>?> peacockTimers = {};
  List<String> peacockQueue = [];
  List<Map<String, dynamic>> gameHistory = [];
  Map<String, int> complaints = {};
  Map<String, Set<String>> achievements = {};
  Map<String, Map<String, List<int>>> dailyRatings = {};
  Map<String, Map<String, List<int>>> allTimeRatings = {};
  List<Map<String, dynamic>> scheduledTimes = [];
  Map<String, List<Map<String, dynamic>>> bans = {};
  Map<String, bool> typing = {};
  String? _profileImage;
  Map<String, String?> memberProfileImages = {};
  Map<String, String?> preferredModes = {};

  // Blocked users map per user
  Map<String, Map<String, bool>> userBlocks = {};

  // Game selection and lobbies fields
  Map<String, dynamic>? _currentGame;
  List<Map<String, dynamic>> availableGames = [];
  Map<String, List<Map<String, dynamic>>> gameLobbies = {};
  Set<String> preferredPeacockGames = {};

  // New fields for SquadQueuePage
  bool _tiltEnabled = true; // Tilt toggle
  bool _hasNewAvailability = false; // AvailabilityTab notification
  bool _hasNewSquadSpot = false; // SquadTab notification
  bool _hasUnreadMessages = false; // ChatScreen notification

  // Chat-related properties
  DocumentSnapshot? _replyingTo;
  DocumentSnapshot? get replyingTo => _replyingTo;

  // Getters for new fields
  bool get tiltEnabled => _tiltEnabled;
  bool get hasNewAvailability => _hasNewAvailability;
  bool get hasNewSquadSpot => _hasNewSquadSpot;
  bool get hasUnreadMessages => _hasUnreadMessages;

  // Filtered members getter excluding blocked users
  List<String> get getFilteredMembers {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final blocks = userBlocks[uid] ?? {};
    return squadMembers
        .where((member) => !blocks.containsKey(member) || !blocks[member]!)
        .toList();
  }

  // Get list of blocked users for current user
  List<String> get getBlockedUsers {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final blocks = userBlocks[uid] ?? {};
    return blocks.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AudioPlayer _audioPlayer = AudioPlayer();
  static const int _firestoreUpdateInterval = 5;
  DateTime _lastFirestoreUpdate = DateTime.now();
  final Set<String> _changedFields = {};
  Timer? _timer;

  BuildContext? context;
  String? _displayName;

  SquadState();

  String? get displayName => _displayName ?? 'User';
  set displayName(String? value) {
    if (value == null || value.trim().isEmpty) {
      _displayName = 'User';
    } else {
      _displayName = value.trim();
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && _displayName != null && _displayName != 'User') {
      _firestore
          .collection('users')
          .doc(user.uid)
          .set({'displayName': _displayName}, SetOptions(merge: true));
    }
    // Also save to SharedPreferences for persistence
    if (_displayName != null && _displayName != 'User') {
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('yourName', _displayName!);
      });
    }
    notifyListeners();
  }

  String? get profileImage => _profileImage;

  // Ensure currentGame is always valid
  Map<String, dynamic>? get currentGame {
    if (_currentGame != null &&
        availableGames.any((game) =>
            game['name'] == _currentGame!['name'] &&
            game['maxSpots'] == _currentGame!['maxSpots'])) {
      return _currentGame;
    }
    // Return first available game if currentGame is invalid
    return availableGames.isNotEmpty ? availableGames.first : null;
  }

  // Private setter for internal use
  set currentGame(Map<String, dynamic>? value) {
    _currentGame = value;
  }

  Future<void> initialize(BuildContext ctx) async {
    context = ctx;
    await _initState();
    _initializeData();
    _syncWithFirestore();

    // Listen for auth state changes to update display name
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null) {
        final userDoc =
            await _firestore.collection('users').doc(user.uid).get();
        final displayNameFromDoc = userDoc.data()?['displayName'];
        _displayName =
            (displayNameFromDoc == null || displayNameFromDoc.trim().isEmpty)
                ? 'User'
                : displayNameFromDoc.trim();
        _profileImage = userDoc.data()?['profileImage'];

        // Also load from SharedPreferences as backup
        final prefs = await SharedPreferences.getInstance();
        final prefsName = prefs.getString('yourName');
        if (prefsName != null && prefsName != 'User') {
          _displayName = prefsName;
        }
        notifyListeners();
      } else {
        _displayName = null;
        _profileImage = null;
        notifyListeners();
      }
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      updateSpotTimers();
      updatePeacockTimers();
      _checkPreferredModes();
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _initState() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      _displayName = userDoc.data()?['displayName'] ?? 'User';
      _profileImage = userDoc.data()?['profileImage'];

      // Also load from SharedPreferences as backup
      final prefs = await SharedPreferences.getInstance();
      final prefsName = prefs.getString('yourName');
      if (prefsName != null && prefsName != 'User') {
        _displayName = prefsName;
      }

      notifyListeners();
    }
  }

  void _initializeData() {
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
    if (_currentGame == null) {
      _currentGame = {
        'name': 'Warzone',
        'maxSpots': 4,
        'description': 'Call of Duty: Warzone - Battle Royale',
        'logo': 'assets/images/placeholder.png'
      };
      // Initialize default game spots
      final gameName = _currentGame!['name'];
      if (!gameSquadSpots.containsKey(gameName)) {
        gameSquadSpots[gameName] = List.filled(_currentGame!['maxSpots'], null);
        gameSpotTimers[gameName] = List.filled(_currentGame!['maxSpots'], null);
      }
    }
  }

  void _syncWithFirestore() {
    _firestore.collection('squad').doc('state').snapshots().listen((snapshot) {
      if (snapshot.exists) {
        var data = snapshot.data()!;
        debugPrint("Raw Firestore data: ${data.toString()}");

        // Handle game-specific data or migrate legacy data
        if (data['gameSquadSpots'] != null) {
          // New game-specific structure
          gameSquadSpots = (data['gameSquadSpots'] as Map<String, dynamic>).map(
              (gameName, spots) =>
                  MapEntry(gameName, List<String?>.from(spots ?? [])));
          gameSpotTimers = (data['gameSpotTimers'] as Map<String, dynamic>).map(
              (gameName, timers) => MapEntry(
                  gameName,
                  (timers as List)
                      .map((timer) => timer != null
                          ? Map<String, dynamic>.from(timer)
                          : null)
                      .toList()));
          gameStatuses = (data['gameStatuses'] as Map<String, dynamic>).map(
              (gameName, statusMap) => MapEntry(
                  gameName, Map<String, String>.from(statusMap ?? {})));
          globalStatuses = Map<String, String>.fromEntries(
              (data['globalStatuses'] as Map<String, dynamic>? ?? {})
                  .entries
                  .where((entry) => entry.key.isNotEmpty && entry.value != null)
                  .map((entry) => MapEntry(entry.key, entry.value as String)));
        } else {
          // Migrate legacy data to current game
          final currentGameName = _currentGame?['name'] ?? 'Warzone';
          gameSquadSpots[currentGameName] =
              List<String?>.from(data['squadSpots'] ?? []);

          // Dynamic spotTimers based on current game
          var rawSpotTimers = data['spotTimers'] ?? [];
          int maxSpots = _currentGame?['maxSpots'] ?? 4;
          gameSpotTimers[currentGameName] = List.filled(maxSpots, null);
          if (rawSpotTimers is List) {
            for (int i = 0; i < rawSpotTimers.length && i < maxSpots; i++) {
              final timer = rawSpotTimers[i];
              if (timer != null && timer is Map<String, dynamic>) {
                gameSpotTimers[currentGameName]![i] =
                    Map<String, dynamic>.from(timer);
              }
            }
          }

          gameStatuses[currentGameName] =
              Map<String, String>.from(data['statuses'] ?? {});
        }

        // Load global statuses
        globalStatuses = Map<String, String>.fromEntries(
            (data['globalStatuses'] as Map<String, dynamic>? ?? {})
                .entries
                .where((entry) => entry.key.isNotEmpty && entry.value != null)
                .map((entry) => MapEntry(entry.key, entry.value as String)));

        squadMembers = List<String>.from(data['members'] ?? squadMembers);

        // Ensure all games have status entries for all members
        for (final gameName in gameStatuses.keys) {
          for (var player in squadMembers) {
            if (!gameSquadSpots[gameName]!.contains(player) &&
                !peacockTimers.containsKey(player) &&
                !peacockQueue.contains(player)) {
              gameStatuses[gameName]![player] =
                  gameStatuses[gameName]![player] ?? 'Offline';
            }
          }
        }

        currentStreaks =
            Map<String, int>.from(data['currentStreaks'] ?? currentStreaks);
        highestStreaks =
            Map<String, int>.from(data['highestStreaks'] ?? highestStreaks);
        gameHistory =
            List<Map<String, dynamic>>.from(data['gameHistory'] ?? []);
        complaints = Map<String, int>.from(data['complaints'] ?? complaints);
        achievements =
            (data['achievements'] as Map<dynamic, dynamic>? ?? {}).map(
          (k, v) => MapEntry(
              k.toString(), Set<String>.from(v.map((item) => item.toString()))),
        );
        dailyRatings =
            Map<String, dynamic>.from(data['dailyRatings'] ?? {}).map(
          (k, v) => MapEntry(
            k,
            Map<String, dynamic>.from(v).map(
              (innerKey, innerValue) => MapEntry(
                innerKey,
                (innerValue as List<dynamic>).map((e) => e as int).toList(),
              ),
            ),
          ),
        );
        allTimeRatings =
            Map<String, dynamic>.from(data['allTimeRatings'] ?? {}).map(
          (k, v) => MapEntry(
            k,
            Map<String, dynamic>.from(v).map(
              (innerKey, innerValue) => MapEntry(
                innerKey,
                (innerValue as List<dynamic>).map((e) => e as int).toList(),
              ),
            ),
          ),
        );
        peacockQueue = List<String>.from(data['peacockQueue'] ?? []);
        var rawPeacockTimers = data['peacockTimers'] ?? {};
        peacockTimers = {};
        if (rawPeacockTimers is Map) {
          rawPeacockTimers.forEach((key, value) {
            if (value is Map) {
              peacockTimers[key.toString()] = Map<String, dynamic>.from(value);
            }
          });
        }
        typing = Map<String, bool>.from(data['typing'] ?? typing);
        preferredModes =
            Map<String, String?>.from(data['preferredModes'] ?? preferredModes);
        userBlocks = (data['userBlocks'] as Map<dynamic, dynamic>? ?? {}).map(
          (k, v) => MapEntry(k.toString(), Map<String, bool>.from(v)),
        );

        // Merge availableGames from Firestore with default games
        var firestoreGames =
            List<Map<String, dynamic>>.from(data['availableGames'] ?? []);
        if (firestoreGames.isNotEmpty) {
          // Use Firestore games but ensure they have required fields
          availableGames = firestoreGames
              .map((game) => {
                    'name': game['name'] ?? 'Unknown Game',
                    'maxSpots': game['maxSpots'] ?? 4,
                    'description': game['description'] ?? 'Custom Game',
                    'logo': game['logo'] ?? 'assets/images/placeholder.png'
                  })
              .toList();
        } else {
          // Use default games if no Firestore data
          availableGames = [
            {
              'name': 'Warzone',
              'maxSpots': 4,
              'description': 'Call of Duty: Warzone - Battle Royale',
              'logo': 'assets/images/placeholder.png'
            },
            {
              'name': 'Modern Warfare III',
              'maxSpots': 4,
              'description': 'Call of Duty: Modern Warfare III - Multiplayer',
              'logo': 'assets/images/placeholder.png'
            },
            {
              'name': 'Fortnite',
              'maxSpots': 4,
              'description': 'Fortnite - Battle Royale',
              'logo': 'assets/images/placeholder.png'
            },
            {
              'name': 'Apex Legends',
              'maxSpots': 3,
              'description': 'Apex Legends - Battle Royale',
              'logo': 'assets/images/placeholder.png'
            },
            {
              'name': 'Valorant',
              'maxSpots': 5,
              'description': 'Valorant - Tactical FPS',
              'logo': 'assets/images/placeholder.png'
            },
            {
              'name': 'Overwatch 2',
              'maxSpots': 5,
              'description': 'Overwatch 2 - Hero Shooter',
              'logo': 'assets/images/placeholder.png'
            },
            {
              'name': 'Rocket League',
              'maxSpots': 3,
              'description': 'Rocket League - Sports Action',
              'logo': 'assets/images/placeholder.png'
            },
            {
              'name': 'Minecraft',
              'maxSpots': 4,
              'description': 'Minecraft - Survival/Creative',
              'logo': 'assets/images/placeholder.png'
            },
          ];
        }

        // Now set currentGame and validate it against availableGames
        var firestoreCurrentGame = data['currentGame'];

        // Only use firestore currentGame if it matches an available game
        if (firestoreCurrentGame != null &&
            availableGames.any((game) =>
                game['name'] == firestoreCurrentGame['name'] &&
                game['maxSpots'] == firestoreCurrentGame['maxSpots'])) {
          _currentGame = firestoreCurrentGame;
        } else {
          // Firestore currentGame is invalid or null, keep existing currentGame or set to first available
          if (_currentGame == null && availableGames.isNotEmpty) {
            _currentGame = availableGames.first;
          }
        }

        // Ensure current game has initialized spots
        if (_currentGame != null) {
          final gameName = _currentGame!['name'];
          if (!gameSquadSpots.containsKey(gameName)) {
            gameSquadSpots[gameName] =
                List.filled(_currentGame!['maxSpots'], null);
            gameSpotTimers[gameName] =
                List.filled(_currentGame!['maxSpots'], null);
          }
        }

        preferredPeacockGames =
            Set<String>.from(data['preferredPeacockGames'] ?? []);
        _changedFields.clear();
        notifyListeners();
      } else {
        debugPrint("Firestore snapshot does not exist");
      }
    });

    _firestore.collection('schedules').snapshots().listen((snapshot) {
      scheduledTimes = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      // Check for new availability with null safety
      bool newAvailability = scheduledTimes.any((time) =>
          time['timestamp'] != null &&
          DateTime.tryParse(time['timestamp'] ?? '') != null &&
          DateTime.parse(time['timestamp']).isAfter(_lastFirestoreUpdate));
      if (newAvailability) {
        _hasNewAvailability = true;
        NotificationService.sendNotification(
            'New Availability', 'A new schedule has been added!');
      }
      debugPrint('Synced scheduledTimes from schedules: $scheduledTimes');
      notifyListeners();
    });

    _firestore.collection('users').snapshots().listen((snapshot) {
      for (var doc in snapshot.docs) {
        String? displayName = doc.data()['displayName'] as String?;
        if (displayName != null && squadMembers.contains(displayName)) {
          memberProfileImages[displayName] =
              doc.data()['profileImage'] as String?;
          preferredModes[displayName] = doc.data()['preferredMode'] as String?;
        }
        final user = FirebaseAuth.instance.currentUser;
        if (user != null && doc.id == user.uid) {
          _displayName = doc.data()['displayName'] ?? _displayName;
          _profileImage = doc.data()['profileImage'] ?? _profileImage;

          // Save to SharedPreferences for backup
          if (_displayName != null && _displayName != 'User') {
            SharedPreferences.getInstance().then((prefs) {
              prefs.setString('yourName', _displayName!);
            });
          }
        }
      }
      notifyListeners();
    });

    _firestore.collection('chat').snapshots().listen((snapshot) {
      bool hasNew = snapshot.docChanges.any((change) =>
          change.type == DocumentChangeType.added &&
          (change.doc.data()?['read'] ?? true) == false &&
          change.doc.data()?['sender_name'] != null &&
          change.doc.data()?['content'] != null);
      if (hasNew) {
        _hasUnreadMessages = true;
        NotificationService.sendNotification(
            'New Message', 'You have an unread message in the chat!');
      }
      notifyListeners();
    });

    // Listen to lobbies subcollections for all games
    for (final game in availableGames) {
      final gameName = game['name'] as String;
      _firestore
          .collection('lobbies')
          .doc(gameName)
          .collection('lobbies')
          .snapshots()
          .listen((snapshot) {
        gameLobbies[gameName] = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
        notifyListeners();
      });
    }
  }

  void _markFieldChanged(String field) {
    _changedFields.add(field);
  }

  Future<void> updateFirestoreAsync({bool force = false}) async {
    final now = DateTime.now();
    if (force ||
        now.difference(_lastFirestoreUpdate).inSeconds >=
            _firestoreUpdateInterval) {
      final data = <String, dynamic>{};
      if (_changedFields.contains('squadSpots') || force) {
        // Only save non-empty game data
        final filteredSquadSpots = Map<String, dynamic>.fromEntries(
            gameSquadSpots.entries.where((entry) => entry.value.isNotEmpty));
        if (filteredSquadSpots.isNotEmpty) {
          data['gameSquadSpots'] = filteredSquadSpots;
        }
      }
      if (_changedFields.contains('spotTimers') || force) {
        // Only save non-empty timer data
        final filteredSpotTimers = Map<String, dynamic>.fromEntries(
            gameSpotTimers.entries
                .where((entry) => entry.value.any((timer) => timer != null)));
        if (filteredSpotTimers.isNotEmpty) {
          data['gameSpotTimers'] = filteredSpotTimers;
        }
      }
      if (_changedFields.contains('statuses') || force) {
        // Only save non-empty status data
        final filteredStatuses = Map<String, dynamic>.fromEntries(
            gameStatuses.entries.where((entry) => entry.value.isNotEmpty));
        if (filteredStatuses.isNotEmpty) {
          data['gameStatuses'] = filteredStatuses;
        }
      }
      if (_changedFields.contains('globalStatuses') || force) {
        final filteredGlobalStatuses = Map<String, String>.fromEntries(
            globalStatuses.entries.where((entry) => entry.key.isNotEmpty));
        if (filteredGlobalStatuses.isNotEmpty) {
          data['globalStatuses'] = filteredGlobalStatuses;
        }
      }
      if (_changedFields.contains('currentStreaks') || force) {
        data['currentStreaks'] = currentStreaks;
      }
      if (_changedFields.contains('highestStreaks') || force) {
        data['highestStreaks'] = highestStreaks;
      }
      if (_changedFields.contains('gameHistory') || force) {
        data['gameHistory'] = gameHistory;
      }
      if (_changedFields.contains('complaints') || force) {
        data['complaints'] = complaints;
      }
      if (_changedFields.contains('achievements') || force) {
        data['achievements'] =
            achievements.map((k, v) => MapEntry(k, v.toList()));
      }
      if (_changedFields.contains('dailyRatings') || force) {
        data['dailyRatings'] = dailyRatings;
      }
      if (_changedFields.contains('allTimeRatings') || force) {
        data['allTimeRatings'] = allTimeRatings;
      }
      if (_changedFields.contains('peacockTimers') || force) {
        data['peacockTimers'] = peacockTimers;
      }
      if (_changedFields.contains('peacockQueue') || force) {
        data['peacockQueue'] = peacockQueue;
      }
      if (_changedFields.contains('members') || force) {
        data['members'] = squadMembers;
      }
      if (_changedFields.contains('typing') || force) data['typing'] = typing;
      if (_changedFields.contains('preferredModes') || force) {
        data['preferredModes'] = preferredModes;
      }
      if (_changedFields.contains('userBlocks') || force) {
        data['userBlocks'] = userBlocks;
      }
      if (_changedFields.contains('currentGame') || force) {
        data['currentGame'] = currentGame;
      }
      if (_changedFields.contains('availableGames') || force) {
        data['availableGames'] = availableGames;
      }
      if (_changedFields.contains('preferredPeacockGames') || force) {
        data['preferredPeacockGames'] = preferredPeacockGames.toList();
      }

      if (data.isNotEmpty) {
        try {
          await _firestore
              .collection('squad')
              .doc('state')
              .set(data, SetOptions(merge: true));
          debugPrint("Firestore updated with: $data");
          _changedFields.clear();
          _lastFirestoreUpdate = now;
        } catch (e) {
          debugPrint("Firestore update failed: $e");
        }
      }
    }
  }

  void updateFirestore({bool force = false}) {
    updateFirestoreAsync(force: force);
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
      _markFieldChanged('complaints');
      await updateFirestoreAsync(force: true);

      await NotificationService.sendNotificationToUser(
        recipientDisplayName: targetMember,
        title: 'New Complaint',
        body: 'You received a complaint: $reason ($category).',
      );

      debugPrint('Complaint submitted against $targetMember: $reason');
      notifyListeners();
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
    if (targetMember == submittedBy) {
      throw Exception('Cannot rate yourself');
    }

    bool canRate =
        await canRateMember(targetMember, submittedBy); // Updated here
    if (!canRate) {
      throw Exception(
          'You can only rate members you played with (Walking status).');
    }

    try {
      ratings.forEach((category, rating) {
        if (rating != null && rating >= 0 && rating <= 5) {
          dailyRatings[targetMember]![category]!.add(rating);
          allTimeRatings[targetMember]![category]!.add(rating);
        }
      });

      final latestGame = gameHistory.lastWhere(
        (game) =>
            (game['players'] as List).contains(targetMember) &&
            (game['players'] as List).contains(submittedBy),
        orElse: () => {},
      );
      if (latestGame.isNotEmpty) {
        latestGame['ratings'] ??= {};
        (latestGame['ratings'] as Map)[submittedBy] ??= {};
        (latestGame['ratings'] as Map)[submittedBy][targetMember] = ratings;
      }

      _markFieldChanged('dailyRatings');
      _markFieldChanged('allTimeRatings');
      _markFieldChanged('gameHistory');
      await updateFirestoreAsync(force: true);

      final ratedCategories = ratings.entries
          .where((e) => e.value != null)
          .map((e) => '${e.key}: ${e.value}/5')
          .join(', ');
      if (ratedCategories.isNotEmpty) {
        await NotificationService.sendNotificationToUser(
          recipientDisplayName: targetMember,
          title: 'New Rating',
          body: 'You were rated by $submittedBy: $ratedCategories.',
        );
      }

      debugPrint('Ratings submitted for $targetMember: $ratings');
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to submit ratings: $e');
      rethrow;
    }
  }

  // Add this method to SquadState
  Future<bool> hasRatedMember(String targetMember, String submittedBy) async {
    final sharedGames = gameHistory
        .where((game) =>
            (game['players'] as List).contains(targetMember) &&
            (game['players'] as List).contains(submittedBy) &&
            (game['result'] == 'Win' || game['result'] == 'Loss'))
        .toList();
    if (sharedGames.isEmpty) return false;
    final latestGame = sharedGames.last;
    final ratings = latestGame['ratings'] as Map? ?? {};
    final submittedRatings = ratings[submittedBy] as Map? ?? {};
    return submittedRatings.containsKey(targetMember);
  }

  // Existing canRateMember (ensure public)
  Future<bool> canRateMember(String targetMember, String submittedBy) async {
    return gameHistory.any((game) =>
        (game['players'] as List).contains(targetMember) &&
        (game['players'] as List).contains(submittedBy) &&
        (game['result'] == 'Win' || game['result'] == 'Loss'));
  }

  /// Gets average rating for a member in a category
  double getAverageRating(String member, String category,
      {bool daily = false}) {
    final ratings = daily
        ? dailyRatings[member]![category]!
        : allTimeRatings[member]![category]!;
    if (ratings.isEmpty) return 0.0;
    return ratings.reduce((a, b) => a + b) / ratings.length;
  }

  /// Gets all ratings for a member as a map for display
  Map<String, double> getMemberRatings(String member, {bool daily = false}) {
    return {
      'Vibes': getAverageRating(member, 'Vibes', daily: daily),
      'Comms': getAverageRating(member, 'Comms', daily: daily),
      'Gunny': getAverageRating(member, 'Gunny', daily: daily),
      'Wingman': getAverageRating(member, 'Wingman', daily: daily),
    };
  }

  // New methods for tilt and notifications
  void updateTiltEnabled(bool value) {
    _tiltEnabled = value;
    notifyListeners();
  }

  void setNewAvailability(bool value) {
    _hasNewAvailability = value;
    notifyListeners();
  }

  void setNewSquadSpot(bool value) {
    _hasNewSquadSpot = value;
    if (value) {
      NotificationService.sendNotification(
          'New Squad Spot', 'A spot has been claimed or opened!');
    }
    notifyListeners();
  }

  void setUnreadMessages(bool value) {
    _hasUnreadMessages = value;
    notifyListeners();
  }

  void clearNotifications(int tabIndex) {
    if (tabIndex == 1) _hasNewAvailability = false;
    if (tabIndex == 2) _hasNewSquadSpot = false;
    if (tabIndex == 3) _hasUnreadMessages = false;
    notifyListeners();
  }

  void setReplyingTo(DocumentSnapshot? message) {
    _replyingTo = message;
    notifyListeners();
  }

  void clearReplyingTo() {
    _replyingTo = null;
    notifyListeners();
  }

  Future<void> sendReply(String messageId, String text) async {
    if (_replyingTo == null) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw 'No user logged in';

      await _firestore.collection('chat').add({
        'text': text,
        'sender': user.displayName ?? _displayName ?? 'User',
        'timestamp': FieldValue.serverTimestamp(),
        'replyTo': messageId,
        'delivered': false,
        'read': false,
      });

      clearReplyingTo();
      debugPrint('Reply sent to message $messageId: $text');
    } catch (e) {
      debugPrint('Failed to send reply: $e');
      rethrow;
    }
  }

  Future<void> deleteMessage(String messageId) async {
    try {
      await _firestore.collection('chat').doc(messageId).delete();
      debugPrint('Message $messageId deleted');
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to delete message: $e');
      rethrow;
    }
  }

  void updatePreferredMode(String user, String? mode) {
    preferredModes[user] = mode;
    _markFieldChanged('preferredModes');
    updateFirestore(force: true);
    notifyListeners();
  }

  void blockUser(String user) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    userBlocks[uid] ??= {};
    userBlocks[uid]![user] = true;
    _markFieldChanged('userBlocks');
    updateFirestore(force: true);
    notifyListeners();
  }

  void unblockUser(String user) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    userBlocks[uid]?.remove(user);
    _markFieldChanged('userBlocks');
    updateFirestore(force: true);
    notifyListeners();
  }

  void updateProfileImage(String url) {
    _profileImage = url;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _firestore
          .collection('users')
          .doc(user.uid)
          .set({'profileImage': url}, SetOptions(merge: true));
    }
    notifyListeners();
  }

  void updateDisplayName(String name) {
    _displayName = name;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _firestore
          .collection('users')
          .doc(user.uid)
          .set({'displayName': name}, SetOptions(merge: true));
    }
    // Also save to SharedPreferences for persistence
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('yourName', name);
    });
    notifyListeners();
  }

  Future<void> removeFromPeacock(String player) async {
    if (peacockTimers.containsKey(player)) {
      peacockTimers.remove(player);
      statuses[player] = 'Offline';
      _markFieldChanged('peacockTimers');
      _markFieldChanged('statuses');
    } else if (peacockQueue.contains(player)) {
      peacockQueue.remove(player);
      statuses[player] = 'Offline';
      _markFieldChanged('peacockQueue');
      _markFieldChanged('statuses');
    }
    await updateFirestoreAsync(force: true);
    notifyListeners();
  }

  void claimSpot(int index) {
    final userName = displayName;
    if (userName != null &&
        userName != 'User' &&
        !squadSpots.contains(userName)) {
      squadSpots[index] = userName;
      spotTimers[index] = {
        'startTime': DateTime.now().millisecondsSinceEpoch,
        'duration': 300,
      };
      statuses[userName] = 'Ready';
      globalStatuses[userName] =
          'Ready'; // Set global status to Ready during timer
      if (peacockTimers.containsKey(userName)) {
        peacockTimers.remove(userName);
        _markFieldChanged('peacockTimers');
      } else if (peacockQueue.contains(userName)) {
        peacockQueue.remove(userName);
        _markFieldChanged('peacockQueue');
      }
      _markFieldChanged('squadSpots');
      _markFieldChanged('spotTimers');
      _markFieldChanged('statuses');
      _markFieldChanged('globalStatuses');
      setNewSquadSpot(true); // Trigger squad spot notification
      updateFirestore(force: true);
      notifyListeners();
    }
  }

  void startPeacockTimer(BuildContext dialogContext) {
    final userName = displayName;
    if (userName != null &&
        userName != 'User' &&
        !squadSpots.contains(userName) &&
        !peacockTimers.containsKey(userName) &&
        !peacockQueue.contains(userName)) {
      if (peacockTimers.length < 4) {
        peacockTimers[userName] = {
          'startTime': DateTime.now().millisecondsSinceEpoch,
          'duration': 3600,
          'mode': 'Quads'
        };
        statuses[userName] = 'Strutting';
        _markFieldChanged('peacockTimers');
        _markFieldChanged('statuses');
      } else {
        peacockQueue.add(userName);
        statuses[userName] = 'Waiting';
        _markFieldChanged('peacockQueue');
        _markFieldChanged('statuses');
      }
      updateFirestore(force: true);
      notifyListeners();
    } else if (userName != null &&
        userName != 'User' &&
        squadSpots.contains(userName)) {
      int spotIndex = squadSpots.indexOf(userName);
      if (spotIndex != -1) {
        squadSpots[spotIndex] = null;
        spotTimers[spotIndex] = null;
        if (peacockTimers.length < 4) {
          peacockTimers[userName] = {
            'startTime': DateTime.now().millisecondsSinceEpoch,
            'duration': 3600,
            'mode': 'Quads'
          };
          statuses[userName] = 'Strutting';
          _markFieldChanged('peacockTimers');
        } else {
          peacockQueue.add(userName);
          statuses[userName] = 'Waiting';
          _markFieldChanged('peacockQueue');
        }
        _markFieldChanged('squadSpots');
        _markFieldChanged('spotTimers');
        _markFieldChanged('statuses');
        setNewSquadSpot(true); // Trigger squad spot notification
        updateFirestore(force: true);
        notifyListeners();
      }
    }
  }

  void _checkPreferredModes() {
    int claimedCount = squadSpots.where((spot) => spot != null).length;
    int availableSpots = 4 - claimedCount;
    if (availableSpots == 0 || peacockQueue.isEmpty) return;

    List<String> potentialPlayers =
        squadSpots.where((spot) => spot != null).cast<String>().toList();
    Map<String, List<String>> modeGroups = {
      'duos': [],
      'trios': [],
      'quads': []
    };

    for (var player in peacockQueue) {
      String? mode = preferredModes[player];
      if (mode != null) {
        modeGroups[mode]?.add(player);
        potentialPlayers.add(player);
      }
    }

    for (var player in List.from(peacockQueue)) {
      String? mode = preferredModes[player];
      if (mode == null) continue;

      int requiredPlayers = mode == 'duos'
          ? 2
          : mode == 'trios'
              ? 3
              : 4;
      int currentPlayers = potentialPlayers.length;

      if (currentPlayers >= requiredPlayers && availableSpots > 0) {
        int spotsToFill =
            (requiredPlayers - claimedCount).clamp(1, availableSpots);
        _fillSpots([player], spotsToFill);
        potentialPlayers.remove(player);
      }
    }
  }

  void _fillSpots(List<String> players, int spotsNeeded) {
    for (var player in players) {
      int? freeSpot = squadSpots.indexOf(null);
      if (freeSpot != -1) {
        squadSpots[freeSpot] = player;
        spotTimers[freeSpot] = {
          'startTime': DateTime.now().millisecondsSinceEpoch,
          'duration': 300,
        };
        statuses[player] = 'Ready';
        peacockQueue.remove(player);
        _markFieldChanged('squadSpots');
        _markFieldChanged('spotTimers');
        _markFieldChanged('statuses');
        _markFieldChanged('peacockQueue');
        setNewSquadSpot(true); // Trigger squad spot notification
      }
    }
    updateFirestore(force: true);
    notifyListeners();
  }

  void updateTypingStatus(String user, bool isTyping) {
    if (typing[user] != isTyping) {
      typing[user] = isTyping;
      _markFieldChanged('typing');
      updateFirestore(force: true);
      notifyListeners();
    }
  }

  String? getTypingUser() {
    return typing.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .firstOrNull;
  }

  void assignSpot(int index, String player) {
    squadSpots[index] = player;
    spotTimers[index] = {
      'startTime': DateTime.now().millisecondsSinceEpoch,
      'duration': 300,
    };
    statuses[player] = 'Ready';
    globalStatuses[player] = 'Ready'; // Set global status to Ready during timer
    if (peacockTimers.containsKey(player)) {
      peacockTimers.remove(player);
      _markFieldChanged('peacockTimers');
    } else if (peacockQueue.contains(player)) {
      peacockQueue.remove(player);
      _markFieldChanged('peacockQueue');
    }
    _markFieldChanged('squadSpots');
    _markFieldChanged('spotTimers');
    _markFieldChanged('statuses');
    _markFieldChanged('globalStatuses');
    setNewSquadSpot(true); // Trigger squad spot notification
    updateFirestore(force: true);
    notifyListeners();
  }

  void removeSpot(int index) {
    String? player = squadSpots[index];
    if (player != null) {
      squadSpots[index] = null;
      spotTimers[index] = null;
      if (peacockTimers.containsKey(player)) {
        globalStatuses[player] = 'Strutting';
      } else if (peacockQueue.contains(player)) {
        globalStatuses[player] = 'Waiting';
      } else {
        globalStatuses[player] = 'Offline';
      }
      _markFieldChanged('globalStatuses');
      _markFieldChanged('squadSpots');
      _markFieldChanged('spotTimers');
      _markFieldChanged('statuses');
      updateFirestore(force: true);
      notifyListeners();
    }
  }

  void lockSpot(int index) {
    if (spotTimers[index] != null) {
      spotTimers[index] = null;
      globalStatuses[squadSpots[index]!] = 'Walking';
      _markFieldChanged('globalStatuses');
      _markFieldChanged('spotTimers');
      _markFieldChanged('statuses');
      updateFirestore(force: true);
      notifyListeners();
    }
  }

  Future<void> recordWin() async {
    List<String> walkingPlayers = squadSpots
        .where((spot) => spot != null && statuses[spot] == 'Walking')
        .cast<String>()
        .toList();
    Map<String, int> updatedStreaks = {};
    for (var player in walkingPlayers) {
      int oldStreak = currentStreaks[player] ?? 0;
      updatedStreaks[player] = oldStreak + 1;
      await _checkAchievements(player, updatedStreaks[player]!);
    }
    currentStreaks.addAll(updatedStreaks);
    gameHistory.add({
      'result': 'Win',
      'players': walkingPlayers,
      'timestamp': DateTime.now().toIso8601String(),
      'ratings': {}, // Fresh ratings map for this game
    });
    await _audioPlayer.setAsset('sounds/victory.mp3');
    await _audioPlayer.play();
    NotificationService.sendNotification(
        'Squad Win!', '${walkingPlayers.join(', ')} won a game!');
    _markFieldChanged('currentStreaks');
    _markFieldChanged('gameHistory');
    _markFieldChanged('achievements');
    updateFirestore(force: true);
    notifyListeners();
  }

  void recordLoss() {
    List<String> walkingPlayers = squadSpots
        .where((spot) =>
            spot != null && spotTimers[squadSpots.indexOf(spot)] == null)
        .cast<String>()
        .toList();
    for (var player in walkingPlayers) {
      currentStreaks[player] = 0;
    }
    gameHistory.add({
      'result': 'Loss',
      'players': walkingPlayers,
      'timestamp': DateTime.now().toIso8601String(),
      'ratings': {}, // Fresh ratings map for this game
    });
    _markFieldChanged('currentStreaks');
    _markFieldChanged('gameHistory');
    updateFirestore(force: true);
    notifyListeners();
  }

  void clearAllSpots() {
    final currentGameName = _currentGame?['name'] ?? 'Warzone';
    final maxSpots = _currentGame?['maxSpots'] ?? 4;
    gameSquadSpots[currentGameName] = List.filled(maxSpots, null);
    gameSpotTimers[currentGameName] = List.filled(maxSpots, null);
    peacockTimers.clear();
    peacockQueue.clear();
    for (var member in squadMembers) {
      if (gameStatuses[currentGameName]?[member] == 'Strutting' ||
          gameStatuses[currentGameName]?[member] == 'Walking') {
        gameStatuses[currentGameName]?[member] = 'Ready';
      } else {
        gameStatuses[currentGameName]?[member] = 'Offline';
      }
    }
    _markFieldChanged('squadSpots');
    _markFieldChanged('spotTimers');
    _markFieldChanged('peacockTimers');
    _markFieldChanged('peacockQueue');
    _markFieldChanged('statuses');
    updateFirestore(force: true);
    notifyListeners();
  }

  void resetTimers() {
    for (int i = 0; i < spotTimers.length; i++) {
      if (spotTimers[i] != null && squadSpots[i] != null) {
        spotTimers[i] = {
          'startTime': DateTime.now().millisecondsSinceEpoch,
          'duration': 300,
        };
      }
    }
    peacockTimers.forEach((player, timer) {
      if (timer != null) {
        timer['startTime'] = DateTime.now().millisecondsSinceEpoch;
        timer['duration'] = 3600;
      }
    });
    _markFieldChanged('spotTimers');
    _markFieldChanged('peacockTimers');
    notifyListeners();
  }

  void reupPeacock() {
    if (_displayName != null) {
      peacockTimers[_displayName!] = peacockTimers[_displayName!] != null
          ? {
              'startTime': DateTime.now().millisecondsSinceEpoch,
              'duration': 3600,
              'mode': peacockTimers[_displayName!]!['mode'] as String
            }
          : {
              'startTime': DateTime.now().millisecondsSinceEpoch,
              'duration': 3600,
              'mode': 'Quads'
            };
      statuses[_displayName!] = 'Strutting';
      _markFieldChanged('peacockTimers');
      _markFieldChanged('statuses');
      updateFirestore(force: true);
      notifyListeners();
    }
  }

  void claimPeacockDialog() {
    showDialog(
      context: context!,
      builder: (context) => AlertDialog(
        title: const Text('Assign Peacock',
            style: TextStyle(color: Colors.cyanAccent)),
        content: SingleChildScrollView(
          child: Column(
            children: squadMembers
                .where((player) =>
                    !peacockTimers.containsKey(player) &&
                    !peacockQueue.contains(player) &&
                    !squadSpots.contains(player))
                .map((player) => ListTile(
                      title: Text(player),
                      onTap: () {
                        if (peacockTimers.length < 4) {
                          peacockTimers[player] = {
                            'startTime': DateTime.now().millisecondsSinceEpoch,
                            'duration': 3600,
                            'mode': 'Quads'
                          };
                          statuses[player] = 'Strutting';
                          _markFieldChanged('peacockTimers');
                        } else {
                          peacockQueue.add(player);
                          statuses[player] = 'Waiting';
                          _markFieldChanged('peacockQueue');
                        }
                        _markFieldChanged('statuses');
                        updateFirestore(force: true);
                        notifyListeners();
                        Navigator.pop(context);
                      },
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'))
        ],
      ),
    );
  }

  void managePeacock() {
    showDialog(
      context: context!,
      builder: (context) => AlertDialog(
        title: const Text('Manage Peacock Queue',
            style: TextStyle(color: Colors.cyanAccent)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...peacockTimers.entries.map((entry) {
                  int startTime = entry.value!['startTime'] as int;
                  int duration = entry.value!['duration'] as int;
                  int remaining = duration -
                      ((DateTime.now().millisecondsSinceEpoch - startTime) /
                              1000)
                          .floor();
                  return ListTile(
                    title: Text(
                        '${entry.key} (Active: ${_formatTimer(remaining > 0 ? remaining : 0)})'),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle,
                          color: Colors.redAccent),
                      onPressed: () async {
                        await removeFromPeacock(entry.key);
                        Navigator.pop(context);
                        managePeacock();
                      },
                    ),
                  );
                }),
                ...peacockQueue.map((player) => ListTile(
                      title: Text('$player (Waiting)'),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle,
                            color: Colors.redAccent),
                        onPressed: () async {
                          await removeFromPeacock(player);
                          Navigator.pop(context);
                          managePeacock();
                        },
                      ),
                    )),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'))
        ],
      ),
    );
  }

  void addBan(String player, String voter) {
    bans[player] ??= [];
    if (bans[player]!.any((ban) => ban['voter'] == voter)) return;
    bans[player]!.add(
        {'voter': voter, 'timestamp': DateTime.now().millisecondsSinceEpoch});
    _markFieldChanged('bans');
    notifyListeners();
    _startBanTimer(player);
  }

  void _startBanTimer(String player) async {
    await Future.delayed(const Duration(hours: 4));
    if (bans[player] != null) {
      bans[player]!.removeWhere((ban) =>
          DateTime.now().millisecondsSinceEpoch - ban['timestamp'] >=
          4 * 3600 * 1000);
      if (bans[player]!.isEmpty) bans.remove(player);
      _markFieldChanged('bans');
      notifyListeners();
    }
  }

  int getBanCount(String player) => bans[player]?.length ?? 0;
  bool isBanned(String player) => getBanCount(player) >= 5;
  int getBanDuration(String player) {
    final count = getBanCount(player);
    if (count >= 7) return 48 * 3600 * 1000;
    if (count >= 5) return 24 * 3600 * 1000;
    return 0;
  }

  // Get the game name where a player has claimed a spot
  String? getPlayerGame(String player) {
    for (final gameName in gameSquadSpots.keys) {
      if (gameSquadSpots[gameName]?.contains(player) ?? false) {
        return gameName;
      }
    }
    return null;
  }

  void updateSpotTimers() {
    bool changed = false;
    for (int i = 0; i < spotTimers.length; i++) {
      if (spotTimers[i] != null) {
        int startTime = spotTimers[i]!['startTime'] as int;
        int duration = spotTimers[i]!['duration'] as int;
        int elapsed =
            ((DateTime.now().millisecondsSinceEpoch - startTime) / 1000)
                .floor();
        int remaining = duration - elapsed;
        if (remaining <= 0) {
          removeSpot(i);
          _assignNextFromQueue();
          changed = true;
        }
      }
    }
    if (changed) {
      updateFirestore(force: true);
    } else {
      updateFirestore();
    }
  }

  void updatePeacockTimers() {
    bool changed = false;
    peacockTimers.forEach((player, timer) {
      if (timer != null) {
        int startTime = timer['startTime'] as int;
        int duration = timer['duration'] as int;
        int elapsed =
            ((DateTime.now().millisecondsSinceEpoch - startTime) / 1000)
                .floor();
        int remaining = duration - elapsed;
        if (remaining <= 0) {
          peacockTimers[player] = null;
          statuses[player] = 'Ready';
          _markFieldChanged('peacockTimers');
          _markFieldChanged('statuses');
          _assignNextFromQueue();
          changed = true;
        }
      }
    });
    peacockTimers.removeWhere((key, value) => value == null);
    if (changed) {
      updateFirestore(force: true);
    } else {
      updateFirestore();
    }
  }

  String getPeacockTimerDisplay(String player) {
    final timer = peacockTimers[player];
    if (timer == null) return '00:00';
    int startTime = timer['startTime'] as int;
    int duration = timer['duration'] as int;
    int remaining = duration -
        ((DateTime.now().millisecondsSinceEpoch - startTime) / 1000).floor();
    return _formatTimer(remaining > 0 ? remaining : 0);
  }

  String getSpotTimerDisplay(int index) {
    if (spotTimers[index] == null) return '00:00';
    int startTime = spotTimers[index]!['startTime'] as int;
    int duration = spotTimers[index]!['duration'] as int;
    int remaining = duration -
        ((DateTime.now().millisecondsSinceEpoch - startTime) / 1000).floor();
    return _formatTimer(remaining > 0 ? remaining : 0);
  }

  String _formatTimer(int? seconds) {
    if (seconds == null) return '00:00';
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _assignNextFromQueue() {
    int struttingCount =
        peacockTimers.values.where((timer) => timer != null).length;
    int waitingCount = peacockQueue.length;
    int availableSpots = squadSpots.where((spot) => spot == null).length;

    if (availableSpots > 0 && (struttingCount > 0 || waitingCount > 0)) {
      if (struttingCount > 0) {
        List<String> struttingPlayers = peacockTimers.keys
            .where((player) => peacockTimers[player] != null)
            .toList();
        for (String player in struttingPlayers) {
          int? freeSpot = squadSpots.indexOf(null);
          if (freeSpot != -1) {
            squadSpots[freeSpot] = player;
            spotTimers[freeSpot] = {
              'startTime': DateTime.now().millisecondsSinceEpoch,
              'duration': 300,
            };
            statuses[player] = 'Ready';
            peacockTimers.remove(player);
            _markFieldChanged('squadSpots');
            _markFieldChanged('spotTimers');
            _markFieldChanged('statuses');
            _markFieldChanged('peacockTimers');
            setNewSquadSpot(true); // Trigger squad spot notification
          }
        }
      } else if (waitingCount > 0) {
        for (int i = 0; i < waitingCount && squadSpots.contains(null); i++) {
          int? freeSpot = squadSpots.indexOf(null);
          if (freeSpot != -1 && peacockQueue.isNotEmpty) {
            String nextPlayer = peacockQueue.removeAt(0);
            if (!squadSpots.contains(nextPlayer) &&
                !peacockTimers.containsKey(nextPlayer)) {
              squadSpots[freeSpot] = nextPlayer;
              spotTimers[freeSpot] = {
                'startTime': DateTime.now().millisecondsSinceEpoch,
                'duration': 300,
              };
              statuses[nextPlayer] = 'Ready';
              _markFieldChanged('squadSpots');
              _markFieldChanged('spotTimers');
              _markFieldChanged('statuses');
              _markFieldChanged('peacockQueue');
              setNewSquadSpot(true); // Trigger squad spot notification
            }
          }
        }
      }
      updateFirestore(force: true);
      notifyListeners();
    }
  }

  Future<void> _checkAchievements(String player, int streak) async {
    achievements[player] ??= {};
    bool added = false;
    if (streak >= 10) {
      achievements[player]!.add('Chicken');
      await _audioPlayer.setAsset('sounds/turducken.wav');
      await _audioPlayer.play();
      added = true;
    }
    if (streak >= 4 && !added) {
      achievements[player]!.add('Duck');
      await _audioPlayer.setAsset('sounds/duck.mp3');
      await _audioPlayer.play();
      added = true;
    }
    if (streak >= 3 && !added) {
      achievements[player]!.add('Turkey');
      await _audioPlayer.setAsset('sounds/turkey.wav');
      await _audioPlayer.play();
    }
    _markFieldChanged('achievements');
  }

  void addToPeacock(String player) {
    final spotIndex = squadSpots.indexOf(player);
    if (spotIndex != -1) {
      squadSpots[spotIndex] = null;
      spotTimers[spotIndex] = null;
      statuses[player] = 'Offline';
      _markFieldChanged('squadSpots');
      _markFieldChanged('spotTimers');
      _markFieldChanged('statuses');
    }

    if (!peacockTimers.containsKey(player) && !peacockQueue.contains(player)) {
      if (peacockTimers.length < 4) {
        peacockTimers[player] = {
          'startTime': DateTime.now().millisecondsSinceEpoch,
          'duration': 3600,
          'mode': 'Quads'
        };
        statuses[player] = 'Strutting';
        _markFieldChanged('peacockTimers');
      } else {
        peacockQueue.add(player);
        statuses[player] = 'Waiting';
        _markFieldChanged('peacockQueue');
      }
      _markFieldChanged('statuses');
      updateFirestore(force: true);
      notifyListeners();
    }
  }

  // Game selection and lobbies methods
  void selectGame(Map<String, dynamic> game) {
    _currentGame = game;
    // Reset spots to match new game size
    int newSize = game['maxSpots'] ?? 4;
    final gameName = game['name'];
    if (!gameSquadSpots.containsKey(gameName) ||
        gameSquadSpots[gameName]!.length != newSize) {
      gameSquadSpots[gameName] = List.filled(newSize, null);
      gameSpotTimers[gameName] = List.filled(newSize, null);
      _markFieldChanged('squadSpots');
      _markFieldChanged('spotTimers');
    }
    updateFirestore(force: true);
    notifyListeners();
  }

  List<Map<String, dynamic>> getVisibleLobbies(String gameName) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final userBlocks = this.userBlocks[uid] ?? {};

    return gameLobbies[gameName]?.where((lobby) {
          final players = List<String>.from(lobby['players'] ?? []);
          // Filter out lobbies with blocked players
          return !players.any((player) =>
              userBlocks.containsKey(player) && userBlocks[player]!);
        }).toList() ??
        [];
  }

  void joinLobby(String lobbyId, String playerName) {
    // Find the lobby across all games
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

        // Update Firestore
        _firestore
            .collection('lobbies')
            .doc(targetGame)
            .collection('lobbies')
            .doc(lobbyId)
            .update({'players': players});

        notifyListeners();
      }
    }
  }

  void addGame(Map<String, dynamic> game) {
    if (!availableGames.any((g) => g['name'] == game['name'])) {
      availableGames.add(game);
      // Add to Firestore
      _firestore.collection('games').add(game);

      // Set up lobbies listener for the new game
      final gameName = game['name'] as String;
      _firestore
          .collection('lobbies')
          .doc(gameName)
          .collection('lobbies')
          .snapshots()
          .listen((snapshot) {
        gameLobbies[gameName] = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
        notifyListeners();
      });

      notifyListeners();
    }
  }

  void editGame(int index, Map<String, dynamic> updatedGame) {
    if (index >= 0 && index < availableGames.length) {
      availableGames[index] = updatedGame;
      // Save to Firestore
      _firestore.collection('games').doc(updatedGame['name']).set(updatedGame);
      notifyListeners();
    }
  }

  void deleteGame(int index) {
    if (index >= 0 && index < availableGames.length) {
      // Don't allow deleting if it's the current game
      if (availableGames[index]['name'] == _currentGame?['name']) {
        return;
      }
      availableGames.removeAt(index);
      notifyListeners();
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
    // This could be stored in user preferences or derived from history
    // For now, return null - can be extended later
    return null;
  }

  void addPreferredPeacockGame(String gameName) {
    preferredPeacockGames.add(gameName);
    updateFirestore(force: true);
    notifyListeners();
  }

  void removePreferredPeacockGame(String gameName) {
    preferredPeacockGames.remove(gameName);
    updateFirestore(force: true);
    notifyListeners();
  }
}
