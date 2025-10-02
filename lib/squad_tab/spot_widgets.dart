import 'package:flutter/material.dart';
import '../squad_state.dart';
import 'member_widgets.dart';

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

    return GestureDetector(
      onLongPress: () {
        if (hasOccupant) {
          squadState.removeSpot(index);
        } else {
          showSpotAssignmentMenu(context, squadState, index);
        }
      },
      onTap: () {
        if (!hasOccupant && squadState.squadSpots.contains(yourName)) {
          assignOtherMember(context, squadState, index);
        } else if (hasOccupant && spotName == yourName && isReady) {
          squadState.lockSpot(index);
        }
      },
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
                  MemberWidgets.buildPlayerStatusRow(
                      context, spotName, squadState),
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
    final isReady = squadState.statuses[spotName] == 'Ready';
    final youAreAssigned = squadState.squadSpots.contains(yourName);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!hasOccupant)
          GestureDetector(
            onLongPress: () {
              showSpotAssignmentMenu(context, squadState, index);
            },
            child: ElevatedButton(
              onPressed: () {
                if (youAreAssigned) {
                  // This would need to be passed from parent
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
                message: 'Tap to claim, hold to assign others',
                child: Text('Claim'),
              ),
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
}
