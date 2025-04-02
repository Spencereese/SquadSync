import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'squad_queue_logic.dart';
import 'utils.dart';

class SquadState with ChangeNotifier {
  final SquadQueueLogic logic;
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

class SquadTab extends StatelessWidget {
  final SquadQueueLogic logic;
  const SquadTab({super.key, required this.logic});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SquadState(logic),
      child: _SquadTabContent(),
    );
  }
}

class _SquadTabContent extends StatefulWidget {
  @override
  _SquadTabContentState createState() => _SquadTabContentState();
}

class _SquadTabContentState extends State<_SquadTabContent> {
  late Timer _uiTimer;

  @override
  void initState() {
    super.initState();
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _uiTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final squadState = Provider.of<SquadState>(context);
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            _buildSquadSpots(context, squadState),
            _buildPeacockSpot(context, squadState),
            _buildActionButtons(context, squadState),
            _buildSquadMembersList(context, squadState),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Semantics(
            label: 'Squad Title',
            child: Text(
              'Squad',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.cyanAccent,
                  ),
            ),
          ),
          IconButton(
            icon: Image.asset(
              'assets/images/settings_gear.png',
              width: 28,
              height: 28,
              color: Colors.grey[400],
            ),
            onPressed: () => _showSettingsDialog(context),
            tooltip: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildSquadSpots(BuildContext context, SquadState squadState) {
    return Column(
      children: List.generate(
        4,
        (index) => _buildSpotCard(context, index, squadState),
      ),
    );
  }

  Widget _buildSpotCard(
      BuildContext context, int index, SquadState squadState) {
    final spotName = squadState.logic.squadSpots[index];
    final hasOccupant = spotName != null;

    return GestureDetector(
      onLongPress: () => hasOccupant
          ? squadState.logic.removeSpot(index)
          : _assignSpot(context, squadState, index),
      child: Semantics(
        label: 'Spot ${index + 1}: ${spotName ?? 'Open'}',
        child: Card(
          elevation: 4,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSpotInfo(context, index, spotName),
                _buildSpotActions(index, hasOccupant, squadState),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpotInfo(BuildContext context, int index, String? spotName) {
    return Expanded(
      child: Row(
        children: [
          Text('Spot ${index + 1}: ',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  )),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  spotName ?? 'Open',
                  style: Theme.of(context).textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                if (spotName != null) _buildPlayerStatusRow(context, spotName),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpotActions(int index, bool hasOccupant, SquadState squadState) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!hasOccupant)
          ElevatedButton(
            onPressed: () => squadState.logic
                .claimSpot(index, () => setState(() {}), context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Claim'),
          ),
        if (hasOccupant && squadState.logic.spotTimers[index] != null)
          ElevatedButton(
            onPressed: () =>
                squadState.logic.lockSpot(index, () => setState(() {})),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueGrey,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Lock'),
          ),
      ],
    );
  }

  Widget _buildPeacockSpot(BuildContext context, SquadState squadState) {
    return GestureDetector(
      onTap: () =>
          squadState.logic.claimPeacockDialog(() => setState(() {}), context),
      onLongPress: () => squadState.logic.managePeacock(),
      child: Semantics(
        label: 'Peacock Spot',
        child: Card(
          elevation: 4,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildPeacockInfo(context),
                ElevatedButton(
                  onPressed: () => squadState.logic.claimPeacock(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Claim'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPeacockInfo(BuildContext context) {
    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Peacock: ',
              style: TextStyle(
                color: Colors.cyanAccent,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              )),
          Flexible(child: _buildPeacockStatus(context)),
        ],
      ),
    );
  }

  Widget _buildPeacockStatus(BuildContext context) {
    final squadState = Provider.of<SquadState>(context);
    if (squadState.logic.peacockTimers.isEmpty &&
        squadState.logic.peacockQueue.isEmpty) {
      return const Text('Open', style: TextStyle(color: Colors.white));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ...squadState.logic.peacockTimers.entries
            .where((e) => e.value != null)
            .map((entry) => _buildPeacockTimerRow(context, entry)),
        ...squadState.logic.peacockQueue
            .map((player) => _buildPeacockQueueRow(context, player)),
      ],
    );
  }

  Widget _buildPeacockTimerRow(
      BuildContext context, MapEntry<String, dynamic> entry) {
    final startTime = entry.value['startTime'] as int;
    final duration = entry.value['duration'] as int;
    final elapsedSeconds =
        ((DateTime.now().millisecondsSinceEpoch - startTime) / 1000).floor();
    final remainingTime = duration - elapsedSeconds;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(entry.key, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(width: 8),
        _buildStatusChip('Strutting'),
        const SizedBox(width: 8),
        Text(
          remainingTime > 0 ? '(${formatTimer(remainingTime)})' : '(Expired)',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildPeacockQueueRow(BuildContext context, String player) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(player, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(width: 8),
        _buildStatusChip('Waiting'),
      ],
    );
  }

  Widget _buildPlayerStatusRow(BuildContext context, String player) {
    final squadState = Provider.of<SquadState>(context);
    final status = squadState.logic.statuses[player] ?? 'Offline';
    final timerIndex = squadState.logic.squadSpots.indexOf(player);
    final timer =
        timerIndex != -1 ? squadState.logic.spotTimers[timerIndex] : null;
    final streak = squadState.logic.currentStreaks[player] ?? 0;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 8,
        children: [
          _buildStatusChip(status),
          if (timer != null)
            Text('(${formatTimer(timer)})',
                style: Theme.of(context).textTheme.bodySmall),
          if (streak > 0) ...[
            Image.asset(
              'assets/images/performance.png',
              width: 16,
              height: 16,
              color: Colors.yellowAccent,
            ),
            Text('$streak',
                style:
                    const TextStyle(color: Colors.yellowAccent, fontSize: 12)),
          ],
          if (squadState.getBanCount(player) > 0)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                squadState.getBanCount(player),
                (_) => Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Image.asset(
                    'assets/images/sword.png',
                    width: 16,
                    height: 16,
                    color: Colors.redAccent,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    return Chip(
      label: Text(status, style: const TextStyle(fontSize: 12)),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      backgroundColor: _getStatusColor(status).withValues(alpha: 0.2),
      labelStyle: TextStyle(color: _getStatusColor(status)),
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

  Widget _buildActionButtons(BuildContext context, SquadState squadState) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton(
            onPressed: () {
              print('Before Win: ${squadState.logic.currentStreaks}');
              squadState.logic.recordWin((VoidCallback innerCallback) {
                setState(() {
                  innerCallback();
                  print('Win recorded');
                  squadState.update();
                });
              });
              print('After Win: ${squadState.logic.currentStreaks}');
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
              print('Before Loss: ${squadState.logic.currentStreaks}');
              squadState.logic.recordLoss((VoidCallback innerCallback) {
                setState(() {
                  innerCallback();
                  print('Loss recorded');
                  squadState.update();
                });
              });
              print('After Loss: ${squadState.logic.currentStreaks}');
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
        if (squadState.logic.squadMembers.isEmpty)
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
              children: squadState.logic.squadMembers
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
    final streak = squadState.logic.currentStreaks[player] ?? 0;
    final bans = squadState.getBanCount(player);
    final status = squadState.logic.statuses[player] ?? 'Offline';

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
                  _buildStatusChip(status),
                ],
              ),
            ),
            Row(
              children: [
                if (streak > 0)
                  Row(
                    children: [
                      Image.asset(
                        'assets/images/performance.png',
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

  void _showSettingsDialog(BuildContext context) {
    final squadState = Provider.of<SquadState>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Squad Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Image.asset(
                'assets/images/clear_all.png',
                width: 24,
                height: 24,
                color: Colors.redAccent,
              ),
              title: const Text('Clear All Spots'),
              onTap: () {
                squadState.logic.clearAllSpots(() => setState(() {}));
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Image.asset(
                'assets/images/timer_off.png',
                width: 24,
                height: 24,
                color: Colors.blueGrey,
              ),
              title: const Text('Reset Timers'),
              onTap: () {
                squadState.logic.resetTimers(() => setState(() {}));
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Image.asset(
                'assets/images/people_group.png',
                width: 24,
                height: 24,
                color: Colors.cyanAccent,
              ),
              title: const Text('Manage Members'),
              onTap: () {
                Navigator.pop(context);
                _showMemberManagementDialog(context, squadState);
              },
            ),
            ListTile(
              leading: Image.asset(
                'assets/images/sword.png',
                width: 24,
                height: 24,
                color: Colors.redAccent,
              ),
              title: const Text('Ban Member'),
              onTap: () {
                Navigator.pop(context);
                _showBanDialog(context, squadState);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showMemberManagementDialog(
      BuildContext context, SquadState squadState) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Manage Members'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Add Member'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Remove Member'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showBanDialog(BuildContext context, SquadState squadState) {
    String? selectedPlayer;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Ban a Member'),
        content: Row(
          children: [
            Image.asset(
              'assets/images/sword.png',
              width: 24,
              height: 24,
              color: Colors.redAccent,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Select Member'),
                items: squadState.logic.squadMembers
                    .map((player) =>
                        DropdownMenuItem(value: player, child: Text(player)))
                    .toList(),
                onChanged: (value) => selectedPlayer = value,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (selectedPlayer != null) {
                squadState.addBan(selectedPlayer!, squadState.logic.yourName);
                Navigator.pop(context);
              }
            },
            child: const Text('Ban'),
          ),
        ],
      ),
    );
  }

  void _assignSpot(BuildContext context, SquadState squadState, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Assign Spot'),
        content: Row(
          children: [
            Image.asset(
              'assets/images/spot_assign.png',
              width: 24,
              height: 24,
              color: Colors.cyanAccent,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Select Player'),
                items: squadState.logic.squadMembers
                    .map((player) =>
                        DropdownMenuItem(value: player, child: Text(player)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    squadState.logic.squadSpots[index] = value;
                    squadState.logic.statuses[value] = 'Walking';
                    squadState.logic.spotTimers[index] = 300;
                    setState(() {});
                    squadState.update();
                    Navigator.pop(context);
                  }
                },
              ),
            ),
          ],
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
}
