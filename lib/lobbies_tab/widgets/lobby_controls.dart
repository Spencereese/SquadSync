import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/notifiers/lobby_notifier.dart' as ln;
import '../../presentation/notifiers/user_notifier.dart';
import '../../services/auth_service_supabase.dart';
import '../../screens/voice_room_screen.dart';
import 'game_alerts_display.dart';

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
        ],
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
        await ref.read(ln.lobbyNotifierProvider.notifier).recordWin(lobbyId);
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
        await ref.read(ln.lobbyNotifierProvider.notifier).recordLoss(lobbyId);
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
