import 'package:flutter/material.dart';

class SquadManager {
  final List<String?> squadSpots;
  final List<int?> spotTimers; // Keep as reference
  final Map<String, String> statuses;
  final Map<String, Map<String, dynamic>?> peacockTimers;
  final List<String> peacockQueue;
  final List<String> squadMembers;
  final VoidCallback updateFirestore; // Callback to update Firestore
  final BuildContext context;
  final String yourName;

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
  });

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

  void claimSpot(int index) {
    if (!squadSpots.contains(yourName)) {
      squadSpots[index] = yourName;
      spotTimers[index] = 300;
      statuses[yourName] = 'Ready';
      updateFirestore();
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

  // Add these new methods for timer updates
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
}
