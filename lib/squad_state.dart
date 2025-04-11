import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:audioplayers/audioplayers.dart';
import '../notification_service.dart';

class SquadState with ChangeNotifier {
  List<String?> squadSpots = List.filled(4, null);
  List<Map<String, dynamic>?> spotTimers = List.filled(4, null);
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
  Map<String, String> statuses = {};
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

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AudioPlayer _audioPlayer = AudioPlayer();
  static const int _firestoreUpdateInterval = 5;
  DateTime _lastFirestoreUpdate = DateTime.now();
  Set<String> _changedFields = {};
  Timer? _timer;

  BuildContext? context;
  String? _displayName;

  SquadState();

  String? get displayName => _displayName;
  String? get profileImage => _profileImage;

  Future<void> initialize(BuildContext ctx) async {
    context = ctx;
    await _initState();
    _initializeData();
    _syncWithFirestore();
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
      notifyListeners();
    }
  }

  void _initializeData() {
    for (var player in squadMembers) {
      statuses[player] = 'Offline';
      currentStreaks[player] = 0;
      highestStreaks[player] = 0;
      complaints[player] = 0;
      achievements[player] = {};
      dailyRatings[player] = {
        "Vibes": [],
        "Comms": [],
        "Gunny": [],
        "Wingman": []
      };
      allTimeRatings[player] = {
        "Vibes": [],
        "Comms": [],
        "Gunny": [],
        "Wingman": []
      };
      peacockTimers[player] = null;
      typing[player] = false;
      memberProfileImages[player] = null;
      preferredModes[player] = null;
    }
    statuses["Alex"] = "Walking";
    statuses["Spencer"] = "Walking";
  }

  void _syncWithFirestore() {
    _firestore.collection('squad').doc('state').snapshots().listen((snapshot) {
      if (snapshot.exists) {
        var data = snapshot.data()!;
        debugPrint("Raw Firestore data: ${data.toString()}");
        squadSpots = List<String?>.from(data['squadSpots'] ?? squadSpots);
        spotTimers =
            List<Map<String, dynamic>?>.from(data['spotTimers'] ?? spotTimers);
        squadMembers = List<String>.from(data['members'] ?? squadMembers);
        var firestoreStatuses =
            Map<String, String>.from(data['statuses'] ?? {});
        statuses = Map<String, String>.from(firestoreStatuses);
        for (var player in squadMembers) {
          if (!squadSpots.contains(player) &&
              !peacockTimers.containsKey(player) &&
              !peacockQueue.contains(player)) {
            statuses[player] = 'Offline';
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
      // Check for new availability
      bool newAvailability = scheduledTimes.any((time) =>
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
        }
      }
      notifyListeners();
    });

    _firestore.collection('chat').snapshots().listen((snapshot) {
      bool hasNew = snapshot.docChanges.any((change) =>
          change.type == DocumentChangeType.added &&
          change.doc.data()?['read'] == false);
      if (hasNew) {
        _hasUnreadMessages = true;
        NotificationService.sendNotification(
            'New Message', 'You have an unread message in the chat!');
      }
      notifyListeners();
    });
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
      if (_changedFields.contains('squadSpots') || force)
        data['squadSpots'] = squadSpots;
      if (_changedFields.contains('spotTimers') || force)
        data['spotTimers'] = spotTimers;
      if (_changedFields.contains('statuses') || force)
        data['statuses'] = statuses;
      if (_changedFields.contains('currentStreaks') || force)
        data['currentStreaks'] = currentStreaks;
      if (_changedFields.contains('highestStreaks') || force)
        data['highestStreaks'] = highestStreaks;
      if (_changedFields.contains('gameHistory') || force)
        data['gameHistory'] = gameHistory;
      if (_changedFields.contains('complaints') || force)
        data['complaints'] = complaints;
      if (_changedFields.contains('achievements') || force) {
        data['achievements'] =
            achievements.map((k, v) => MapEntry(k, v.toList()));
      }
      if (_changedFields.contains('dailyRatings') || force)
        data['dailyRatings'] = dailyRatings;
      if (_changedFields.contains('allTimeRatings') || force)
        data['allTimeRatings'] = allTimeRatings;
      if (_changedFields.contains('peacockTimers') || force)
        data['peacockTimers'] = peacockTimers;
      if (_changedFields.contains('peacockQueue') || force)
        data['peacockQueue'] = peacockQueue;
      if (_changedFields.contains('members') || force)
        data['members'] = squadMembers;
      if (_changedFields.contains('typing') || force) data['typing'] = typing;
      if (_changedFields.contains('preferredModes') || force)
        data['preferredModes'] = preferredModes;

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
    required String category, // e.g., Behavior, Inactivity, Toxicity
    required String submittedBy,
  }) async {
    if (!squadMembers.contains(targetMember)) {
      throw Exception('Invalid member: $targetMember');
    }

    try {
      // Store detailed complaint in Firestore subcollection
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

      // Increment complaint counter
      complaints[targetMember] = (complaints[targetMember] ?? 0) + 1;
      _markFieldChanged('complaints');
      await updateFirestoreAsync(force: true);

      // Notify all members (to be updated when NotificationService supports targeting)
      NotificationService.sendNotification(
        'New Complaint',
        'Complaint against $targetMember: $reason ($category).',
      );

      debugPrint('Complaint submitted against $targetMember: $reason');
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to submit complaint: $e');
      rethrow;
    }
  }

  /// Submits ratings for a member, restricted to those in Walking status during same game
  Future<void> submitRatings({
    required String targetMember,
    required Map<String, int?> ratings, // e.g., {'Vibes': 4, 'Comms': null}
    required String submittedBy,
  }) async {
    if (!squadMembers.contains(targetMember)) {
      throw Exception('Invalid member: $targetMember');
    }
    if (targetMember == submittedBy) {
      throw Exception('Cannot rate yourself');
    }

    // Validate that target was Walking in a shared game
    bool canRate = await _canRateMember(targetMember, submittedBy);
    if (!canRate) {
      throw Exception(
          'You can only rate members you played with (Walking status).');
    }

    try {
      // Update daily and all-time ratings
      ratings.forEach((category, rating) {
        if (rating != null && rating >= 0 && rating <= 5) {
          dailyRatings[targetMember]![category]!.add(rating);
          allTimeRatings[targetMember]![category]!.add(rating);
        }
      });

      // Find the latest game with both members and update its ratings
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

      // Notify all members (to be updated when NotificationService supports targeting)
      final ratedCategories = ratings.entries
          .where((e) => e.value != null)
          .map((e) => '${e.key}: ${e.value}/5')
          .join(', ');
      if (ratedCategories.isNotEmpty) {
        NotificationService.sendNotification(
          'New Rating',
          '$targetMember was rated by $submittedBy: $ratedCategories.',
        );
      }

      debugPrint('Ratings submitted for $targetMember: $ratings');
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to submit ratings: $e');
      rethrow;
    }
  }

  /// Checks if submitter can rate target based on shared Walking status in a game
  Future<bool> _canRateMember(String targetMember, String submittedBy) async {
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

  // Chat-related methods
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

  // Existing methods (unchanged unless noted)
  void updatePreferredMode(String user, String? mode) {
    preferredModes[user] = mode;
    _markFieldChanged('preferredModes');
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
    if (_displayName != null && !squadSpots.contains(_displayName)) {
      squadSpots[index] = _displayName;
      spotTimers[index] = {
        'startTime': DateTime.now().millisecondsSinceEpoch,
        'duration': 300,
      };
      statuses[_displayName!] = 'Ready';
      if (peacockTimers.containsKey(_displayName)) {
        peacockTimers.remove(_displayName);
        _markFieldChanged('peacockTimers');
      } else if (peacockQueue.contains(_displayName)) {
        peacockQueue.remove(_displayName);
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

  void startPeacockTimer(BuildContext dialogContext) {
    if (_displayName != null &&
        !squadSpots.contains(_displayName) &&
        !peacockTimers.containsKey(_displayName) &&
        !peacockQueue.contains(_displayName)) {
      if (peacockTimers.length < 4) {
        peacockTimers[_displayName!] = {
          'startTime': DateTime.now().millisecondsSinceEpoch,
          'duration': 3600,
          'mode': 'Quads'
        };
        statuses[_displayName!] = 'Strutting';
        _markFieldChanged('peacockTimers');
        _markFieldChanged('statuses');
      } else {
        peacockQueue.add(_displayName!);
        statuses[_displayName!] = 'Waiting';
        _markFieldChanged('peacockQueue');
        _markFieldChanged('statuses');
      }
      updateFirestore(force: true);
      notifyListeners();
    } else if (_displayName != null && squadSpots.contains(_displayName)) {
      int spotIndex = squadSpots.indexOf(_displayName);
      if (spotIndex != -1) {
        squadSpots[spotIndex] = null;
        spotTimers[spotIndex] = null;
        if (peacockTimers.length < 4) {
          peacockTimers[_displayName!] = {
            'startTime': DateTime.now().millisecondsSinceEpoch,
            'duration': 3600,
            'mode': 'Quads'
          };
          statuses[_displayName!] = 'Strutting';
          _markFieldChanged('peacockTimers');
        } else {
          peacockQueue.add(_displayName!);
          statuses[_displayName!] = 'Waiting';
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
        statuses[player] = 'Strutting';
      } else if (peacockQueue.contains(player)) {
        statuses[player] = 'Waiting';
      } else {
        statuses[player] = 'Offline';
      }
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
      statuses[squadSpots[index]!] = 'Walking';
      _markFieldChanged('spotTimers');
      _markFieldChanged('statuses');
      updateFirestore(force: true);
      notifyListeners();
    }
  }

  void recordWin() {
    List<String> walkingPlayers = squadSpots
        .where((spot) => spot != null && statuses[spot] == 'Walking')
        .cast<String>()
        .toList();
    Map<String, int> updatedStreaks = {};
    for (var player in walkingPlayers) {
      int oldStreak = currentStreaks[player] ?? 0;
      updatedStreaks[player] = oldStreak + 1;
      _checkAchievements(player, updatedStreaks[player]!);
    }
    currentStreaks.addAll(updatedStreaks);
    gameHistory.add({
      'result': 'Win',
      'players': walkingPlayers,
      'timestamp': DateTime.now().toIso8601String(),
      'ratings': {},
    });
    _audioPlayer.play(AssetSource('sounds/victory.mp3'));
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
      'ratings': {},
    });
    _markFieldChanged('currentStreaks');
    _markFieldChanged('gameHistory');
    updateFirestore(force: true);
    notifyListeners();
  }

  void clearAllSpots() {
    squadSpots = List.filled(4, null);
    spotTimers = List.filled(4, null);
    peacockTimers.clear();
    peacockQueue.clear();
    for (var member in squadMembers) {
      if (statuses[member] == 'Strutting' || statuses[member] == 'Walking') {
        statuses[member] = 'Ready';
      } else {
        statuses[member] = 'Offline';
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

  void _checkAchievements(String player, int streak) {
    achievements[player] ??= {};
    bool added = false;
    if (streak >= 10) {
      achievements[player]!.add('Chicken');
      _audioPlayer.play(AssetSource('sounds/turducken.wav'));
      added = true;
    }
    if (streak >= 4 && !added) {
      achievements[player]!.add('Duck');
      _audioPlayer.play(AssetSource('sounds/duck.mp3'));
      added = true;
    }
    if (streak >= 3 && !added) {
      achievements[player]!.add('Turkey');
      _audioPlayer.play(AssetSource('sounds/turkey.wav'));
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
}
