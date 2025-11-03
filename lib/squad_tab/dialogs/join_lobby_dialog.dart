import 'package:flutter/material.dart';
import '../../squad_state.dart';
import 'base_dialog.dart';

/// Dialog for joining lobbies with other players
class JoinLobbyDialog extends BaseSquadDialog {
  final String player;
  final SquadState squadState;

  const JoinLobbyDialog({
    super.key,
    required this.player,
    required this.squadState,
  });

  @override
  Widget build(BuildContext context) {
    final visibleLobbies =
        squadState.getVisibleLobbies(squadState.currentGame?['name'] ?? '');

    return AlertDialog(
      shape: BaseSquadDialog.dialogShape,
      title: Text('Join Lobby with $player'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: visibleLobbies.length,
          itemBuilder: (context, index) {
            final lobby = visibleLobbies[index];
            final host = lobby['host'] ?? 'Unknown';
            final players = List<String>.from(lobby['players'] ?? []);
            final game = lobby['game'] ?? 'Unknown';

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                title: Text('$game Lobby - Host: $host'),
                subtitle:
                    Text('${players.length} players: ${players.join(', ')}'),
                trailing: ElevatedButton(
                  onPressed: () {
                    squadState.joinLobby(
                        lobby['id'], squadState.displayName ?? '');
                    // Defer navigation to avoid _debugLocked assertion
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }
                    });
                  },
                  child: const Text('Join'),
                ),
              ),
            );
          },
        ),
      ),
      actions: BaseSquadDialog.dialogActions(
        context: context,
        actions: [
          BaseSquadDialog.cancelButton(context),
        ],
      ),
    );
  }

  /// Static method to show the dialog (maintains compatibility)
  static void show(BuildContext context, String player, SquadState squadState) {
    showDialog(
      context: context,
      builder: (dialogContext) => JoinLobbyDialog(
        player: player,
        squadState: squadState,
      ),
    );
  }
}
