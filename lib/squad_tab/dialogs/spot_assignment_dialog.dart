import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squad_sync/presentation/notifiers/lobby_notifier.dart' as ln;

class SpotAssignmentDialog {
  static void show(BuildContext context, WidgetRef ref, int index) {
    final asyncState = ref.read(ln.lobbyNotifierProvider);
    if (asyncState is AsyncData) {
      final squadState = asyncState.value!;
      final gameName = squadState.currentGame?['name'] ?? '';
      final lobbyMemberUids = squadState.lobbyMemberUids;
      final memberDisplayNames = squadState.memberDisplayNames;
      final gameLobbySpots = squadState.gameLobbySpots[gameName] ?? [];

      final availablePlayers = lobbyMemberUids
          .where((uid) => !gameLobbySpots.contains(uid))
          .map((uid) => memberDisplayNames[uid] ?? 'Unknown')
          .toList();

      if (availablePlayers.isEmpty) return;

      final squadId = squadState.selectedLobbyId;
      if (squadId == null) return;

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
                      // Find the UID for the selected player
                      final uid = memberDisplayNames.entries
                          .firstWhere((entry) => entry.value == player)
                          .key;
                      ref
                          .read(ln.lobbyNotifierProvider.notifier)
                          .assignSpot(squadId, index, uid);
                      Navigator.pop(dialogContext);
                    },
                  )),
            ],
          ),
        ),
      );
    }
  }
}
