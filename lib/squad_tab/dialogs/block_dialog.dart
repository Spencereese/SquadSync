import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../presentation/notifiers/squad_notifier.dart' as sn;

/// Dialog for blocking/unblocking players
class BlockDialog extends ConsumerWidget {
  final String player;

  const BlockDialog({
    super.key,
    required this.player,
  });

  static void show(BuildContext context, String player) {
    showDialog(
      context: context,
      builder: (dialogContext) => BlockDialog(player: player),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return ref.watch(sn.squadNotifierProvider).when(
          data: (squadState) {
            final isBlocked =
                squadState.userBlocks[uid]?.containsKey(player) ?? false;
            final action = isBlocked ? 'Unblock' : 'Block Player';
            final message = isBlocked
                ? 'Unblock $player? You will see each other again.'
                : 'Hide $player from your view? This is mutual—they won\'t see you either.';

            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Text('$action $player'),
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    try {
                      if (isBlocked) {
                        // await ref
                        //     .read(sn.squadNotifierProvider.notifier)
                        //     .unblockUser(player);
                      } else {
                        // await ref
                        //     .read(sn.squadNotifierProvider.notifier)
                        //     .blockUser(player);
                      }
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    } catch (e) {
                      // Handle error
                    }
                  },
                  child: Text(action),
                ),
              ],
            );
          },
          loading: () => const CircularProgressIndicator(),
          error: (e, s) => Text('Error loading squad: $e'),
        );
  }
}
