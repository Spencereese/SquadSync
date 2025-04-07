import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../notification_service.dart';
import '../rating_dialog.dart';

class SquadState with ChangeNotifier {
  // Core data
  List<String?> squadSpots = List.filled(4, null);
  List<int?> spotTimers = List.filled(4, null);
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
  Map<String, Map<String, List<int>>> allTimeRatings = {};
  List<Map<String, dynamic>> scheduledTimes = [];
  Map<String, List<Map<String, dynamic>>> bans = {};
  Map<String, bool> typing = {};

  // Firebase and utilities
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AudioPlayer _audioPlayer = AudioPlayer();
  static const int _firestoreUpdateInterval = 5;
  DateTime _lastFirestoreUpdate = DateTime.now();
  Timer? _timer;

  // Context and user info
  BuildContext? context; // Set by initState
  final String yourName;

  SquadState({required this.yourName});

  // Initialization
  void initState(BuildContext ctx) {
    context = ctx;
    _initializeAuth();
    _initializeData();
    _syncWithFirestore();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      updateSpotTimers();
      updatePeacockTimers();
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _initializeAuth() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      UserCredential cred = await FirebaseAuth.instance.signInAnonymously();
      await cred.user!.updateDisplayName(yourName);
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
    }
  }

  // Firestore sync
  void _syncWithFirestore() {
    _firestore.collection('squad').doc('state').snapshots().listen((snapshot) {
      if (snapshot.exists) {
        var data = snapshot.data()!;
        squadSpots = List<String?>.from(data['squadSpots'] ?? squadSpots);
        spotTimers = List<int?>.from(data['spotTimers'] ?? spotTimers);
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
        scheduledTimes =
            List<Map<String, dynamic>>.from(data['scheduledTimes'] ?? []);
        peacockQueue = List<String>.from(data['peacockQueue'] ?? peacockQueue);
        peacockTimers =
            Map<String, dynamic>.from(data['peacockTimers'] ?? {}).map(
          (k, v) =>
              MapEntry(k, v != null ? Map<String, dynamic>.from(v) : null),
        );
        typing = Map<String, bool>.from(data['typing'] ?? typing);
        notifyListeners();
      }
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
        'scheduledTimes': scheduledTimes,
        'peacockTimers': peacockTimers,
        'peacockQueue': peacockQueue,
        'members': squadMembers,
        'typing': typing,
      };
      _firestore
          .collection('squad')
          .doc('state')
          .set(data, SetOptions(merge: true));
      _lastFirestoreUpdate = now;
    }
  }

  // Typing management for ChatService
  void updateTypingStatus(String user, bool isTyping) {
    if (typing[user] != isTyping) {
      typing[user] = isTyping;
      updateFirestore(force: true);
      notifyListeners();
    }
  }

  String? getTypingUser() {
    return typing.entries
        .where((entry) => entry.value == true)
        .map((entry) => entry.key)
        .firstOrNull;
  }

  // Squad management methods
  void assignSpot(int index) {
    showDialog(
      context: context!,
      builder: (context) {
        String? selectedPlayer;
        return AlertDialog(
          title: const Text('Assign Spot'),
          content: DropdownButton<String>(
            hint: const Text('Select Player'),
            value: selectedPlayer,
            items: squadMembers
                .where((player) => !squadSpots.contains(player))
                .map((player) =>
                    DropdownMenuItem(value: player, child: Text(player)))
                .toList(),
            onChanged: (value) {
              selectedPlayer = value;
              if (selectedPlayer != null) {
                squadSpots[index] = selectedPlayer;
                spotTimers[index] = 300;
                statuses[selectedPlayer!] = 'Ready';
                updateFirestore(force: true);
                notifyListeners();
                Navigator.pop(context);
              }
            },
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
          ],
        );
      },
    );
  }

  void removeSpot(int index) {
    String? player = squadSpots[index];
    if (player != null) {
      squadSpots[index] = null;
      spotTimers[index] = null;
      statuses[player] = 'Offline';
      updateFirestore(force: true);
      notifyListeners();
    }
  }

  void claimSpot(int index) {
    if (!squadSpots.contains(yourName)) {
      squadSpots[index] = yourName;
      spotTimers[index] = 300;
      statuses[yourName] = 'Ready';
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
        spotTimers[i] = 300;
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

  // Peacock management
  void startPeacockTimer() {
    String selectedMode = 'Trios';
    showDialog(
      context: context!,
      builder: (context) => AlertDialog(
        title: const Text('Select Game Mode'),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return DropdownButton<String>(
              value: selectedMode,
              items: const [
                DropdownMenuItem(value: 'Trios', child: Text('Trios')),
                DropdownMenuItem(value: 'Quads', child: Text('Quads')),
              ],
              onChanged: (value) => setDialogState(() => selectedMode = value!),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (!squadSpots.contains(yourName) &&
                  !peacockTimers.containsKey(yourName) &&
                  !peacockQueue.contains(yourName)) {
                if (peacockTimers.length < 4) {
                  peacockTimers[yourName] = {
                    'startTime': DateTime.now().millisecondsSinceEpoch,
                    'duration': 3600,
                    'mode': selectedMode
                  };
                  statuses[yourName] = 'Strutting';
                } else {
                  peacockQueue.add(yourName);
                  statuses[yourName] = 'Waiting';
                }
                updateFirestore(force: true);
                notifyListeners();
              }
            },
            child: const Text('Peacock'),
          ),
        ],
      ),
    );
  }

  void reupPeacock() {
    peacockTimers[yourName] = peacockTimers[yourName] != null
        ? {
            'startTime': DateTime.now().millisecondsSinceEpoch,
            'duration': 3600,
            'mode': peacockTimers[yourName]!['mode'] as String
          }
        : {
            'startTime': DateTime.now().millisecondsSinceEpoch,
            'duration': 3600,
            'mode': 'Quads'
          };
    statuses[yourName] = 'Strutting';
    updateFirestore(force: true);
    notifyListeners();
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
              child: const Text('Cancel')),
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
              child: const Text('Close')),
        ],
      ),
    );
  }

  // Ban management
  void addBan(String player, String voter) {
    bans[player] ??= [];
    if (bans[player]!.any((ban) => ban['voter'] == voter)) return;
    bans[player]!.add(
        {'voter': voter, 'timestamp': DateTime.now().millisecondsSinceEpoch});
    notifyListeners();
    _startBanTimer(player);
  }

  void _startBanTimer(String player) async {
    await Future.delayed(Duration(hours: 4));
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

  // Timer updates
  void updateSpotTimers() {
    for (int i = 0; i < spotTimers.length; i++) {
      if (spotTimers[i] != null && spotTimers[i]! > 0) {
        spotTimers[i] = spotTimers[i]! - 1;
        if (spotTimers[i] == 0) {
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

  // Helpers
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
    int requiredSpots = struttingCount > 0 ? struttingCount : waitingCount;

    if (availableSpots == requiredSpots && requiredSpots > 0) {
      if (struttingCount > 0) {
        List<String> struttingPlayers = peacockTimers.keys
            .where((player) => peacockTimers[player] != null)
            .toList();
        for (String player in struttingPlayers) {
          int? freeSpot = squadSpots.indexOf(null);
          if (freeSpot != -1) {
            squadSpots[freeSpot] = player;
            spotTimers[freeSpot] = 300;
            statuses[player] = 'Ready';
            peacockTimers.remove(player);
          }
        }
      } else if (waitingCount > 0) {
        int spotsToFill = waitingCount;
        for (int i = 0; i < spotsToFill; i++) {
          int? freeSpot = squadSpots.indexOf(null);
          if (freeSpot != -1 && peacockQueue.isNotEmpty) {
            String nextPlayer = peacockQueue.removeAt(0);
            if (!squadSpots.contains(nextPlayer) &&
                !peacockTimers.containsKey(nextPlayer)) {
              squadSpots[freeSpot] = nextPlayer;
              spotTimers[freeSpot] = 300;
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
