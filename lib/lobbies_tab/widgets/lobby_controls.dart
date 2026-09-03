import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/notifiers/lobby_notifier.dart' as ln;
import '../../services/auth_service_supabase.dart';
import '../../services/availability_ping.dart';
import '../../services/session_rating_flow.dart';
import '../../services/session_rating_machine.dart';
import '../../screens/voice_room_screen.dart';

/// LobbyControls component - handles action buttons and controls
/// Extracted from the monolithic LobbyTab to improve maintainability
class LobbyControls extends ConsumerWidget {
  const LobbyControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SliverToBoxAdapter(
      child: Column(
        children: [
          // Win/Loss/Voice buttons
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _WinButton(),
                _VoiceRoomButton(),
                _LossButton(),
              ],
            ),
          ),
          // Game alert section removed - moved to chat menu as friend-wide "Looking for Squad"
          _OnNowButton(),
        ],
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
  const _VoiceRoomButton();

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

          // Navigate to voice room screen with lobby context
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => VoiceRoomScreen(
                roomId: squadState.selectedLobbyId!,
                squadName: 'Squad Voice',
                isHost: false,
              ),
            ),
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
