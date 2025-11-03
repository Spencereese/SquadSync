import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../squad_state.dart';
import 'base_dialog.dart';

/// Dialog for blocking/unblocking players
class BlockDialog extends BaseSquadDialog {
  final String player;
  final SquadState squadState;

  const BlockDialog({
    super.key,
    required this.player,
    required this.squadState,
  });

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isBlocked = squadState.userBlocks[uid]?.containsKey(player) ?? false;
    final action = isBlocked ? 'Unblock' : 'Block Player';
    final message = isBlocked
        ? 'Unblock $player? You will see each other again.'
        : 'Hide $player from your view? This is mutual—they won\'t see you either.';

    return AlertDialog(
      shape: BaseSquadDialog.dialogShape,
      title: Text('$action $player'),
      content: Text(message),
      actions: BaseSquadDialog.dialogActions(
        context: context,
        actions: [
          BaseSquadDialog.cancelButton(context),
          BaseSquadDialog.submitButton(
            context: context,
            text: action,
            onPressed: () async {
              if (isBlocked) {
                await squadState.unblockUser(player);
              } else {
                await squadState.blockUser(player);
              }
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
    );
  }

  /// Static method to show the dialog (maintains compatibility)
  static void show(BuildContext context, String player, SquadState squadState) {
    showDialog(
      context: context,
      builder: (dialogContext) => BlockDialog(
        player: player,
        squadState: squadState,
      ),
    );
  }
}
