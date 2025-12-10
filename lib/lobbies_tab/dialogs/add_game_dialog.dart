import 'package:flutter/material.dart';
import '../../domain/entities/lobby_state.dart';

class AddGameDialog {
  static void show(BuildContext context, LobbyState squadState) {
    String gameName = '';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add New Game'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Game Name',
                hintText: 'e.g., Call of Duty: Warzone, Fortnite',
              ),
              onChanged: (value) => gameName = value,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (gameName.isNotEmpty) {
                // TODO: Implement addGame using notifier
                // squadState.addGame(gameName);
                // Defer navigation to avoid _debugLocked assertion
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (Navigator.canPop(dialogContext)) {
                    Navigator.pop(dialogContext);
                  }
                });
              }
            },
            child: const Text('Add Game'),
          ),
        ],
      ),
    );
  }
}
