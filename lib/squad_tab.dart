import 'package:flutter/material.dart';
import 'squad_queue.dart';
import 'utils.dart';

class SquadTab extends StatelessWidget {
  final SquadQueuePageState state;

  const SquadTab({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSquadSpots(context),
            _buildPeacockSpot(context),
            _buildActionButtons(context),
            _buildSquadMembersList(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSquadSpots(BuildContext context) {
    return Column(
      children: List.generate(4, (index) => _buildSpotCard(context, index)),
    );
  }

  Widget _buildSpotCard(BuildContext context, int index) {
    final spotName = state.squadSpots[index];
    final hasOccupant = spotName != null;

    return GestureDetector(
      onLongPress: () =>
          hasOccupant ? state.removeSpot(index) : state.assignSpot(index),
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSpotInfo(context, index, spotName),
              _buildSpotActions(index, hasOccupant),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpotInfo(BuildContext context, int index, String? spotName) {
    return Row(
      children: [
        Text('Spot ${index + 1}: ',
            style: Theme.of(context).textTheme.titleLarge),
        Text(spotName ?? 'Open', style: Theme.of(context).textTheme.bodyMedium),
        if (spotName != null) ...[
          const SizedBox(width: 8),
          _buildStatusText(context, spotName),
          if (state.spotTimers[index] != null) ...[
            const SizedBox(width: 8),
            Text('(${formatTimer(state.spotTimers[index])})',
                style: Theme.of(context).textTheme.bodyMedium),
          ],
          if (state.statuses[spotName] == 'Walking') ...[
            const SizedBox(width: 8),
            buildBadge(state.currentStreaks[spotName] ?? 0),
            const SizedBox(width: 4),
            _buildStreakText(spotName),
          ],
        ],
      ],
    );
  }

  Widget _buildSpotActions(int index, bool hasOccupant) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!hasOccupant)
          ElevatedButton(
            onPressed: () => state.claimSpot(index),
            child: const Text('Claim'),
          ),
        if (hasOccupant && state.spotTimers[index] != null)
          ElevatedButton(
            onPressed: () => state.lockSpot(index),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
            child: const Text('Lock'),
          ),
      ],
    );
  }

  Widget _buildPeacockSpot(BuildContext context) {
    return GestureDetector(
      onTap: () => state.claimPeacockDialog(context),
      onLongPress: () => state.managePeacock(),
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildPeacockInfo(context),
              ElevatedButton(
                onPressed: () => state.claimPeacock(),
                child: const Text('Claim'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeacockInfo(BuildContext context) {
    return Row(
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
    );
  }

  Widget _buildPeacockStatus(BuildContext context) {
    if (state.peacockTimers.isEmpty && state.peacockQueue.isEmpty) {
      return const Text('Open', style: TextStyle(color: Colors.white));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ...state.peacockTimers.entries
            .where((e) => e.value != null)
            .map((entry) => _buildPeacockTimerRow(context, entry))
            .toList(),
        ...state.peacockQueue
            .map((player) => _buildPeacockQueueRow(context, player))
            .toList(),
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
        const Text('Strutting',
            style: TextStyle(color: Colors.blueAccent, fontSize: 12)),
        const SizedBox(width: 8),
        Text(
          remainingTime > 0 ? '(${formatTimer(remainingTime)})' : '(Expired)',
          style: Theme.of(context).textTheme.bodyMedium,
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
        Text('Waiting',
            style: TextStyle(color: Colors.grey[400], fontSize: 12)),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton.icon(
            onPressed: () => state.recordWin(),
            icon: Image.asset('assets/images/check.png', width: 24, height: 24),
            label: const Text('Win'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
          ElevatedButton.icon(
            onPressed: () => state.recordLoss(),
            icon: Image.asset('assets/images/close.png', width: 24, height: 24),
            label: const Text('Loss'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
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
        if (state.squadMembers.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text('No squad members yet',
                style: TextStyle(color: Colors.grey)),
          )
        else
          ...state.squadMembers
              .map((player) => _buildMemberCard(context, player)),
      ],
    );
  }

  Widget _buildMemberCard(BuildContext context, String player) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(player, style: Theme.of(context).textTheme.bodyMedium),
            Row(
              children: [
                _buildStatusText(context, player),
                if (state.statuses[player] == 'Walking') ...[
                  const SizedBox(width: 8),
                  buildBadge(state.currentStreaks[player] ?? 0),
                  const SizedBox(width: 4),
                ],
                _buildStreakText(player),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusText(BuildContext context, String player) {
    final status = state.statuses[player] ?? 'Offline';
    return Text(
      status,
      style: TextStyle(
        color: status == 'Strutting'
            ? Colors.blueAccent
            : status == 'Walking'
                ? Colors.greenAccent
                : status == 'Ready'
                    ? Colors.yellowAccent
                    : Colors.grey[400],
        fontSize: 12,
      ),
    );
  }

  Widget _buildStreakText(String player) {
    return Text(
      '${state.currentStreaks[player] ?? 0}',
      style: const TextStyle(color: Colors.cyanAccent, fontSize: 12),
    );
  }
}
