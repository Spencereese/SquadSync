import 'dart:async';
import 'package:flutter/material.dart';
import 'squad_queue_logic.dart';
import 'utils.dart';

class SquadTab extends StatefulWidget {
  final SquadQueueLogic logic;

  const SquadTab({super.key, required this.logic});

  @override
  _SquadTabState createState() => _SquadTabState();
}

class _SquadTabState extends State<SquadTab> {
  late Timer _uiTimer;

  @override
  void initState() {
    super.initState();
    // Start a timer to rebuild the UI every second
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {}); // Trigger rebuild to update timers
    });
  }

  @override
  void dispose() {
    _uiTimer.cancel(); // Clean up the timer
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context, setState),
            _buildSquadSpots(context, setState),
            _buildPeacockSpot(context, setState),
            _buildActionButtons(context, setState),
            _buildSquadMembersList(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, StateSetter setState) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Squad',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettingsDialog(context, setState),
            tooltip: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildSquadSpots(BuildContext context, StateSetter setState) {
    return Column(
      children: List.generate(
        4,
        (index) => _buildSpotCard(context, index, setState),
      ),
    );
  }

  Widget _buildSpotCard(BuildContext context, int index, StateSetter setState) {
    final spotName = widget.logic.squadSpots[index];
    final hasOccupant = spotName != null;

    return GestureDetector(
      onLongPress: () => hasOccupant
          ? widget.logic.removeSpot(index, setState)
          : widget.logic.assignSpot(index, setState),
      child: Card(
        elevation: 3,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSpotInfo(context, index, spotName),
              _buildSpotActions(index, hasOccupant, setState),
            ],
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
              style: Theme.of(context).textTheme.titleLarge),
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

  Widget _buildSpotActions(int index, bool hasOccupant, StateSetter setState) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!hasOccupant)
          ElevatedButton(
            onPressed: () => widget.logic.claimSpot(index, setState),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Claim'),
          ),
        if (hasOccupant && widget.logic.spotTimers[index] != null)
          ElevatedButton(
            onPressed: () => widget.logic.lockSpot(index, setState),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueGrey,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Lock'),
          ),
      ],
    );
  }

  Widget _buildPeacockSpot(BuildContext context, StateSetter setState) {
    return GestureDetector(
      onTap: () => widget.logic.claimPeacockDialog(setState),
      onLongPress: () => widget.logic.managePeacock(setState),
      child: Card(
        elevation: 3,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildPeacockInfo(context),
              ElevatedButton(
                onPressed: () => widget.logic.claimPeacock(),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Claim'),
              ),
            ],
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
    if (widget.logic.peacockTimers.isEmpty &&
        widget.logic.peacockQueue.isEmpty) {
      return const Text('Open', style: TextStyle(color: Colors.white));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ...widget.logic.peacockTimers.entries
            .where((e) => e.value != null)
            .map((entry) => _buildPeacockTimerRow(context, entry)),
        ...widget.logic.peacockQueue
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
    final status = widget.logic.statuses[player] ?? 'Offline';
    final timerIndex = widget.logic.squadSpots.indexOf(player);
    final timer = timerIndex != -1 ? widget.logic.spotTimers[timerIndex] : null;
    final streak = widget.logic.currentStreaks[player] ?? 0;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 8,
        children: [
          _buildStatusChip(status),
          if (timer != null)
            Text('(${formatTimer(timer)})',
                style: Theme.of(context).textTheme.bodySmall),
          if (status == 'Walking') ...[
            buildBadge(streak),
            Text('$streak',
                style: const TextStyle(color: Colors.cyanAccent, fontSize: 12)),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    return Chip(
      label: Text(status, style: const TextStyle(fontSize: 12)),
      padding: const EdgeInsets.symmetric(horizontal: 6),
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

  Widget _buildActionButtons(BuildContext context, StateSetter setState) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton.icon(
            onPressed: () => widget.logic.recordWin(setState),
            icon: Image.asset('assets/images/check.png', width: 24, height: 24),
            label: const Text('Win'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => widget.logic.recordLoss(setState),
            icon: Image.asset('assets/images/close.png', width: 24, height: 24),
            label: const Text('Loss'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSquadMembersList(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Squad Members:',
              style: Theme.of(context).textTheme.titleLarge),
        ),
        if (widget.logic.squadMembers.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text('No squad members yet',
                style: TextStyle(color: Colors.grey)),
          )
        else
          ...widget.logic.squadMembers
              .map((player) => _buildMemberCard(context, player)),
      ],
    );
  }

  Widget _buildMemberCard(BuildContext context, String player) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(player, style: Theme.of(context).textTheme.bodyMedium),
            _buildPlayerStatusRow(context, player),
          ],
        ),
      ),
    );
  }

  void _showSettingsDialog(BuildContext context, StateSetter setState) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Squad Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.clear_all),
              title: const Text('Clear All Spots'),
              onTap: () {
                widget.logic.clearAllSpots(setState);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.timer_off),
              title: const Text('Reset Timers'),
              onTap: () {
                widget.logic.resetTimers(setState);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Manage Members'),
              onTap: () {
                // Add member management logic here if needed
                Navigator.pop(context);
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
}
