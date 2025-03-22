import 'dart:async';
import 'package:cod_squad_app/utils.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'squad_manager.dart';
import 'notification_service.dart';
import 'rating_dialog.dart';

class SquadQueueLogic {
  List<String?> squadSpots = List.filled(4, null);
  List<int?> spotTimers = List.filled(4, null);
  final List<String> squadMembers = [
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
  static const int _firestoreUpdateInterval = 5;
  DateTime _lastFirestoreUpdate = DateTime.now();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late SquadManager squadManager;
  Timer? _timer;
  final String yourName;
  BuildContext? context; // Will be set by UI

  SquadQueueLogic({required this.yourName});

  void initState(BuildContext ctx) {
    context = ctx;
    _initializeAuth();
    _initializeData();
    _syncWithFirestore();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      squadManager = SquadManager(
        squadSpots: squadSpots,
        spotTimers: spotTimers,
        statuses: statuses,
        peacockTimers: peacockTimers,
        peacockQueue: peacockQueue,
        squadMembers: squadMembers,
        updateFirestore: () => updateFirestore(force: false),
        context: context!,
        yourName: yourName,
      );

      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        squadManager.updateSpotTimers();
        squadManager.updatePeacockTimers();
      });
    });
  }

  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
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
    }
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
    }
  }

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
              }
            },
            child: const Text('Peacock'),
          ),
        ],
      ),
    );
  }

  void _syncWithFirestore() {
    _firestore.collection('squad').doc('state').snapshots().listen((snapshot) {
      if (snapshot.exists) {
        var data = snapshot.data()!;
        var remoteSpotTimers =
            List<int?>.from(data['spotTimers'] ?? [null, null, null, null]);
        statuses = Map<String, String>.from(data['statuses'] ?? statuses);
        currentStreaks =
            Map<String, int>.from(data['currentStreaks'] ?? currentStreaks);
        highestStreaks =
            Map<String, int>.from(data['highestStreaks'] ?? highestStreaks);
        gameHistory =
            List<Map<String, dynamic>>.from(data['gameHistory'] ?? []);
        complaints = Map<String, int>.from(data['complaints'] ?? complaints);
        achievements = (data['achievements'] ?? {}).map((k, v) {
          final value = v is Iterable ? v : [];
          return MapEntry(k as String,
              Set<String>.from(value.map((item) => item.toString())));
        });
        dailyRatings = (data['dailyRatings'] ?? {})
            .map((k, v) => MapEntry(k, Map<String, List<int>>.from(v)));
        allTimeRatings = (data['allTimeRatings'] ?? {})
            .map((k, v) => MapEntry(k, Map<String, List<int>>.from(v)));
        scheduledTimes =
            List<Map<String, dynamic>>.from(data['scheduledTimes'] ?? []);
        peacockQueue = List<String>.from(data['peacockQueue'] ?? peacockQueue);
        peacockTimers = (data['peacockTimers'] ?? {}).map((k, v) =>
            MapEntry(k, v != null ? Map<String, dynamic>.from(v) : null));
      }
    }, onError: (error) => print('Firestore sync error: $error'));
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
      };
      _firestore
          .collection('squad')
          .doc('state')
          .set(data)
          .catchError((error) => print('Firestore update error: $error'));
      _lastFirestoreUpdate = now;
    }
  }

  void _showRatingDialog(String leavingPlayer, Function setStateCallback) {
    List<String> walkingPlayers = squadSpots
        .where((spot) =>
            spot != null &&
            spotTimers[squadSpots.indexOf(spot)] == null &&
            spot != leavingPlayer)
        .cast<String>()
        .toList();
    if (walkingPlayers.isEmpty) return;

    RatingDialog.showRatingDialog(context!, walkingPlayers, (ratings) {
      setStateCallback(() {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        gameHistory.last['ratings'] = ratings;
        for (var player in walkingPlayers) {
          for (var category in ['Vibes', 'Comms', 'Gunny', 'Wingman']) {
            if (ratings[player]![category] != null) {
              dailyRatings[player]![category]!.add(ratings[player]![category]!);
              allTimeRatings[player]![category]!
                  .add(ratings[player]![category]!);
              if (dailyRatings[player]![category]!.isNotEmpty &&
                  now.day != today.day) {
                dailyRatings[player]![category] = [ratings[player]![category]!];
              }
            }
          }
        }
        updateFirestore(force: true);
      });
    });
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

  void recordWin(Function setStateCallback) {
    setStateCallback(() {
      List<String> walkingPlayers = squadSpots
          .where((spot) =>
              spot != null && spotTimers[squadSpots.indexOf(spot)] == null)
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
    });
    updateFirestore(force: true);
  }

  void recordLoss(Function setStateCallback) {
    setStateCallback(() {
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
    });
    updateFirestore(force: true);
  }

  void assignSpot(int index, Function setStateCallback) {
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
              setStateCallback(() {
                selectedPlayer = value;
                if (selectedPlayer != null) {
                  squadSpots[index] = selectedPlayer;
                  spotTimers[index] = 300;
                  statuses[selectedPlayer!] = 'Ready';
                  updateFirestore(force: true);
                  Navigator.pop(context);
                }
              });
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

  void removeSpot(int index, Function setStateCallback) {
    setStateCallback(() {
      String? player = squadSpots[index];
      if (player != null) {
        squadSpots[index] = null;
        spotTimers[index] = null;
        statuses[player] = 'Offline';
        updateFirestore(force: true);
      }
    });
  }

  void claimSpot(int index, Function setStateCallback) {
    setStateCallback(() {
      if (!squadSpots.contains(yourName)) {
        squadSpots[index] = yourName;
        spotTimers[index] = 300;
        statuses[yourName] = 'Ready';
        updateFirestore(force: true);
      }
    });
  }

  void lockSpot(int index, Function setStateCallback) {
    setStateCallback(() {
      if (spotTimers[index] != null) {
        spotTimers[index] = null;
        statuses[squadSpots[index]!] = 'Walking';
        updateFirestore(force: true);
      }
    });
  }

  void reupPeacock(Function setStateCallback) {
    setStateCallback(() {
      peacockTimers[yourName] = peacockTimers[yourName] != null
          ? {'time': 3600, 'mode': peacockTimers[yourName]!['mode'] as String}
          : {'time': 3600, 'mode': 'Quads'};
      statuses[yourName] = 'Strutting';
      updateFirestore(force: true);
    });
  }

  void claimPeacock() {
    startPeacockTimer();
  }

  void clearAllSpots(Function setStateCallback) {
    setStateCallback(() {
      squadSpots = List.filled(4, null);
      spotTimers = List.filled(4, null);
      peacockTimers.clear();
      peacockQueue.clear();
      for (var member in squadMembers) {
        if (statuses[member] == 'Strutting' || statuses[member] == 'Walking') {
          statuses[member] = 'Ready';
        }
      }
    });
  }

  void resetTimers(Function setStateCallback) {
    setStateCallback(() {
      spotTimers = List.filled(4, null);
      peacockTimers.clear();
      for (var player in peacockQueue) {
        statuses[player] = 'Ready';
      }
      peacockQueue.clear();
    });
  }

  void claimPeacockDialog(Function setStateCallback) {
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
                        setStateCallback(() {
                          if (peacockTimers.length < 4) {
                            peacockTimers[player] = {
                              'startTime':
                                  DateTime.now().millisecondsSinceEpoch,
                              'duration': 3600,
                              'mode': 'Quads'
                            };
                            statuses[player] = 'Strutting';
                          } else {
                            peacockQueue.add(player);
                            statuses[player] = 'Waiting';
                          }
                          updateFirestore(force: true);
                        });
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

  void managePeacock(Function setStateCallback) {
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
                        '${entry.key} (Active: ${formatTimer(remaining > 0 ? remaining : 0)})'),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle,
                          color: Colors.redAccent),
                      onPressed: () {
                        setStateCallback(() {
                          peacockTimers.remove(entry.key);
                          statuses[entry.key] = 'Ready';
                          _assignNextFromQueue();
                          updateFirestore(force: true);
                        });
                        Navigator.pop(context);
                        managePeacock(setStateCallback);
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
                          setStateCallback(() {
                            peacockQueue.remove(player);
                            statuses[player] = 'Offline';
                            updateFirestore(force: true);
                          });
                          Navigator.pop(context);
                          managePeacock(setStateCallback);
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

  void scheduleTime(bool available, Function setStateCallback) {
    showDialog(
      context: context!,
      builder: (BuildContext context) {
        DateTime? selectedDateTime;
        return AlertDialog(
          title:
              Text('Call to Arms (${available ? 'Available' : 'Unavailable'})'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (time != null) {
                          setState(() {
                            selectedDateTime = DateTime(date.year, date.month,
                                date.day, time.hour, time.minute);
                          });
                        }
                      }
                    },
                    child: Text(
                      selectedDateTime == null
                          ? 'Pick a Time'
                          : selectedDateTime!
                              .toIso8601String()
                              .substring(0, 16),
                    ),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                if (selectedDateTime != null) {
                  setStateCallback(() {
                    scheduledTimes.add({
                      'player': yourName,
                      'available': available,
                      'time': selectedDateTime!.toIso8601String(),
                    });
                    updateFirestore(force: true);
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Schedule'),
            ),
          ],
        );
      },
    );
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('yourName');
  }
}
