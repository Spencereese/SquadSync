import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers.dart';
import '../dialogs/spot_assignment_dialog.dart';

/// SquadGrid component - handles the display of spot cards and assignment logic
/// Extracted from the monolithic SquadTab to improve maintainability
class SquadGrid extends ConsumerWidget {
  const SquadGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentGame = ref
        .watch(squadStateNotifierProvider.select((state) => state.currentGame));
    final maxSpots = currentGame?['maxSpots'] ?? 4;

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => SpotCard(
          key: ValueKey('spot_$index'),
          index: index,
        ),
        childCount: maxSpots,
      ),
    );
  }
}

/// SpotCard - Individual spot card widget with optimized rebuilds
class SpotCard extends ConsumerWidget {
  final int index;

  const SpotCard({
    super.key,
    required this.index,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameName = ref.watch(squadStateNotifierProvider
        .select((state) => state.currentGame?['name'] ?? ''));
    final squadSpots = ref.watch(squadStateNotifierProvider
        .select((state) => state.gameSquadSpots[gameName] ?? []));
    final spotTimers = ref.watch(squadStateNotifierProvider
        .select((state) => state.gameSpotTimers[gameName] ?? []));
    final globalStatuses = ref.watch(
        squadStateNotifierProvider.select((state) => state.globalStatuses));
    final displayName = ref
        .watch(squadStateNotifierProvider.select((state) => state.displayName));

    final spotName = index < squadSpots.length ? squadSpots[index] : null;
    final hasOccupant = spotName != null;
    final yourName = displayName;
    final isReady = globalStatuses[spotName] == 'Ready';

    // Check if any buttons will be shown
    final hasTimer = index < spotTimers.length && spotTimers[index] != null;
    final isCalling = globalStatuses[spotName] == 'Calling';
    final hasCallButton = !hasOccupant;
    final hasLockButton =
        hasOccupant && hasTimer && isCalling && spotName == yourName;
    final hasWalkingButton =
        hasOccupant && hasTimer && isReady && spotName == yourName;
    final hasAnyButton = hasCallButton || hasLockButton || hasWalkingButton;

    return GestureDetector(
      onLongPress: () {
        if (hasOccupant) {
          ref
              .read(squadStateNotifierProvider.notifier)
              .removeSpot(gameName, index);
        } else {
          SpotAssignmentDialog.show(context, ref, index);
        }
      },
      onTap: hasAnyButton
          ? null
          : () {
              if (!hasOccupant) {
                // Claim the empty spot
                ref
                    .read(squadStateNotifierProvider.notifier)
                    .claimSpot(gameName, index);
              } else if (hasOccupant && spotName == yourName) {
                final status = globalStatuses[spotName];
                if (status == 'Ready') {
                  ref
                      .read(squadStateNotifierProvider.notifier)
                      .lockSpot(gameName, index);
                } else if (status != 'Calling') {
                  // Allow leaving spot by tapping when not ready and not calling
                  ref
                      .read(squadStateNotifierProvider.notifier)
                      .removeSpot(gameName, index);
                }
                // Don't remove spot when calling - let the Lock button handle it
              } else if (hasOccupant && squadSpots.contains(yourName)) {
                // You're already in a spot, allow assigning others
                SpotAssignmentDialog.show(context, ref, index);
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
            subtitle: _buildSpotSubtitle(
                context, index, spotName, spotTimers, globalStatuses),
            trailing: _buildSpotActions(context, index, hasOccupant, spotName,
                displayName, spotTimers, globalStatuses, ref, gameName),
          ),
        ),
      ),
    );
  }

  Widget _buildSpotSubtitle(
      BuildContext context,
      int index,
      String? spotName,
      List<Map<String, dynamic>?> spotTimers,
      Map<String, String> globalStatuses) {
    final hasTimer = spotTimers[index] != null;
    final timerDisplay = hasTimer ? _getTimerDisplay(spotTimers[index]) : null;
    final status =
        spotName != null ? globalStatuses[spotName] ?? 'Occupied' : 'Open';
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

  String? _getTimerDisplay(Map<String, dynamic>? timer) {
    if (timer == null) return null;
    // Simple implementation - could be enhanced
    final endTime = timer['endTime'];
    if (endTime is DateTime) {
      final remaining = endTime.difference(DateTime.now());
      if (remaining.isNegative) return 'Expired';
      return '${remaining.inMinutes}m ${remaining.inSeconds % 60}s';
    }
    return 'Timer';
  }

  Widget _buildSpotActions(
      BuildContext context,
      int index,
      bool hasOccupant,
      String? spotName,
      String displayName,
      List<Map<String, dynamic>?> spotTimers,
      Map<String, String> globalStatuses,
      WidgetRef ref,
      String gameName) {
    final yourName = displayName;
    final hasTimer = spotTimers[index] != null;
    final isCalling = globalStatuses[spotName] == 'Calling';
    final isReady = globalStatuses[spotName] == 'Ready';

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
              onPressed: () => ref
                  .read(squadStateNotifierProvider.notifier)
                  .claimSpot(gameName, index),
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
              onPressed: () => ref
                  .read(squadStateNotifierProvider.notifier)
                  .lockSpot(gameName, index),
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
              onPressed: () => ref
                  .read(squadStateNotifierProvider.notifier)
                  .removeSpot(gameName, index),
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
