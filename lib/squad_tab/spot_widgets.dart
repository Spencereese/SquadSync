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
                _buildSpotActions(context, index, hasOccupant, squadState,
                    showSpotAssignmentMenu),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildSpotInfo(BuildContext context, int index,
      String? spotName, SquadState squadState) {
    final hasTimer = squadState.spotTimers[index] != null;
    final timerDisplay =
        hasTimer ? squadState.getSpotTimerDisplay(index) : null;

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
                if (hasTimer && timerDisplay != null && timerDisplay != '00:00')
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Time: $timerDisplay',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.orange,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
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
            onPressed: () => squadState.callSpotForGame(index, gameName),
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
            onPressed: () => squadState.lockCalledSpot(gameName, index),
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
            onPressed: () => squadState.removeSpot(index),
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
