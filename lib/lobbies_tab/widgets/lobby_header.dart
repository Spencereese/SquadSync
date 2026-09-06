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
/// Voice join uses [joinVoiceRoom] (existing VoiceRoomScreen, no restyle).
class LobbyHeader extends ConsumerWidget {
  final String? lobbyId;

  const LobbyHeader({
    super.key,
    this.lobbyId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOffline = ref.watch(ln.lobbyNotifierProvider).hasError;
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

              LobbyVoiceJoinHost(
                lobbyId: lobbyId,
                squadName: _voiceSquadName(ref),
                isOffline: ref.watch(ln.lobbyNotifierProvider).hasError,
              ),

              LobbyShareButton(
                onPressed: () => _shareLobbyLink(
                  context,
                  lobbyId,
                  isOffline: isOffline,
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

  String _voiceSquadName(WidgetRef ref) {
    try {
      final name = ref
          .read(ln.lobbyNotifierProvider)
          .valueOrNull
          ?.currentLobby
          ?.name
          .trim();
      if (name != null && name.isNotEmpty) return name;
    } catch (_) {}
    return kDefaultVoiceSquadName;
  }

  Future<void> _shareLobbyLink(
    BuildContext context,
    String? lobbyId, {
    bool isOffline = false,
  }) async {
    HapticFeedback.lightImpact();
    final result = await shareLobbyLink(
      lobbyId: lobbyId,
      isOffline: isOffline,
    );
    if (!context.mounted) return;
    presentLobbyShare(context, result);
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

/// Live Voice join on the lobby header. Empty / offline copy, reconnect
/// toast after drop, no stacked [VoiceRoomScreen]. Never a spinner.
class LobbyVoiceJoinHost extends StatefulWidget {
  const LobbyVoiceJoinHost({
    super.key,
    this.lobbyId,
    this.squadName = kDefaultVoiceSquadName,
    this.isHost = false,
    this.isOffline = false,
    this.session,
    this.push,
  });

  final String? lobbyId;
  final String squadName;
  final bool isHost;
  final bool isOffline;
  final VoiceJoinSession? session;
  final Future<void> Function(Widget page)? push;

  @override
  State<LobbyVoiceJoinHost> createState() => _LobbyVoiceJoinHostState();
}

class _LobbyVoiceJoinHostState extends State<LobbyVoiceJoinHost> {
  VoiceLobbyHeaderPhase? _lastPhase;

  VoiceJoinSession get _session => widget.session ?? voiceJoinSession;

  VoiceLobbyHeaderPhase get _phase => resolveVoiceLobbyHeaderPhase(
        lobbyId: widget.lobbyId,
        isOffline: widget.isOffline,
        isJoined: _session.isJoined,
        isJoining: _session.isJoining,
        isDropped: _session.isDropped,
      );

  void _maybeReconnectToast({
    required VoiceLobbyHeaderPhase? previous,
    required VoiceLobbyHeaderPhase current,
  }) {
    if (!shouldShowVoiceReconnectToast(
      previous: previous,
      current: current,
      voiceDrop: _session.isDropped,
    )) {
      return;
    }
    if (!voiceReconnectToastGate.claim(now: DateTime.now().toUtc())) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;
      messenger.showSnackBar(voiceReconnectSnackBar());
    });
  }

  Future<void> _onPressed() async {
    HapticFeedback.lightImpact();
    final result = await joinVoiceRoom(
      roomId: widget.lobbyId,
      squadName: widget.squadName,
      isHost: widget.isHost,
      context: widget.push == null ? context : null,
      push: widget.push,
      session: _session,
      isOffline: widget.isOffline,
    );
    if (!mounted) return;
    presentVoiceLobbyJoin(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _session,
      builder: (context, _) {
        final phase = _phase;
        final previous = _lastPhase;
        _lastPhase = phase;
        _maybeReconnectToast(previous: previous, current: phase);
        return LobbyVoiceJoinButton(
          phase: phase,
          onPressed: _onPressed,
        );
      },
    );
  }
}

/// Lobby header Voice join. Live path calls [joinVoiceRoom].
class LobbyVoiceJoinButton extends StatelessWidget {
  const LobbyVoiceJoinButton({
    super.key,
    required this.onPressed,
    this.phase = VoiceLobbyHeaderPhase.ready,
  });

  final VoidCallback onPressed;
  final VoiceLobbyHeaderPhase phase;

  @override
  Widget build(BuildContext context) {
    final copy = voiceLobbyHeaderMessage(phase);
    Widget button = IconButton(
      key: const Key('lobby-voice-join'),
      icon: const Icon(
        Icons.headset,
        color: Colors.cyanAccent,
        size: 26,
      ),
      onPressed: onPressed,
      tooltip: copy,
    );
    if (phase != VoiceLobbyHeaderPhase.ready) {
      button = KeyedSubtree(key: voiceLobbyHeaderKey(phase), child: button);
    }
    return Semantics(
      label: copy == 'Join voice' ? 'Join voice room' : copy,
      child: button,
    );
  }
}
