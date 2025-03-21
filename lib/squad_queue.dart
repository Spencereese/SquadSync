import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'setup_screen.dart';
import 'chat/chat_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';
import 'squad_tab.dart';
import 'availability_tab.dart';
import 'utils.dart';
import 'performance_hub_tab.dart';
import 'rating_dialog.dart';

class SquadQueuePage extends StatefulWidget {
  final String yourName;
  const SquadQueuePage({super.key, required this.yourName});

  @override
  SquadQueuePageState createState() => SquadQueuePageState();
}

class SquadQueuePageState extends State<SquadQueuePage> {
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
  int _selectedIndex = 2; // Start on Squad tab (Peacock)
  static const int _firestoreUpdateInterval = 5;
  DateTime _lastFirestoreUpdate = DateTime.now();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _initializeAuth();
    _initializeData();
    _syncWithFirestore(); // Firestore handles everything now
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _initializeAuth() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      UserCredential cred = await FirebaseAuth.instance.signInAnonymously();
      await cred.user!.updateDisplayName(widget.yourName);
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
    // Count Strutting players in peacockTimers
    int struttingCount =
        peacockTimers.values.where((timer) => timer != null).length;
    // Count Waiting players in peacockQueue
    int waitingCount = peacockQueue.length;
    // Count available spots in squadSpots
    int availableSpots = squadSpots.where((spot) => spot == null).length;

    print(
        'Strutting: $struttingCount, Waiting: $waitingCount, Available Spots: $availableSpots, Queue: $peacockQueue');

    // Determine required spots based on Strutting or Waiting players
    int requiredSpots = struttingCount > 0 ? struttingCount : waitingCount;

    // Only assign if available spots exactly match required count
    if (availableSpots == requiredSpots && requiredSpots > 0) {
      setState(() {
        // Step 1: Move all Strutting players from peacockTimers to squadSpots
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
              print('Moved $player from Peacock to Spot ${freeSpot + 1}');
            }
          }
        }
        // Step 2: Move all Waiting players from peacockQueue if no Strutting players
        else if (waitingCount > 0) {
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
                print(
                    'Assigned $nextPlayer from queue to Spot ${freeSpot + 1}');
              }
            }
          }
        }

        updateFirestore(force: true);
      });
    } else {
      print(
          'Skipping assignment: Spots ($availableSpots) do not match required ($requiredSpots)');
    }
  }

  void startPeacockTimer() {
    String selectedMode = 'Trios';
    showDialog(
      context: context,
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
              setState(() {
                if (!squadSpots.contains(widget.yourName) &&
                    !peacockTimers.containsKey(widget.yourName) &&
                    !peacockQueue.contains(widget.yourName)) {
                  if (peacockTimers.length < 4) {
                    peacockTimers[widget.yourName] = {
                      'startTime': DateTime.now()
                          .millisecondsSinceEpoch, // Save start time
                      'duration': 3600, // Total duration in seconds
                      'mode': selectedMode
                    };
                    statuses[widget.yourName] = 'Strutting';
                  } else {
                    peacockQueue.add(widget.yourName);
                    statuses[widget.yourName] = 'Waiting';
                  }
                  updateFirestore(force: true); // Sync to Firestore
                }
              });
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
        setState(() {
          var data = snapshot.data()!;
          squadSpots = List<String?>.from(
              data['squadSpots'] ?? [null, null, null, null]);
          spotTimers =
              List<int?>.from(data['spotTimers'] ?? [null, null, null, null]);
          statuses = Map<String, String>.from(data['statuses'] ?? statuses);
          currentStreaks =
              Map<String, int>.from(data['currentStreaks'] ?? currentStreaks);
          highestStreaks =
              Map<String, int>.from(data['highestStreaks'] ?? highestStreaks);
          gameHistory =
              List<Map<String, dynamic>>.from(data['gameHistory'] ?? []);
          complaints = Map<String, int>.from(data['complaints'] ?? complaints);
          achievements = (data['achievements'] ?? {})
              .map((k, v) => MapEntry(k, Set<String>.from(v ?? [])));
          dailyRatings = (data['dailyRatings'] ?? {})
              .map((k, v) => MapEntry(k, Map<String, List<int>>.from(v)));
          allTimeRatings = (data['allTimeRatings'] ?? {})
              .map((k, v) => MapEntry(k, Map<String, List<int>>.from(v)));
          scheduledTimes =
              List<Map<String, dynamic>>.from(data['scheduledTimes'] ?? []);
          peacockQueue =
              List<String>.from(data['peacockQueue'] ?? peacockQueue);

          // Sync peacockTimers and calculate remaining time
          var rawPeacockTimers =
              Map<String, dynamic>.from(data['peacockTimers'] ?? {});
          peacockTimers = rawPeacockTimers.map((player, value) {
            if (value != null) {
              int startTime = value['startTime'] as int;
              int duration = value['duration'] as int;
              int elapsedSeconds =
                  ((DateTime.now().millisecondsSinceEpoch - startTime) / 1000)
                      .floor();
              int remainingTime = duration - elapsedSeconds;
              if (remainingTime <= 0) {
                statuses[player] = 'Ready';
                return MapEntry(player, null); // Timer expired
              }
              return MapEntry(player, {
                'startTime': startTime,
                'duration': duration,
                'mode': value['mode']
              });
            }
            return MapEntry(player, null);
          }).cast<String, Map<String, dynamic>?>();
          peacockTimers.removeWhere((key, value) => value == null);
        });
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
        'peacockTimers': peacockTimers, // Already has startTime and duration
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

  void _showRatingDialog(String leavingPlayer) {
    List<String> walkingPlayers = squadSpots
        .where((spot) =>
            spot != null &&
            spotTimers[squadSpots.indexOf(spot)] == null &&
            spot != leavingPlayer)
        .cast<String>()
        .toList();
    if (walkingPlayers.isEmpty) return;

    RatingDialog.showRatingDialog(context, walkingPlayers, (ratings) {
      setState(() {
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

  Widget _buildSlider(String label, double value, Function(double) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 14)),
            Text(value.toInt().toString(),
                style: const TextStyle(color: Colors.white, fontSize: 14)),
          ],
        ),
        Slider(
          value: value,
          min: 1.0,
          max: 10.0,
          divisions: 9,
          label: value.toInt().toString(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  void _checkAchievements(String player, int streak) {
    print('Checking achievements for $player, streak: $streak');
    achievements[player] ??= {};
    bool added = false;
    if (streak >= 10) {
      achievements[player]!.add('Chicken');
      _audioPlayer.play(AssetSource('sounds/turducken.wav'));
      added = true;
      print('$player earned Chicken');
    }
    if (streak >= 4 && !added) {
      achievements[player]!.add('Duck');
      _audioPlayer.play(AssetSource('sounds/duck.mp3'));
      added = true;
      print('$player earned Duck');
    }
    if (streak >= 3 && !added) {
      achievements[player]!.add('Turkey');
      _audioPlayer.play(AssetSource('sounds/turkey.wav'));
      print('$player earned Turkey');
    }
  }

  void recordWin() {
    setState(() {
      List<String> walkingPlayers = squadSpots
          .where((spot) =>
              spot != null && spotTimers[squadSpots.indexOf(spot)] == null)
          .cast<String>()
          .toList();
      print('Walking players for win: $walkingPlayers');
      Map<String, int> updatedStreaks = {};
      for (var player in walkingPlayers) {
        int oldStreak = currentStreaks[player] ?? 0;
        updatedStreaks[player] = oldStreak + 1;
        print('$player streak: $oldStreak -> ${updatedStreaks[player]}');
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

  void recordLoss() {
    setState(() {
      List<String> walkingPlayers = squadSpots
          .where((spot) =>
              spot != null && spotTimers[squadSpots.indexOf(spot)] == null)
          .cast<String>()
          .toList();
      print('Walking players for loss: $walkingPlayers');
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
    });
  }

  void assignSpot(int index) {
    showDialog(
      context: context,
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
              setState(() {
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

  void removeSpot(int index) {
    setState(() {
      String? player = squadSpots[index];
      if (player != null) {
        squadSpots[index] = null;
        spotTimers[index] = null;
        statuses[player] = 'Offline';
        updateFirestore(force: true);
      }
    });
  }

  void claimSpot(int index) {
    setState(() {
      if (!squadSpots.contains(widget.yourName)) {
        squadSpots[index] = widget.yourName;
        spotTimers[index] = 300;
        statuses[widget.yourName] = 'Ready';
        updateFirestore(force: true);
      }
    });
  }

  void lockSpot(int index) {
    setState(() {
      if (spotTimers[index] != null) {
        spotTimers[index] = null;
        statuses[squadSpots[index]!] = 'Walking';
        updateFirestore(force: true);
      }
    });
  }

  void reupPeacock() {
    setState(() {
      peacockTimers[widget.yourName] = peacockTimers[widget.yourName] != null
          ? {
              'time': 3600,
              'mode': peacockTimers[widget.yourName]!['mode'] as String
            }
          : {'time': 3600, 'mode': 'Quads'};
      statuses[widget.yourName] = 'Strutting';
      updateFirestore(force: true);
    });
  }

  void claimPeacock() {
    startPeacockTimer();
  }

  void claimPeacockDialog(BuildContext context) {
    print('PeacockTimers: $peacockTimers');
    print('PeacockQueue: $peacockQueue');
    print('SquadSpots: $squadSpots');
    print('Statuses: $statuses');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Assign Peacock',
            style: TextStyle(color: Colors.cyanAccent)),
        content: SingleChildScrollView(
          child: Column(
            children: squadMembers
                .map((player) => ListTile(
                      title: Text(player,
                          style: Theme.of(context).textTheme.bodyMedium),
                      onTap: () {
                        setState(() {
                          print('Attempting to assign $player');
                          // Block if actively Strutting or Waiting
                          if ((peacockTimers.containsKey(player) &&
                                  statuses[player] == 'Strutting') ||
                              (peacockQueue.contains(player) &&
                                  statuses[player] == 'Waiting')) {
                            print(
                                'Cannot assign $player: actively Strutting or Waiting');
                          } else {
                            // Clear stale Peacock/Queue entries if not Strutting/Waiting
                            if (peacockTimers.containsKey(player)) {
                              peacockTimers.remove(player);
                              print('Cleared stale Peacock entry for $player');
                            }
                            if (peacockQueue.contains(player)) {
                              peacockQueue.remove(player);
                              print('Cleared stale Queue entry for $player');
                            }
                            // Pull from squadSpots if Walking or Ready
                            int? spotIndex = squadSpots.indexOf(player);
                            if (spotIndex != -1 &&
                                (statuses[player] == 'Walking' ||
                                    statuses[player] == 'Ready')) {
                              squadSpots[spotIndex] = null;
                              spotTimers[spotIndex] = null;
                              print(
                                  'Pulled $player from Spot ${spotIndex + 1} to Peacock');
                            }
                            // Assign to Peacock
                            if (peacockTimers.length < 4) {
                              peacockTimers[player] = {
                                'time': 3600,
                                'mode': 'Quads'
                              };
                              statuses[player] = 'Strutting';
                              print('Assigned $player to Peacock as Strutting');
                            } else {
                              peacockQueue.add(player);
                              statuses[player] = 'Waiting';
                              print(
                                  'Added $player to Peacock queue as Waiting');
                            }
                            updateFirestore(force: true);
                          }
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
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void managePeacock() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manage Peacock Queue',
            style: TextStyle(color: Colors.cyanAccent)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...peacockTimers.entries
                    .where((entry) => entry.value != null)
                    .map((entry) => ListTile(
                          title: Text(
                            '${entry.key} (Active: ${formatTimer(entry.value?['time'] as int?)})',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.remove_circle,
                                color: Colors.redAccent),
                            onPressed: () {
                              setState(() {
                                peacockTimers.remove(entry.key);
                                statuses[entry.key] = 'Ready';
                                _assignNextFromQueue();
                                updateFirestore(force: true);
                                print('Removed ${entry.key} from Peacock');
                              });
                              Navigator.pop(context);
                              managePeacock();
                            },
                          ),
                        )),
                ...peacockQueue.map((player) => ListTile(
                      title: Text('$player (Waiting)',
                          style: Theme.of(context).textTheme.bodyMedium),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle,
                            color: Colors.redAccent),
                        onPressed: () {
                          setState(() {
                            peacockQueue.remove(player);
                            statuses[player] = 'Offline';
                            updateFirestore(force: true);
                            print('Removed $player from Peacock queue');
                          });
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

  void scheduleTime(bool available) {
    showDialog(
      context: context,
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
                  setState(() {
                    scheduledTimes.add({
                      'player': widget.yourName,
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

  void logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('yourName');
    if (mounted) {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (context) => const SetupScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.black, Colors.indigo],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height:
                    MediaQuery.of(context).size.height - kToolbarHeight - 64,
                child: _buildPages()[_selectedIndex],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 64,
              color: Colors.black,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildTabItem(
                      iconPath: 'assets/images/performance.png',
                      index: 0,
                      size: 32),
                  _buildTabItem(
                      iconPath: 'assets/images/availability.png',
                      index: 1,
                      size: 32),
                  _buildPeacockTabItem(),
                  _buildTabItem(
                      iconPath: 'assets/images/chat.png', index: 3, size: 32),
                  _buildTabItem(
                      iconPath: 'assets/images/placeholder.png',
                      index: 4,
                      size: 32),
                ],
              ),
            ),
          ),
        ],
      ),
      appBar: AppBar(title: const Text('SquadSync')),
    );
  }

  List<Widget> _buildPages() {
    return [
      PerformanceHubTab(state: this), // New Performance Hub tab
      AvailabilityTab(state: this),
      SquadTab(state: this),
      ChatScreen(yourName: widget.yourName),
      const PlaceholderTab(),
    ];
  }

  Widget _buildTabItem({
    required String iconPath,
    required int index,
    required double size,
  }) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image(
            image: AssetImage(iconPath),
            width: size,
            height: size,
            color: isSelected ? null : Colors.grey[600],
          ),
          if (isSelected)
            Container(
              width: size,
              height: 2,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: Colors.cyanAccent,
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyanAccent.withOpacity(0.5),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPeacockTabItem() {
    bool isSelected = _selectedIndex == 2;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: Image(
              image: AssetImage('assets/images/squad.png'),
              fit: BoxFit.contain,
            ),
          ),
          if (isSelected)
            Container(
              width: 52,
              height: 2,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: Colors.cyanAccent,
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyanAccent.withOpacity(0.6),
                    blurRadius: 6,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class PlaceholderTab extends StatelessWidget {
  const PlaceholderTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'we can stop them\nwe can make them suffer',
        style: TextStyle(color: Colors.white, fontSize: 24),
      ),
    );
  }
}
