import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../chat/screens/components/chat_info_actions.dart';
import '../../core/deep_link_routes.dart';
import '../../core/voice_room_join.dart';
import '../../domain/entities/lobby.dart';
import '../../presentation/notifiers/lobby_notifier.dart' as ln;
import '../../services/auth_service_supabase.dart';
import '../../services/availability_ping.dart';
import '../../services/session_rating_flow.dart';
import '../../services/session_rating_machine.dart';
import '../../screens/discovery_swipe_screen.dart';
import '../../widgets/discovery_swipe_gate.dart';
import '../../widgets/grok_concierge.dart';
import '../../widgets/lobby_surface_feedback.dart';

/// LobbyControls — Tonight strip (I am on / Looking for Squad / Invite),
/// Grok concierge (three commands), gated fill swipe, Win/Loss, Voice under More.
/// Search is not an entry. No free-chat field. No public Tinder launch.
class LobbyControls extends ConsumerWidget {
  const LobbyControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lobbyAsync = ref.watch(ln.lobbyNotifierProvider);
    final tonightPhase = lobbySurfacePhaseFromAsync(
      lobbyAsync,
      isEmpty: tonightLobbyMissing,
    );
    final tonightError = lobbyAsyncError(lobbyAsync);
    final tonightChildren = tonightPhase == LobbySurfacePhase.data
        ? tonightStripChildren(
            onNow: const _OnNowButton(),
            lookingForSquad: const _LobbyLookingForSquad(),
            invite: const _LobbyInviteButton(),
          )
        : const <Widget>[];

    return SliverToBoxAdapter(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _WinButton(),
                _LossButton(),
              ],
            ),
          ),
          TonightActionsBlock(
            isLoading: tonightPhase == LobbySurfacePhase.loading,
            isEmpty: tonightPhase == LobbySurfacePhase.empty,
            error: tonightError,
            children: tonightChildren,
          ),
          const SizedBox(height: 16),
          GrokConciergeSection(
            squadId: lobbyAsync.valueOrNull?.currentLobby?.chatGroupId ??
                lobbyAsync.valueOrNull?.selectedLobbyId ??
                lobbyAsync.valueOrNull?.currentLobby?.id ??
                '',
          ),
          DiscoverySwipeEntryButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const DiscoverySwipeScreen(),
                ),
              );
            },
          ),
          MoreActionsBlock(
            children: [
              if (slotForTonightAction(kMoreVoiceAction) ==
                  TonightStripSlot.more)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Center(
                    child: _VoiceRoomButton(key: Key('more-voice')),
                  ),
                ),
              if (slotForTonightAction(kDeadSearchAction) != null)
                const SizedBox.shrink(),
            ],
          ),
        ],
      ),
    );
  }
}

/// Looking for Squad on the lobby Tonight strip. Same live button as chat-info.
class _LobbyLookingForSquad extends ConsumerWidget {
  const _LobbyLookingForSquad();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ln.lobbyNotifierProvider).valueOrNull;
    final lobby = state?.currentLobby;
    final squadId =
        lobby?.chatGroupId ?? state?.selectedLobbyId ?? lobby?.id ?? '';
    if (squadId.isEmpty) {
      return const SizedBox.shrink();
    }
    return LookingForSquadButton(
      key: const Key('tonight-looking-for-squad'),
      squadId: squadId,
      neonColor: Theme.of(context).colorScheme.primary,
    );
  }
}

/// Tonight Invite — [shareLobbyLink], same helper as lobby header.
class _LobbyInviteButton extends ConsumerWidget {
  const _LobbyInviteButton();

  Future<void> _onPressed(BuildContext context, WidgetRef ref) async {
    Lobby? currentLobby;
    String? selectedLobbyId;
    Map<String, Lobby> userLobbies = const {};
    try {
      final state = ref.read(ln.lobbyNotifierProvider).valueOrNull;
      selectedLobbyId = state?.selectedLobbyId;
      currentLobby = state?.currentLobby;
      userLobbies = state?.userLobbies ?? const {};
    } catch (_) {}

    final lobbyId = resolveInviteLobbyId(
      squadId: selectedLobbyId ?? currentLobby?.id ?? '',
      selectedLobbyId: selectedLobbyId,
      currentLobby: currentLobby,
      userLobbies: userLobbies,
    );
    if (lobbyId.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No lobby selected')),
        );
      }
      return;
    }

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          key: const Key('tonight-invite'),
          onPressed: () => _onPressed(context, ref),
          icon: const Icon(Icons.share, size: 20),
          label: const Text(
            'Invite',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(fontSize: 18),
            elevation: 4,
          ),
        ),
      ),
    );
  }
}

/// "I'm on now" from the lobby tab. Same [AvailabilityPing.dispatch]
/// path as Looking-for-Squad chat info.
class _OnNowButton extends ConsumerStatefulWidget {
  const _OnNowButton();

  @override
  ConsumerState<_OnNowButton> createState() => _OnNowButtonState();
}

class _OnNowButtonState extends ConsumerState<_OnNowButton> {
  bool _isLoading = false;

  Future<void> _onPressed() async {
    String? uid;
    try {
      uid = AuthServiceSupabase().currentUser?.id;
    } catch (_) {
      uid = null;
    }
    if (uid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sign in to ping your squad'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final state = ref.read(ln.lobbyNotifierProvider).valueOrNull;
    final lobbyId = state?.selectedLobbyId ?? state?.currentLobby?.id;
    if (lobbyId == null || lobbyId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No lobby selected')),
        );
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await AvailabilityPing.dispatch(
        senderUid: uid,
        lobbyId: lobbyId,
        currentLobby: state?.currentLobby,
        userLobbies: state?.userLobbies ?? const {},
        lobbyMemberUids: state?.lobbyMemberUids ?? const [],
        gameName: state?.currentGame?['name'] as String? ??
            state?.currentLobby?.gameName,
        senderName: state?.displayName,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.snackbarMessage),
          backgroundColor: result.sent ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to ping: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final squadStateAsync = ref.watch(ln.lobbyNotifierProvider);
    final hasLobby = squadStateAsync.maybeWhen(
      data: (state) =>
          (state.selectedLobbyId ?? state.currentLobby?.id) != null,
      orElse: () => false,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          key: const Key('lobby-availability-on-now'),
          onPressed: _isLoading || !hasLobby ? null : _onPressed,
          icon: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.campaign, size: 20),
          label: const Text(
            "I'm on now",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(fontSize: 18),
            elevation: 4,
          ),
        ),
      ),
    );
  }
}

/// Win button widget
class _WinButton extends ConsumerWidget {
  const _WinButton();

  Future<void> _showWinConfirmation(
      BuildContext context, WidgetRef ref, String lobbyId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Record Win'),
        content: const Text('Record a win for this lobby?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Record Win'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final rating = await promptAndRecordEndedSession(
          context: context,
          ref: ref,
          lobbyId: lobbyId,
          result: 'win',
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(sessionRecordedSnackbar('win', rating))),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to record win: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final squadStateAsync = ref.watch(ln.lobbyNotifierProvider);
    return squadStateAsync.maybeWhen(
      data: (squadState) {
        final lobbyId = squadState.selectedLobbyId;
        return ElevatedButton(
          onPressed: lobbyId != null
              ? () => _showWinConfirmation(context, ref, lobbyId)
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(fontSize: 18),
            elevation: 4,
            shadowColor: Colors.green.withValues(alpha: 0.3),
          ),
          child: const Text(
            'Win',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        );
      },
      orElse: () => const ElevatedButton(
        onPressed: null,
        child: Text('Win'),
      ),
    );
  }
}

/// Voice room button widget - extracted for better performance
class _VoiceRoomButton extends ConsumerWidget {
  const _VoiceRoomButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final squadStateAsync = ref.watch(ln.lobbyNotifierProvider);

    return squadStateAsync.maybeWhen(
      data: (squadState) => ElevatedButton.icon(
        onPressed: () {
          if (squadState.selectedLobbyId == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No lobby selected')),
            );
            return;
          }

          openVoiceRoom(
            context: context,
            roomId: squadState.selectedLobbyId!,
            squadName: kDefaultVoiceSquadName,
            isHost: false,
          );
        },
        icon: const Icon(Icons.mic),
        label: const Text('Voice'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 18),
          elevation: 4,
        ),
      ),
      orElse: () => ElevatedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.mic),
        label: const Text('Voice'),
      ),
    );
  }
}

/// Loss button widget
class _LossButton extends ConsumerWidget {
  const _LossButton();

  Future<void> _showLossConfirmation(
      BuildContext context, WidgetRef ref, String lobbyId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Record Loss'),
        content: const Text('Record a loss for this lobby?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Record Loss'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final rating = await promptAndRecordEndedSession(
          context: context,
          ref: ref,
          lobbyId: lobbyId,
          result: 'loss',
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(sessionRecordedSnackbar('loss', rating))),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to record loss: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final squadStateAsync = ref.watch(ln.lobbyNotifierProvider);
    return squadStateAsync.maybeWhen(
      data: (squadState) {
        final lobbyId = squadState.selectedLobbyId;
        return ElevatedButton(
          onPressed: lobbyId != null
              ? () => _showLossConfirmation(context, ref, lobbyId)
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(fontSize: 18),
            elevation: 4,
            shadowColor: Colors.redAccent.withValues(alpha: 0.3),
          ),
          child: const Text(
            'Loss',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        );
      },
      orElse: () => const ElevatedButton(
        onPressed: null,
        child: Text('Loss'),
      ),
    );
  }
}
