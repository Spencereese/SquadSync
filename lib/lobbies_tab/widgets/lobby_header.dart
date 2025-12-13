import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squad_sync/presentation/notifiers/lobby_notifier.dart' as ln;
import '../dialogs/settings_dialog.dart';

/// LobbyHeader component - handles navigation and game info display
/// Extracted from the monolithic LobbyTab to improve maintainability
class LobbyHeader extends ConsumerWidget {
  final String? lobbyId;

  const LobbyHeader({
    super.key,
    this.lobbyId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(
        top: 40.0, // Add top padding to avoid phone settings/clock
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Back button
              Semantics(
                label: 'Go back to lobby selection',
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Colors.cyanAccent,
                    size: 28,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Back to lobbies',
                ),
              ),

              // Centered game name - clickable to show game selection
              Expanded(
                child: GestureDetector(
                  onTap: () => _showGameSelectionDialog(context, ref),
                  child: Consumer(
                    builder: (context, ref, child) {
                      final squadStateAsync =
                          ref.watch(ln.lobbyNotifierProvider);
                      final gameName = squadStateAsync.maybeWhen(
                        data: (state) =>
                            state.currentGame?['name'] ?? 'Select Game',
                        orElse: () => 'Select Game',
                      );

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            gameName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_drop_down,
                            color: Colors.cyanAccent,
                            size: 24,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),

              // Settings button
              Semantics(
                label: 'Open squad settings',
                child: IconButton(
                  icon: Image.asset(
                    'assets/images/settings_gear.png',
                    width: 28,
                    height: 28,
                    color: Colors.grey[400],
                  ),
                  onPressed: () =>
                      SettingsDialog.show(context, ref, lobbyId: lobbyId),
                  tooltip: 'Settings',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showGameSelectionDialog(BuildContext context, WidgetRef ref) {
    final TextEditingController gameController = TextEditingController();
    Map<String, dynamic>? selectedGame; // ignore: unused_local_variable

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Colors.black.withValues(alpha: 0.9),
          title: const Text(
            'Switch Game',
            style: TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: gameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Search for a game...',
                    hintStyle: TextStyle(color: Colors.grey),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.cyanAccent),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.cyanAccent),
                    ),
                  ),
                  onChanged: (value) async {
                    if (value.isNotEmpty) {
                      // final gameManager = Provider.of<GameManager>(context, listen: false);
                      // final results = await gameManager.searchGames(value);
                      // if (results.isNotEmpty) {
                      //   setState(() {
                      //     selectedGame = results.first;
                      //   });
                      // }
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: null,
              child: Text(
                'Switch',
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
