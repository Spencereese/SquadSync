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
  Map<String, String> statuses = {"Alex": "Walking", "Spencer": "Walking"};
  Map<String, int> currentStreaks = {};
  Map<String, int> highestStreaks = {};
  Map<String, Map<String, dynamic>?> peacockTimers = {};
  List<String> peacockQueue = [];
  List<Map<String, dynamic>> gameHistory = [];
  Map<String, int> complaints = {};
  Map<String, Set<String>> achievements = {};
  Map<String, Map<String, List<int>>> dailyRatings = {};
  Map<String, Map<String, List<int>>> allTimeRatings =
      {}; // Fixed: Changed [] to {}
  List<Map<String, dynamic>> scheduledTimes = [];
  Map<String, List<Map<String, dynamic>>> bans = {};
  Map<String, bool> typing = {};
  String? _profileImage;
  Map<String, String?> memberProfileImages = {};
  Map<String, String?> preferredModes = {};

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AudioPlayer _audioPlayer = AudioPlayer();
  static const int _firestoreUpdateInterval = 5;
  DateTime _lastFirestoreUpdate = DateTime.now();
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
      currentStreaks[player] ??= 0;
      highestStreaks[player] ??= 0;
      complaints[player] ??= 0;
      achievements[player] ??= {};
      dailyRatings[player] ??= {
        "Vibes": [],
        "Comms": [],
        "Gunny": [],
        "Wingman": []
      };
      allTimeRatings[player] ??= {
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
  }

  void _syncWithFirestore() {
    _firestore.collection('squad').doc('state').snapshots().listen((snapshot) {
      if (snapshot.exists) {
        var data = snapshot.data()!;
        squadSpots = List<String?>.from(data['squadSpots'] ?? squadSpots);
        spotTimers =
            List<Map<String, dynamic>?>.from(data['spotTimers'] ?? spotTimers);
        squadMembers = List<String>.from(data['members'] ?? squadMembers);
        statuses = Map<String, String>.from(data['statuses'] ?? statuses);
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
          (k, v) => MapEntry(k, Map<String, List<int>>.from(v)),
        );
        allTimeRatings =
            Map<String, dynamic>.from(data['allTimeRatings'] ?? {}).map(
          (k, v) => MapEntry(k, Map<String, List<int>>.from(v)),
        );
        peacockQueue = List<String>.from(data['peacockQueue'] ?? []);
        peacockTimers =
            Map<String, dynamic>.from(data['peacockTimers'] ?? {}).map(
          (k, v) => MapEntry(
            k,
            v != null && v is Map ? Map<String, dynamic>.from(v) : null,
          ),
        );
        typing = Map<String, bool>.from(data['typing'] ?? typing);
        preferredModes =
            Map<String, String?>.from(data['preferredModes'] ?? preferredModes);
        debugPrint(
            "Firestore sync: peacockTimers=$peacockTimers, peacockQueue=$peacockQueue");
        notifyListeners();
      }
    });

    _firestore.collection('schedules').snapshots().listen((snapshot) {
      scheduledTimes = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
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
  }

  void updateFirestore({bool force = false}) {
    final now = DateTime.now();
    if (force ||
        now.difference(_lastFirestoreUpdate).inSeconds >=
            _firestoreUpdateInterval) {
      final data = {
        'squadSpots': squadSpots,
        'spotTimers': spotTimers,
        'statuses': statuses,
        'currentStreaks': currentStreaks,
        'highestStreaks': highestStreaks,
        'gameHistory': gameHistory,
        'complaints': complaints,
        'achievements': achievements.map((k, v) => MapEntry(k, v.toList())),
        'dailyRatings': dailyRatings,
        'allTimeRatings': allTimeRatings,
        'peacockTimers': peacockTimers,
        'peacockQueue': peacockQueue,
        'members': squadMembers,
        'typing': typing,
        'preferredModes': preferredModes,
      };
      _firestore
          .collection('squad')
          .doc('state')
          .set(data, SetOptions(merge: true));
      _lastFirestoreUpdate = now;
    }
  }

  void updatePreferredMode(String user, String? mode) {
    preferredModes[user] = mode;
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

  void removeFromPeacock(String player) {
    if (peacockTimers.containsKey(player)) {
      peacockTimers.remove(player);
      statuses[player] = 'Offline';
    } else if (peacockQueue.contains(player)) {
      peacockQueue.remove(player);
      statuses[player] = 'Offline';
    }
    updateFirestore(force: true);
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
      } else if (peacockQueue.contains(_displayName)) {
        peacockQueue.remove(_displayName);
      }
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
      } else {
        peacockQueue.add(_displayName!);
        statuses[_displayName!] = 'Waiting';
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
        } else {
          peacockQueue.add(_displayName!);
          statuses[_displayName!] = 'Waiting';
        }
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
      }
    }
    updateFirestore(force: true);
    notifyListeners();
  }

  void updateTypingStatus(String user, bool isTyping) {
    if (typing[user] != isTyping) {
      typing[user] = isTyping;
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
    } else if (peacockQueue.contains(player)) {
      peacockQueue.remove(player);
    }
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
      updateFirestore(force: true);
      notifyListeners();
    }
  }

  void lockSpot(int index) {
    if (spotTimers[index] != null) {
      spotTimers[index] = null;
      statuses[squadSpots[index]!] = 'Walking';
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
      }
    }
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
                        } else {
                          peacockQueue.add(player);
                          statuses[player] = 'Waiting';
                        }
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
                      onPressed: () {
                        peacockTimers.remove(entry.key);
                        statuses[entry.key] = 'Ready';
                        _assignNextFromQueue();
                        updateFirestore(force: true);
                        notifyListeners();
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
                        onPressed: () {
                          peacockQueue.remove(player);
                          statuses[player] = 'Offline';
                          updateFirestore(force: true);
                          notifyListeners();
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
        }
      }
    }
    updateFirestore();
  }

  void updatePeacockTimers() {
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
          _assignNextFromQueue();
        }
      }
    });
    peacockTimers.removeWhere((key, value) => value == null);
    updateFirestore();
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
  }
}
