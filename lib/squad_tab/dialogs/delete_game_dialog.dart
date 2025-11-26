import 'package:flutter/material.dart';
import '../../domain/entities/squad_state.dart';

class DeleteGameDialog {
  static void show(BuildContext context, SquadState squadState, int index) {
    final game = squadState.availableGames[index];
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Game'),
        content: Text(
            'Are you sure you want to delete "${game['name']}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // TODO: Implement deleteGame using notifier
              // squadState.deleteGame(game['name']);
              // Defer navigation to avoid _debugLocked assertion
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (Navigator.canPop(dialogContext)) {
                  Navigator.pop(dialogContext);
                }
              });
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
