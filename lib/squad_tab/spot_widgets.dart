import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../squad_state.dart';
import '../services/timer_service.dart';
import 'dialogs/spot_assignment_dialog.dart';

class SpotTimerDisplay extends ConsumerStatefulWidget {
  final int index;
  final SquadState squadState;

  const SpotTimerDisplay({
    super.key,
    required this.index,
    required this.squadState,
  });

  @override
  ConsumerState<SpotTimerDisplay> createState() => _SpotTimerDisplayState();
}

class _SpotTimerDisplayState extends ConsumerState<SpotTimerDisplay> {
  Duration? _totalDuration;
  bool _hasExpired = false;

  @override
  void didUpdateWidget(SpotTimerDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateTotalDuration();
  }

  void _updateTotalDuration() {
    final timer = widget.squadState.spotTimers[widget.index];
    if (timer != null) {
      _totalDuration = Duration(seconds: timer['duration'] as int? ?? 0);
    } else {
      _totalDuration = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameName = widget.squadState.currentGame?['name'] ?? '';
    final key = 'spot_${gameName}_${widget.index}';
    final timerService = ref.watch(timerServiceProvider);

    return StreamBuilder<Duration>(
      stream: timerService.observeTimer(key),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            width: 60,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }

        final remaining = snapshot.data ?? Duration.zero;
        final progress = _totalDuration != null && _totalDuration!.inSeconds > 0
            ? remaining.inSeconds / _totalDuration!.inSeconds
            : 0.0;

        // Update formatted time
        final minutes = remaining.inMinutes;
        final seconds = remaining.inSeconds % 60;
        final formatted =
            '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

        // Haptic feedback on expiration
        if (remaining == Duration.zero && !_hasExpired) {
          _hasExpired = true;
          HapticFeedback.vibrate();
        } else if (remaining > Duration.zero) {
          _hasExpired = false;
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formatted,
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 60,
              height: 4,
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

class SpotWidgets {
  static Widget buildSpotCard(
      BuildContext context,
      int index,
      SquadState squadState,
      Function(BuildContext, SquadState, int) assignOtherMember) {
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
                assignOtherMember(context, squadState, index);
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

  static Widget _buildSpotSubtitle(BuildContext context, int index,
      String? spotName, SquadState squadState) {
    final hasTimer = squadState.spotTimers[index] != null;
    final status =
        spotName != null ? squadState.statuses[spotName] ?? 'Occupied' : 'Open';
    final statusColor = _getSpotStatusColor(status);

    return Row(
      children: [
        Text(
          status,
          style: TextStyle(color: statusColor),
        ),
        if (hasTimer) ...[
          const SizedBox(width: 8),
          SpotTimerDisplay(index: index, squadState: squadState),
        ],
      ],
    );
  }

  static Color _getSpotStatusColor(String status) {
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

  static Widget _buildSpotActions(BuildContext context, int index,
      bool hasOccupant, SquadState squadState) {
    final spotName = squadState.squadSpots[index];
    final yourName = squadState.displayName;
    final hasTimer = squadState.spotTimers[index] != null;
    final isCalling = squadState.statuses[spotName] == 'Calling';
    final isReady = squadState.statuses[spotName] == 'Ready';
    final gameName = squadState.currentGame?['name'] ?? '';

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
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () {
                try {
                  squadState.callSpotForGame(index, gameName);
                } catch (e) {
                  // Handle error silently
                }
              },
              onLongPress: () =>
                  SpotAssignmentDialog.show(context, squadState, index),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.call, size: 16, color: Colors.black),
                  const SizedBox(width: 6),
                  const Text('Call',
                      style: TextStyle(
                          color: Colors.black, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        if (hasOccupant && hasTimer && isCalling && spotName == yourName)
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.orangeAccent, Colors.deepOrange],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.orangeAccent.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () {
                try {
                  squadState.lockCalledSpot(gameName, index);
                } catch (e) {
                  // Handle error silently
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock, size: 16, color: Colors.white),
                  const SizedBox(width: 6),
                  const Text('Lock',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        if (hasOccupant && hasTimer && isReady && spotName == yourName)
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
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () {
                try {
                  squadState.removeSpot(index);
                } catch (e) {
                  // Handle error silently
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.exit_to_app, size: 16, color: Colors.white),
                  const SizedBox(width: 6),
                  const Text('Leave',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        // Removed "Leave" button - players lose spots automatically after 5 minutes if not locked
      ],
    );
  }
}
