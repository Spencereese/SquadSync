import 'package:flutter/material.dart';
import '../../squad_state.dart';

class SpotAssignmentDialog {
  static void show(BuildContext context, SquadState squadState, int index) {
    final availablePlayers = squadState.getFilteredMembers
        .where((player) => !squadState.squadSpots.contains(player))
        .toList();

    if (availablePlayers.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (dialogContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.4,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        builder: (_, controller) => ListView(
          controller: controller,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Assign Spot ${index + 1}',
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            ...availablePlayers.map((player) => ListTile(
                  title: Text(player),
                  onTap: () {
                    squadState.assignSpot(index, player);
                    Navigator.pop(dialogContext);
                  },
                )),
          ],
        ),
      ),
    );
  }
}
