import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../squad_state.dart';
import '../utils.dart';

class SquadTab extends StatelessWidget {
  const SquadTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SquadTabContent();
  }
}

class _SquadTabContent extends StatefulWidget {
  const _SquadTabContent();

  @override
  _SquadTabContentState createState() => _SquadTabContentState();
}

class _SquadTabContentState extends State<_SquadTabContent> {
  @override
  Widget build(BuildContext context) {
    return Consumer<SquadState>(
      builder: (context, squadState, child) {
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
      },
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
    final spotName = squadState.squadSpots[index];
    final hasOccupant = spotName != null;
    final yourName = squadState.yourName;

    return GestureDetector(
      onTap: () {
        if (!hasOccupant && squadState.squadSpots.contains(yourName)) {
          _assignOtherMember(context, squadState, index);
        }
      },
      onLongPress: () => hasOccupant
          ? squadState.removeSpot(index)
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
                _buildSpotInfo(context, index, spotName, squadState),
                _buildSpotActions(context, index, hasOccupant, squadState),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpotInfo(BuildContext context, int index, String? spotName,
      SquadState squadState) {
    return Expanded(
      child: Row(
        children: [
          Text('Spot ${index + 1}: ',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  spotName ?? 'Open',
                  style: Theme.of(context).textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                if (spotName != null)
                  _buildPlayerStatusRow(context, spotName, squadState),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpotActions(BuildContext context, int index, bool hasOccupant,
      SquadState squadState) {
    final spotName = squadState.squadSpots[index];
    final yourName = squadState.yourName;
    final isReady = squadState.statuses[spotName] == 'Ready';
    final youAreAssigned = squadState.squadSpots.contains(yourName);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!hasOccupant)
          ElevatedButton(
            onPressed: () {
              if (youAreAssigned) {
                _assignOtherMember(context, squadState, index);
              } else {
                squadState.claimSpot(index);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 6,
            ),
            child: const Tooltip(
              message: 'Claim this spot or assign another',
              child: Text('Claim'),
            ),
          ),
        if (hasOccupant && isReady)
          ElevatedButton(
            onPressed: () => squadState.lockSpot(index),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.yellowAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 6,
            ),
            child: const Tooltip(
              message: 'Confirm as Walking',
              child: Text('Lock In'),
            ),
          ),
      ],
    );
  }

  Widget _buildPeacockSpot(BuildContext context, SquadState squadState) {
    final yourName = squadState.yourName;
    final youAreAssigned = squadState.squadSpots.contains(yourName);
    final canClaimPeacock = !youAreAssigned;

    return GestureDetector(
      onTap: canClaimPeacock ? () => squadState.startPeacockTimer() : null,
      onLongPress: () => squadState.managePeacock(),
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
                  onPressed: canClaimPeacock
                      ? () => squadState.startPeacockTimer()
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        canClaimPeacock ? Colors.teal : Colors.grey,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 6,
                  ),
                  child: const Tooltip(
                    message: 'Claim Peacock spot',
                    child: Text('Claim'),
                  ),
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
    if (squadState.peacockTimers.isEmpty && squadState.peacockQueue.isEmpty) {
      return const Text('Open', style: TextStyle(color: Colors.white));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ...squadState.peacockTimers.entries
            .where((e) => e.value != null)
            .map((entry) => _buildPeacockTimerRow(context, entry, squadState)),
        ...squadState.peacockQueue
            .map((player) => _buildPeacockQueueRow(context, player)),
      ],
    );
  }

  Widget _buildPeacockTimerRow(BuildContext context,
      MapEntry<String, Map<String, dynamic>?> entry, SquadState squadState) {
    final timer = entry.value;
    if (timer == null) return const SizedBox.shrink();
    final remainingTime = squadState.getPeacockTimerDisplay(entry.key);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(entry.key, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(width: 8),
        _buildStatusChip('Strutting'),
        const SizedBox(width: 8),
        Text('($remainingTime)', style: Theme.of(context).textTheme.bodySmall),
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

  Widget _buildPlayerStatusRow(
      BuildContext context, String player, SquadState squadState) {
    final status = squadState.statuses[player] ?? 'Offline';
    final timerIndex = squadState.squadSpots.indexOf(player);
    final timer = timerIndex != -1 ? squadState.spotTimers[timerIndex] : null;
    final streak = squadState.currentStreaks[player] ?? 0;
    final banCount = squadState.getBanCount(player);

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
          if (banCount > 0)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                banCount,
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
            onPressed: squadState.recordWin,
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
            onPressed: squadState.recordLoss,
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
        if (squadState.squadMembers.isEmpty)
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
              children: squadState.squadMembers
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
    final streak = squadState.currentStreaks[player] ?? 0;
    final banCount = squadState.getBanCount(player);
    final status = squadState.statuses[player] ?? 'Offline';

    String winIcon = 'assets/images/performance.png';
    if (streak >= 10)
      winIcon = 'assets/images/chicken.png';
    else if (streak >= 4)
      winIcon = 'assets/images/duck.png';
    else if (streak >= 3) winIcon = 'assets/images/turkey.png';

    return Semantics(
      label: 'Member: $player',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey[800]!)),
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
                      Image.asset(winIcon,
                          width: 20, height: 20, color: Colors.yellowAccent),
                      const SizedBox(width: 4),
                      Text('$streak',
                          style: const TextStyle(color: Colors.yellowAccent)),
                    ],
                  ),
                if (banCount > 0) ...[
                  const SizedBox(width: 12),
                  Row(
                    children: [
                      Image.asset('assets/images/sword.png',
                          width: 20, height: 20, color: Colors.redAccent),
                      const SizedBox(width: 4),
                      Text('$banCount',
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
              leading: Image.asset('assets/images/clear_all.png',
                  width: 24, height: 24, color: Colors.redAccent),
              title: const Text('Clear All Spots'),
              onTap: () {
                squadState.clearAllSpots();
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Image.asset('assets/images/timer_off.png',
                  width: 24, height: 24, color: Colors.blueGrey),
              title: const Text('Reset Timers'),
              onTap: () {
                squadState.resetTimers();
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Image.asset('assets/images/people_group.png',
                  width: 24, height: 24, color: Colors.cyanAccent),
              title: const Text('Manage Members'),
              onTap: () {
                Navigator.pop(context);
                _showMemberManagementDialog(context, squadState);
              },
            ),
            ListTile(
              leading: Image.asset('assets/images/sword.png',
                  width: 24, height: 24, color: Colors.redAccent),
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
              child: const Text('Close')),
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
              child: const Text('Close')),
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
            Image.asset('assets/images/sword.png',
                width: 24, height: 24, color: Colors.redAccent),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Select Member'),
                items: squadState.squadMembers
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
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (selectedPlayer != null) {
                squadState.addBan(selectedPlayer!, squadState.yourName);
                Navigator.pop(context);
              }
            },
            child: const Text('Ban'),
          ),
        ],
      ),
    );
  }

  void _assignOtherMember(
      BuildContext context, SquadState squadState, int index) {
    final yourName = squadState.yourName;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Assign Member'),
        content: Row(
          children: [
            Image.asset('assets/images/spot_assign.png',
                width: 24, height: 24, color: Colors.teal),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Select Player'),
                items: squadState.squadMembers
                    .where((player) =>
                        player != yourName &&
                        !squadState.squadSpots.contains(player))
                    .map((player) =>
                        DropdownMenuItem(value: player, child: Text(player)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    squadState.assignSpot(index);
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
              child: const Text('Cancel')),
        ],
      ),
    );
  }

  void _assignSpot(BuildContext context, SquadState squadState, int index) {
    squadState.assignSpot(index);
  }
}
