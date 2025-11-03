import 'package:flutter/material.dart';
import '../../squad_state.dart';

class AddGameDialog {
  static void show(BuildContext context, SquadState squadState) {
    String gameName = '';
    String gameDescription = '';
    String gameLogo = '';
    int maxSpots = 4;

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
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'e.g., Battle Royale, Multiplayer FPS',
              ),
              onChanged: (value) => gameDescription = value,
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Cover Image URL',
                hintText: 'e.g., https://images.igdb.com/...',
              ),
              onChanged: (value) => gameLogo = value,
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Max Players',
                hintText: 'e.g., 4, 3, 5',
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) => maxSpots = int.tryParse(value) ?? 4,
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
                squadState.addGame({
                  'name': gameName,
                  'maxSpots': maxSpots,
                  'description': gameDescription.isNotEmpty
                      ? gameDescription
                      : 'Custom Game',
                  'coverUrl': gameLogo.isNotEmpty
                      ? gameLogo
                      : 'assets/images/placeholder.png'
                });
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
