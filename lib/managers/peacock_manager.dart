import 'package:flutter/material.dart';

/// Manages peacock queue, timers, and related functionality
class PeacockManager with ChangeNotifier {
  List<String> _peacockQueue = [];
  Map<String, Map<String, dynamic>?> _peacockTimers = {};

  List<String> get peacockQueue => _peacockQueue;
  Map<String, Map<String, dynamic>?> get peacockTimers => _peacockTimers;

  set peacockQueue(List<String> value) {
    _peacockQueue = value;
    notifyListeners();
  }

  set peacockTimers(Map<String, Map<String, dynamic>?> value) {
    _peacockTimers = value;
    notifyListeners();
  }

  // Dependencies that need to be injected or accessed
  String? Function()? getDisplayName;
  List<String> Function()? getSquadMembers;
  List<String?> Function()? getSquadSpots;
  Map<String, String> Function()? getStatuses;
  void Function(String)? updateStatus;
  void Function()? updateFirestore;
  void Function(String)? markFieldChanged;
  BuildContext? Function()? getContext;
  void Function(String, int)?
      assignSpotToPlayer; // Callback for spot assignment

  // Constructor to inject dependencies
  PeacockManager({
    this.getDisplayName,
    this.getSquadMembers,
    this.getSquadSpots,
    this.getStatuses,
    this.updateStatus,
    this.updateFirestore,
    this.markFieldChanged,
    this.getContext,
    this.assignSpotToPlayer,
  });

  void startPeacockTimer(BuildContext dialogContext) {
    final userName = getDisplayName?.call();
    final squadSpots = getSquadSpots?.call() ?? [];

    if (userName != null &&
        userName != 'User' &&
        !squadSpots.contains(userName) &&
        !_peacockTimers.containsKey(userName) &&
        !_peacockQueue.contains(userName)) {
      if (_peacockTimers.length < 4) {
        _peacockTimers[userName] = {
          'startTime': DateTime.now().millisecondsSinceEpoch,
          'duration': 3600,
          'mode': 'Quads'
        };
        updateStatus?.call('$userName:Strutting');
        markFieldChanged?.call('peacockTimers');
        markFieldChanged?.call('statuses');
      } else {
        _peacockQueue.add(userName);
        updateStatus?.call('$userName:Waiting');
        markFieldChanged?.call('peacockQueue');
        markFieldChanged?.call('statuses');
      }
      updateFirestore?.call();
      notifyListeners();
    }
  }

  void reupPeacock() {
    final displayName = getDisplayName?.call();
    if (displayName != null) {
      _peacockTimers[displayName] = _peacockTimers[displayName] != null
          ? {
              'startTime': DateTime.now().millisecondsSinceEpoch,
              'duration': 3600,
              'mode': _peacockTimers[displayName]!['mode'] as String
            }
          : {
              'startTime': DateTime.now().millisecondsSinceEpoch,
              'duration': 3600,
              'mode': 'Quads'
            };
      updateStatus?.call('$displayName:Strutting');
      markFieldChanged?.call('peacockTimers');
      markFieldChanged?.call('statuses');
      updateFirestore?.call();
      notifyListeners();
    }
  }

  void claimPeacockDialog() {
    final context = getContext?.call();
    final squadMembers = getSquadMembers?.call() ?? [];
    final squadSpots = getSquadSpots?.call() ?? [];

    if (context == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Assign Peacock',
            style: TextStyle(color: Colors.cyanAccent)),
        content: SingleChildScrollView(
          child: Column(
            children: squadMembers
                .where((player) =>
                    !_peacockTimers.containsKey(player) &&
                    !_peacockQueue.contains(player) &&
                    !squadSpots.contains(player))
                .map((player) => ListTile(
                      title: Text(player),
                      onTap: () {
                        if (_peacockTimers.length < 4) {
                          _peacockTimers[player] = {
                            'startTime': DateTime.now().millisecondsSinceEpoch,
                            'duration': 3600,
                            'mode': 'Quads'
                          };
                          updateStatus?.call('$player:Strutting');
                          markFieldChanged?.call('peacockTimers');
                        } else {
                          _peacockQueue.add(player);
                          updateStatus?.call('$player:Waiting');
                          markFieldChanged?.call('peacockQueue');
                        }
                        markFieldChanged?.call('statuses');
                        updateFirestore?.call();
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
    final context = getContext?.call();
    if (context == null) return;

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
                ..._peacockTimers.entries.map((entry) {
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
                ..._peacockQueue.map((player) => ListTile(
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

  bool updatePeacockTimers() {
    // Server-side timers are now handled by Cloud Functions
    // This method only cleans up any locally detected expired timers as fallback
    bool changed = false;
    _peacockTimers.forEach((player, timer) {
      if (timer != null) {
        int startTime = timer['startTime'] as int;
        int duration = timer['duration'] as int;
        int elapsed =
            ((DateTime.now().millisecondsSinceEpoch - startTime) / 1000)
                .floor();
        int remaining = duration - elapsed;
        if (remaining <= 0) {
          // Timer expired - clean up locally (server should have done this already)
          _peacockTimers[player] = null;
          updateStatus?.call('$player:Ready');
          markFieldChanged?.call('peacockTimers');
          markFieldChanged?.call('statuses');
          _assignNextFromQueue();
          changed = true;
        }
      }
    });
    _peacockTimers.removeWhere((key, value) => value == null);
    // Don't update Firestore here - server handles timer expiration
    return changed;
  }

  void _assignNextFromQueue() {
    final squadSpots = getSquadSpots?.call() ?? [];
    int struttingCount =
        _peacockTimers.values.where((timer) => timer != null).length;
    int waitingCount = _peacockQueue.length;
    int availableSpots = squadSpots.where((spot) => spot == null).length;

    if (availableSpots > 0 && (struttingCount > 0 || waitingCount > 0)) {
      if (struttingCount > 0) {
        List<String> struttingPlayers = _peacockTimers.keys
            .where((player) => _peacockTimers[player] != null)
            .toList();
        for (String player in struttingPlayers) {
          int? freeSpot = squadSpots.indexOf(null);
          if (freeSpot != -1) {
            assignSpotToPlayer?.call(player, freeSpot);
            _peacockTimers.remove(player);
            markFieldChanged?.call('peacockTimers');
          }
        }
      } else if (waitingCount > 0) {
        for (int i = 0; i < waitingCount && squadSpots.contains(null); i++) {
          int? freeSpot = squadSpots.indexOf(null);
          if (freeSpot != -1 && _peacockQueue.isNotEmpty) {
            String nextPlayer = _peacockQueue.removeAt(0);
            assignSpotToPlayer?.call(nextPlayer, freeSpot);
            markFieldChanged?.call('peacockQueue');
          }
        }
      }
      updateFirestore?.call();
      notifyListeners();
    }
  }

  void addToPeacock(String player) {
    if (!_peacockQueue.contains(player)) {
      _peacockQueue.add(player);
      notifyListeners();
    }
  }

  Future<void> removeFromPeacock(String player) async {
    _peacockQueue.remove(player);
    _peacockTimers.remove(player);
    updateStatus?.call('$player:Offline');
    markFieldChanged?.call('peacockQueue');
    markFieldChanged?.call('peacockTimers');
    markFieldChanged?.call('statuses');
    updateFirestore?.call();
    notifyListeners();
  }

  String getPeacockTimerDisplay(String player) {
    final timer = _peacockTimers[player];
    if (timer == null) return '00:00';
    int startTime = timer['startTime'] as int;
    int duration = timer['duration'] as int;
    int remaining = duration -
        ((DateTime.now().millisecondsSinceEpoch - startTime) / 1000).floor();
    return _formatTimer(remaining > 0 ? remaining : 0);
  }

  String _formatTimer(int? seconds) {
    if (seconds == null || seconds <= 0) return '00:00';
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}
