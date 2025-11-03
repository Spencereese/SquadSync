import 'package:flutter/material.dart';
import '../../squad_state.dart';

class EditGameDialog {
  static void show(BuildContext context, SquadState squadState, int index) {
    final game = squadState.availableGames[index];
    final TextEditingController nameController =
        TextEditingController(text: game['name']);
    final TextEditingController descriptionController =
        TextEditingController(text: game['description'] ?? '');
    final TextEditingController logoController =
        TextEditingController(text: game['logo'] ?? '');
    final TextEditingController spotsController =
        TextEditingController(text: game['maxSpots'].toString());

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
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'e.g., Battle Royale, Multiplayer FPS',
              ),
              controller: descriptionController,
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Logo Path',
                hintText: 'e.g., assets/images/placeholder.png',
              ),
              controller: logoController,
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Max Players',
                hintText: 'e.g., 4, 3, 5',
              ),
              controller: spotsController,
              keyboardType: TextInputType.number,
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
              final gameDescription = descriptionController.text.trim();
              final gameLogo = logoController.text.trim();
              final maxSpots =
                  int.tryParse(spotsController.text) ?? game['maxSpots'];

              if (gameName.isNotEmpty) {
                squadState.editGame(index, {
                  'name': gameName,
                  'maxSpots': maxSpots,
                  'description': gameDescription.isNotEmpty
                      ? gameDescription
                      : 'Custom Game',
                  'logo': gameLogo.isNotEmpty
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
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
