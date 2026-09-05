import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squad_sync/presentation/notifiers/lobby_notifier.dart' as ln;
import '../../core/deep_link_routes.dart';
import '../../core/voice_room_join.dart';
import '../dialogs/settings_dialog.dart';
import '../../widgets/unified_game_selection_sheet.dart';
import '../../domain/entities/game.dart';
import 'lobby_seat_affordance.dart';
import 'match_history_badge.dart';

/// LobbyHeader — back, game, Voice join, share, settings.
/// Voice join uses [openVoiceRoom] (existing VoiceRoomScreen, no restyle).
class LobbyHeader extends ConsumerWidget {
  final String? lobbyId;

  const LobbyHeader({
    super.key,
    this.lobbyId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top,
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
                          const SizedBox(height: 4),
                          const LobbySeatStatusChipHost(),
                        ],
                      );
                    },
                  ),
                ),
              ),

              if (_nonEmptyLobbyId(lobbyId) != null)
                LobbyVoiceJoinButton(
                  onPressed: () => _joinVoiceRoom(context, ref, lobbyId!),
                ),

              if (_nonEmptyLobbyId(lobbyId) != null)
                LobbyShareButton(
                  onPressed: () => _shareLobbyLink(context, lobbyId!),
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

  void _joinVoiceRoom(BuildContext context, WidgetRef ref, String lobbyId) {
    HapticFeedback.lightImpact();
    var squadName = kDefaultVoiceSquadName;
    try {
      final name = ref
          .read(ln.lobbyNotifierProvider)
          .valueOrNull
          ?.currentLobby
          ?.name
          .trim();
      if (name != null && name.isNotEmpty) squadName = name;
    } catch (_) {}
    openVoiceRoom(
      context: context,
      roomId: lobbyId,
      squadName: squadName,
    );
  }

  Future<void> _shareLobbyLink(BuildContext context, String lobbyId) async {
    HapticFeedback.lightImpact();
    try {
      await shareLobbyLink(lobbyId: lobbyId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lobby link copied'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not share lobby link: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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

String? _nonEmptyLobbyId(String? lobbyId) {
  final id = lobbyId?.trim();
  if (id == null || id.isEmpty) return null;
  return id;
}

/// Lobby header share. Live path calls [shareLobbyLink].
class LobbyShareButton extends StatelessWidget {
  const LobbyShareButton({
    super.key,
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Share lobby link',
      child: IconButton(
        key: const Key('lobby-share-link'),
        icon: const Icon(
          Icons.share,
          color: Colors.cyanAccent,
          size: 26,
        ),
        onPressed: onPressed,
        tooltip: 'Share lobby',
      ),
    );
  }
}

/// Lobby header Voice join. Live path calls [openVoiceRoom].
class LobbyVoiceJoinButton extends StatelessWidget {
  const LobbyVoiceJoinButton({
    super.key,
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Join voice room',
      child: IconButton(
        key: const Key('lobby-voice-join'),
        icon: const Icon(
          Icons.headset,
          color: Colors.cyanAccent,
          size: 26,
        ),
        onPressed: onPressed,
        tooltip: 'Join voice',
      ),
    );
  }
}
