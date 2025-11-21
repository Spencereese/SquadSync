import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../squad_state.dart';
import '../../managers/squad_manager.dart';
import 'member_management_dialog.dart';
import 'ban_dialog.dart';
import 'manage_games_dialog.dart';

class SettingsDialog {
  static void show(BuildContext context, SquadState squadState,
      {String? lobbyId}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Squad Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Close Lobby option - only show if we're in a lobby
            if (lobbyId != null) ...[
              ListTile(
                leading: Icon(Icons.close, color: Colors.redAccent),
                title: const Text('Close Lobby'),
                subtitle: const Text('End this lobby and remove all spots'),
                onTap: () async {
                  Navigator.pop(context);
                  await _closeLobby(context, lobbyId);
                },
              ),
              const Divider(),
            ],
            ListTile(
              leading: Image.asset('assets/images/clear_all.png',
                  width: 24, height: 24, color: Colors.redAccent),
              title: const Text('Clear All Spots'),
              onTap: () {
                squadState.clearAllSpots(squadState.currentGame?['name'] ?? '');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Image.asset('assets/images/timer_off.png',
                  width: 24, height: 24, color: Colors.blueGrey),
              title: const Text('Reset Timers'),
              onTap: () {
                squadState.resetTimers(squadState.currentGame?['name'] ?? '');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Image.asset('assets/images/people_group.png',
                  width: 24, height: 24, color: Colors.cyanAccent),
              title: const Text('Manage Members'),
              onTap: () {
                Navigator.pop(context);
                MemberManagementDialog.show(context, squadState);
              },
            ),
            ListTile(
              leading: Image.asset('assets/images/sword.png',
                  width: 24, height: 24, color: Colors.redAccent),
              title: const Text('Ban Member'),
              onTap: () {
                Navigator.pop(context);
                BanDialog.show(context, squadState);
              },
            ),
            ListTile(
              leading: Icon(Icons.games, color: Colors.cyanAccent),
              title: const Text('Manage Games'),
              onTap: () {
                Navigator.pop(context);
                ManageGamesDialog.show(context, squadState);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
        ],
      ),
    );
  }

  static Future<void> _closeLobby(BuildContext context, String lobbyId) async {
    final squadManager = Provider.of<SquadManager>(context, listen: false);

    try {
      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Close Lobby'),
          content: const Text(
              'Are you sure you want to close this lobby? This will remove all claimed spots and cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Close Lobby'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await squadManager.closeLobby(lobbyId);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lobby closed successfully')),
          );
          // Navigate back to lobby selection
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to close lobby: $e')),
        );
      }
    }
  }
}
