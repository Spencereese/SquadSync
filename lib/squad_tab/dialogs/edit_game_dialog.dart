import 'package:flutter/material.dart';
import '../../squad_state.dart';

class EditGameDialog {
  static void show(BuildContext context, SquadState squadState, int index) {
    final game = squadState.availableGames[index];
    final TextEditingController nameController =
        TextEditingController(text: game['name']);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Game'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Game Name',
                hintText: 'e.g., Call of Duty: Warzone, Fortnite',
              ),
              controller: nameController,
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
              final gameName = nameController.text.trim();

              if (gameName.isNotEmpty) {
                squadState.editGame(game['name'], gameName);
                // Defer navigation to avoid _debugLocked assertion
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (Navigator.canPop(dialogContext)) {
                    Navigator.pop(dialogContext);
                  }
                });
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
