import 'package:flutter/material.dart';
import '../../domain/entities/lobby_state.dart';
import 'add_game_dialog.dart';
import 'edit_game_dialog.dart';
import 'delete_game_dialog.dart';

class ManageGamesDialog {
  static void show(BuildContext context, LobbyState squadState) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Manage Games'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount:
                squadState.availableGames.length + 1, // +1 for add button
            itemBuilder: (context, index) {
              if (index == squadState.availableGames.length) {
                // Add new game button
                return ListTile(
                  leading: Icon(Icons.add_circle, color: Colors.greenAccent),
                  title: const Text('Add New Game'),
                  onTap: () {
                    Navigator.pop(dialogContext);
                    AddGameDialog.show(context, squadState);
                  },
                );
              }

              final game = squadState.availableGames[index];

              return ListTile(
                leading: game['logo'] != null
                    ? Image.asset(
                        game['logo'],
                        width: 32,
                        height: 32,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.image_not_supported,
                                size: 32, color: Colors.grey),
                      )
                    : const Icon(Icons.gamepad, color: Colors.cyanAccent),
                title: Text(game['name']),
                subtitle: Text('${game['maxSpots']} players'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        EditGameDialog.show(context, squadState, index);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        DeleteGameDialog.show(context, squadState, index);
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
