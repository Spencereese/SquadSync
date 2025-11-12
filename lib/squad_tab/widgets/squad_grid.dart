import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../squad_state.dart';
import '../dialogs/spot_assignment_dialog.dart';

/// SquadGrid component - handles the display of spot cards and assignment logic
/// Extracted from the monolithic SquadTab to improve maintainability
class SquadGrid extends StatelessWidget {
  const SquadGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SquadState>(
      builder: (context, squadState, child) {
        final maxSpots = squadState.currentGame?['maxSpots'] ?? 4;

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => SpotCard(
              key: ValueKey('spot_$index'),
              index: index,
              squadState: squadState,
            ),
            childCount: maxSpots,
          ),
        );
      },
    );
  }
}

/// SpotCard - Individual spot card widget with optimized rebuilds
class SpotCard extends StatelessWidget {
  final int index;
  final SquadState squadState;

  const SpotCard({
    super.key,
    required this.index,
    required this.squadState,
  });

  @override
  Widget build(BuildContext context) {
    final spotName = squadState.squadSpots[index];
    final hasOccupant = spotName != null;
    final yourName = squadState.displayName;
    final isReady = squadState.statuses[spotName] == 'Ready';

    // Check if any buttons will be shown
    final hasTimer = squadState.spotTimers[index] != null;
    final isCalling = squadState.statuses[spotName] == 'Calling';
    final hasCallButton = !hasOccupant;
    final hasLockButton =
        hasOccupant && hasTimer && isCalling && spotName == yourName;
    final hasWalkingButton =
        hasOccupant && hasTimer && isReady && spotName == yourName;
    final hasAnyButton = hasCallButton || hasLockButton || hasWalkingButton;

    return GestureDetector(
      onLongPress: () {
        if (hasOccupant) {
          squadState.removeSpot(index);
        } else {
          SpotAssignmentDialog.show(context, squadState, index);
        }
      },
      onTap: hasAnyButton
          ? null
          : () {
              if (!hasOccupant) {
                // Claim the empty spot
                squadState.claimSpot(index);
              } else if (hasOccupant && spotName == yourName) {
                final status = squadState.statuses[spotName];
                if (status == 'Ready') {
                  squadState.lockSpot(index);
                } else if (status != 'Calling') {
                  // Allow leaving spot by tapping when not ready and not calling
                  squadState.removeSpot(index);
                }
                // Don't remove spot when calling - let the Lock button handle it
              } else if (hasOccupant &&
                  squadState.squadSpots.contains(yourName)) {
                // You're already in a spot, allow assigning others
                SpotAssignmentDialog.show(context, squadState, index);
              }
            },
      child: Semantics(
        label:
            'Spot ${index + 1}: ${spotName ?? 'Open'}${spotName == yourName && !isReady ? ' (tap to leave)' : spotName == yourName && isReady ? ' (ready to lock)' : ''}',
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          color: Colors.white.withValues(alpha: 0.1),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  hasOccupant ? Colors.cyanAccent : Colors.grey[600],
              child: Text(
                hasOccupant ? spotName[0].toUpperCase() : '${index + 1}',
                style: TextStyle(
                    color: hasOccupant ? Colors.black : Colors.white,
                    fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(
              'Spot ${index + 1}: ${spotName ?? 'Open'}',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
            subtitle: _buildSpotSubtitle(context, index, spotName, squadState),
            trailing:
                _buildSpotActions(context, index, hasOccupant, squadState),
          ),
        ),
      ),
    );
  }

  Widget _buildSpotSubtitle(BuildContext context, int index, String? spotName,
      SquadState squadState) {
    final hasTimer = squadState.spotTimers[index] != null;
    final timerDisplay =
        hasTimer ? squadState.getSpotTimerDisplay(index) : null;
    final status =
        spotName != null ? squadState.statuses[spotName] ?? 'Occupied' : 'Open';
    final statusColor = _getSpotStatusColor(status);

    return Row(
      children: [
        Text(
          status,
          style: TextStyle(color: statusColor),
        ),
        if (timerDisplay != null && timerDisplay != '00:00') ...[
          const SizedBox(width: 8),
          Text(
            '($timerDisplay)',
            style: TextStyle(color: statusColor, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Color _getSpotStatusColor(String status) {
    switch (status) {
      case 'Ready':
        return Colors.greenAccent;
      case 'Calling':
        return Colors.orangeAccent;
      case 'Occupied':
        return Colors.white70;
      case 'Open':
        return Colors.grey;
      default:
        return Colors.white70;
    }
  }

  Widget _buildSpotActions(BuildContext context, int index, bool hasOccupant,
      SquadState squadState) {
    final spotName = squadState.squadSpots[index];
    final yourName = squadState.displayName;
    final hasTimer = squadState.spotTimers[index] != null;
    final isCalling = squadState.statuses[spotName] == 'Calling';
    final isReady = squadState.statuses[spotName] == 'Ready';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!hasOccupant)
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.tealAccent, Colors.teal],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.tealAccent.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: () => squadState.claimSpot(index),
              icon: const Icon(Icons.call, size: 16),
              label: const Text('Call'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.black,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                textStyle:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          )
        else if (hasOccupant && hasTimer && isCalling && spotName == yourName)
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.yellowAccent, Colors.orange],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.yellowAccent.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: () => squadState.lockSpot(index),
              icon: const Icon(Icons.lock, size: 16),
              label: const Text('Lock'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.black,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                textStyle:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          )
        else if (hasOccupant && hasTimer && isReady && spotName == yourName)
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.redAccent, Colors.red],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.redAccent.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: () => squadState.removeSpot(index),
              icon: const Icon(Icons.directions_walk, size: 16),
              label: const Text('Leave'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                textStyle:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }
}
