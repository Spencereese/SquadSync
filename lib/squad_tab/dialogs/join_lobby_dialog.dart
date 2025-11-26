import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../presentation/notifiers/squad_notifier.dart' as sn;

/// Dialog for joining lobbies with other players
class JoinLobbyDialog extends ConsumerWidget {
  final String player;

  const JoinLobbyDialog({
    super.key,
    required this.player,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final squadState = ref.watch(sn.squadNotifierProvider).valueOrNull;
    if (squadState == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final visibleLobbies =
        squadState.gameLobbies.values.expand((l) => l).toList();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                    final userId = FirebaseAuth.instance.currentUser!.uid;
                    ref
                        .read(sn.squadNotifierProvider.notifier)
                        .joinSquad(lobby['id'], userId);
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
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  /// Static method to show the dialog
  static void show(BuildContext context, String player) {
    showDialog(
      context: context,
      builder: (dialogContext) => JoinLobbyDialog(
        player: player,
      ),
    );
  }
}
