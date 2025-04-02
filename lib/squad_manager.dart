import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SquadState with ChangeNotifier {
  final SquadManager logic;
  Map<String, List<Map<String, dynamic>>> bans = {};

  SquadState(this.logic);

  void addBan(String player, String voter) {
    bans[player] ??= [];
    if (bans[player]!.any((ban) => ban['voter'] == voter)) return;
    bans[player]!.add(
        {'voter': voter, 'timestamp': DateTime.now().millisecondsSinceEpoch});
    notifyListeners();
    _startBanTimer(player);
  }

  void clearAllSpots() {
    for (int i = 0; i < logic.squadSpots.length; i++) {
      if (logic.squadSpots[i] != null) {
        logic.removeSpot(i);
      }
    }
    notifyListeners();
  }

  void resetTimers() {
    for (int i = 0; i < logic.spotTimers.length; i++) {
      if (logic.spotTimers[i] != null && logic.squadSpots[i] != null) {
        logic.spotTimers[i] = 300; // Reset to 5 minutes
      }
    }
    logic.peacockTimers.forEach((player, timer) {
      if (timer != null) {
        timer['startTime'] = DateTime.now().millisecondsSinceEpoch;
        timer['duration'] = 3600; // Reset to 1 hour
      }
    });
    notifyListeners();
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

  void update() {
    notifyListeners();
  }
}

class SquadManager {
  final List<String?> squadSpots;
  final List<int?> spotTimers;
  final Map<String, String> statuses;
  final Map<String, Map<String, dynamic>?> peacockTimers;
  final List<String> peacockQueue;
  final List<String> squadMembers;
  final VoidCallback updateFirestore;
  final BuildContext context;
  final String yourName;
  final Map<String, int> currentStreaks;

  SquadManager({
    required this.squadSpots,
    required this.spotTimers,
    required this.statuses,
    required this.peacockTimers,
    required this.peacockQueue,
    required this.squadMembers,
    required this.updateFirestore,
    required this.context,
    required this.yourName,
    required this.currentStreaks,
  });

  Widget buildSquadManager() {
    return Consumer<SquadState>(
      builder: (context, squadState, _) => Column(
        children: [
          _buildActionButtons(context, squadState),
          _buildSquadMembersList(context, squadState),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, SquadState squadState) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton(
            onPressed: () {
              // print('Before Win - Streaks: $currentStreaks');
              // print(
              //     'Before Win - Walking Players: ${squadSpots.where((spot) => spot != null && spotTimers[squadSpots.indexOf(spot)] == null).toList()}');
              recordWin(() {
                // print('Win recorded');
                squadState.update();
              });
              // print('After Win - Streaks: $currentStreaks');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontSize: 18),
            ),
            child: const Text('Win'),
          ),
          ElevatedButton(
            onPressed: () {
              // print('Before Loss - Streaks: $currentStreaks');
              recordLoss(() {
                // print('Loss recorded');
                squadState.update();
              });
              // print('After Loss - Streaks: $currentStreaks');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontSize: 18),
            ),
            child: const Text('Loss'),
          ),
        ],
      ),
    );
  }

  Widget _buildSquadMembersList(BuildContext context, SquadState squadState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Semantics(
            label: 'Squad Members List',
            child: Text(
              'Squad Members:',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: Colors.cyanAccent),
            ),
          ),
        ),
        if (squadMembers.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text('No squad members yet',
                style: TextStyle(color: Colors.grey)),
          )
        else
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.grey[900],
            ),
            child: Column(
              children: squadMembers
                  .map(
                      (player) => _buildMemberCard(context, player, squadState))
                  .toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildMemberCard(
      BuildContext context, String player, SquadState squadState) {
    final streak = currentStreaks[player] ?? 0;
    final bans = squadState.getBanCount(player);
    final status = statuses[player] ?? 'Offline';

    String winIcon = 'assets/images/performance.png';
    if (streak >= 10) {
      winIcon = 'assets/images/chicken.png';
    } else if (streak >= 4) {
      winIcon = 'assets/images/duck.png';
    } else if (streak >= 3) {
      winIcon = 'assets/images/turkey.png';
    }

    return Semantics(
      label: 'Member: $player',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[800]!),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(player,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Chip(
                    label: Text(status, style: const TextStyle(fontSize: 12)),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor:
                        _getStatusColor(status).withValues(alpha: 0.2),
                    labelStyle: TextStyle(color: _getStatusColor(status)),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                if (streak > 0)
                  Row(
                    children: [
                      Image.asset(
                        winIcon,
                        width: 20,
                        height: 20,
                        color: Colors.yellowAccent,
                      ),
                      const SizedBox(width: 4),
                      Text('$streak',
                          style: const TextStyle(color: Colors.yellowAccent)),
                    ],
                  ),
                if (bans > 0) ...[
                  const SizedBox(width: 12),
                  Row(
                    children: [
                      Image.asset(
                        'assets/images/sword.png',
                        width: 20,
                        height: 20,
                        color: Colors.redAccent,
                      ),
                      const SizedBox(width: 4),
                      Text('$bans',
                          style: const TextStyle(color: Colors.redAccent)),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Strutting':
        return Colors.blueAccent;
      case 'Walking':
        return Colors.greenAccent;
      case 'Ready':
        return Colors.yellowAccent;
      case 'Waiting':
        return Colors.grey[400]!;
      default:
        return Colors.grey[600]!;
    }
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
              selectedPlayer = value;
              if (selectedPlayer != null) {
                squadSpots[index] = selectedPlayer;
                spotTimers[index] = 300;
                statuses[selectedPlayer!] = 'Ready';
                updateFirestore();
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
      updateFirestore();
    }
  }

  void claimSpot(int index, {BuildContext? context, VoidCallback? callback}) {
    if (!squadSpots.contains(yourName)) {
      squadSpots[index] = yourName;
      spotTimers[index] = 300;
      statuses[yourName] = 'Ready';
      updateFirestore();
      callback?.call();
    }
  }

  void lockSpot(int index) {
    if (spotTimers[index] != null) {
      spotTimers[index] = null;
      statuses[squadSpots[index]!] = 'Walking';
      updateFirestore();
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
                updateFirestore();
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
    updateFirestore();
  }

  void claimPeacock() {
    startPeacockTimer();
  }

  void claimPeacockDialog() {
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
                        if ((peacockTimers.containsKey(player) &&
                                statuses[player] == 'Strutting') ||
                            (peacockQueue.contains(player) &&
                                statuses[player] == 'Waiting')) {
                          // Do nothing if actively Strutting or Waiting
                        } else {
                          if (peacockTimers.containsKey(player)) {
                            peacockTimers.remove(player);
                          }
                          if (peacockQueue.contains(player)) {
                            peacockQueue.remove(player);
                          }
                          int? spotIndex = squadSpots.indexOf(player);
                          if (spotIndex != -1 &&
                              (statuses[player] == 'Walking' ||
                                  statuses[player] == 'Ready')) {
                            squadSpots[spotIndex] = null;
                            spotTimers[spotIndex] = null;
                          }
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
                          updateFirestore();
                        }
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
                            '${entry.key} (Active: ${getPeacockTimerDisplay(entry.key)})',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.remove_circle,
                                color: Colors.redAccent),
                            onPressed: () {
                              peacockTimers.remove(entry.key);
                              statuses[entry.key] = 'Ready';
                              _assignNextFromQueue();
                              updateFirestore();
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
                          peacockQueue.remove(player);
                          statuses[player] = 'Offline';
                          updateFirestore();
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
      updateFirestore();
    }
  }

  String _formatTimer(int? seconds) {
    if (seconds == null) return '00:00';
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

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

  void recordWin(void Function() callback) {
    // Placeholder: Update currentStreaks or other logic here
    for (var player in squadSpots.where((spot) => spot != null)) {
      currentStreaks[player!] = (currentStreaks[player] ?? 0) + 1;
    }
    updateFirestore();
    callback();
  }

  void recordLoss(void Function() callback) {
    // Placeholder: Reset streaks or other logic here
    for (var player in squadSpots.where((spot) => spot != null)) {
      currentStreaks[player!] = 0;
    }
    updateFirestore();
    callback();
  }
}
