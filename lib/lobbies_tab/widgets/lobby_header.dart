import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squad_sync/presentation/notifiers/lobby_notifier.dart' as ln;
import '../dialogs/settings_dialog.dart';
import '../../widgets/unified_game_selection_sheet.dart';
import '../../domain/entities/game.dart';
import 'match_history_badge.dart';

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

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
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
                          ),
                          // Match history stats badge
                          if (lobbyId != null) ...[
                            const SizedBox(height: 4),
                            MatchHistoryBadge(lobbyId: lobbyId!),
                          ],
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

  void _showGameSelectionDialog(BuildContext context, WidgetRef ref) async {
    HapticFeedback.lightImpact();

    await UnifiedGameSelectionSheet.show(
      context,
      title: 'Switch Game',
      subtitle: 'Select a different game for this lobby',
      showPinnedGames: true,
      showSearchButton: true,
      showMaxSpotSelector: false,
      onGameSelected: (Game game) async {
        try {
          // Update the lobby's current game
          await ref
              .read(ln.lobbyNotifierProvider.notifier)
              .setCurrentGame(game.toJson());

          if (context.mounted) {
            HapticFeedback.mediumImpact();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Switched to ${game.name}'),
                backgroundColor: Theme.of(context).colorScheme.primary,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to switch game: $e'),
                backgroundColor: Theme.of(context).colorScheme.error,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }
        }
      },
    );
  }
}
