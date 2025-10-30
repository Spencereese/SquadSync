import 'package:flutter/material.dart';
import '../squad_state.dart';

class SpotWidgets {
  static Widget buildSpotCard(
      BuildContext context,
      int index,
      SquadState squadState,
      Function(BuildContext, SquadState, int) showSpotAssignmentMenu,
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
          showSpotAssignmentMenu(context, squadState, index);
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
            trailing: _buildSpotActions(context, index, hasOccupant, squadState,
                showSpotAssignmentMenu),
          ),
        ),
      ),
    );
  }

  static Widget _buildSpotSubtitle(BuildContext context, int index,
      String? spotName, SquadState squadState) {
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

  static Widget _buildSpotActions(
      BuildContext context,
      int index,
      bool hasOccupant,
      SquadState squadState,
      Function(BuildContext, SquadState, int) showSpotAssignmentMenu) {
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
          ElevatedButton(
            onPressed: () {
              debugPrint('Call button pressed for spot $index');
              try {
                squadState.callSpotForGame(index, gameName);
                debugPrint('Call button action completed for spot $index');
              } catch (e) {
                debugPrint('Call button failed for spot $index: $e');
              }
            },
            onLongPress: () =>
                showSpotAssignmentMenu(context, squadState, index),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 6,
            ),
            child: const Tooltip(
              message: 'Tap to call, hold to assign others',
              child: Text('Call'),
            ),
          ),
        if (hasOccupant && hasTimer && isCalling && spotName == yourName)
          ElevatedButton(
            onPressed: () {
              debugPrint('Lock button pressed for spot $index');
              try {
                squadState.lockCalledSpot(gameName, index);
                debugPrint('Lock button action completed for spot $index');
              } catch (e) {
                debugPrint('Lock button failed for spot $index: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 6,
            ),
            child: const Tooltip(
              message: 'Lock in your spot',
              child: Text('Lock'),
            ),
          ),
        if (hasOccupant && hasTimer && isReady && spotName == yourName)
          ElevatedButton(
            onPressed: () {
              debugPrint('Leave button pressed for spot $index');
              try {
                squadState.removeSpot(index);
                debugPrint('Leave button action completed for spot $index');
              } catch (e) {
                debugPrint('Leave button failed for spot $index: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 6,
            ),
            child: const Tooltip(
              message: 'Leave your spot',
              child: Text('Leave'),
            ),
          ),
        // Removed "Leave" button - players lose spots automatically after 5 minutes if not locked
      ],
    );
  }
}
