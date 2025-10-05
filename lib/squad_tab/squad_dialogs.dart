import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../squad_state.dart';

class SquadDialogs {
  static void showSpotAssignmentMenu(
      BuildContext context, SquadState squadState, int index) {
    final availablePlayers = squadState.getFilteredMembers
        .where((player) => !squadState.squadSpots.contains(player))
        .toList();

    if (availablePlayers.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (dialogContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.4,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        builder: (_, controller) => ListView(
          controller: controller,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Assign Spot ${index + 1}',
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            ...availablePlayers.map((player) => ListTile(
                  title: Text(player),
                  onTap: () {
                    squadState.assignSpot(index, player);
                    Navigator.pop(dialogContext);
                  },
                )),
          ],
        ),
      ),
    );
  }

  static void showBlockDialog(
      BuildContext context, String player, SquadState squadState) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isBlocked = squadState.userBlocks[uid]?.containsKey(player) ?? false;
    final action = isBlocked ? 'Unblock' : 'Block Player';
    final message = isBlocked
        ? 'Unblock $player? You will see each other again.'
        : 'Hide $player from your view? This is mutual—they won\'t see you either.';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('$action $player'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (isBlocked) {
                squadState.unblockUser(player);
              } else {
                squadState.blockUser(player);
              }
              Navigator.of(dialogContext).pop();
            },
            child: Text(action),
          ),
        ],
      ),
    );
  }

  static void showComplaintDialog(BuildContext context,
      ScaffoldMessengerState messenger, SquadState squadState, String player) {
    String? reason;
    String? category;
    final categories = ['Behavior', 'Inactivity', 'Toxicity'];

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('File Complaint Against $player'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'Reason'),
                onChanged: (value) => reason = value,
              ),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Category'),
                items: categories
                    .map(
                        (cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                    .toList(),
                onChanged: (value) => setState(() => category = value),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (reason != null &&
                  category != null &&
                  squadState.displayName != null) {
                try {
                  await squadState.submitComplaint(
                    targetMember: player,
                    reason: reason!,
                    category: category!,
                    submittedBy: squadState.displayName!,
                  );
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Complaint submitted')),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  static void showRatingsDialog(
      BuildContext context,
      ScaffoldMessengerState messenger,
      SquadState squadState,
      String player) async {
    final ratings = <String, int?>{
      'Vibes': null,
      'Comms': null,
      'Gunny': null,
      'Wingman': null
    };
    final canRate = squadState.displayName != null &&
        await squadState.canRateMember(player, squadState.displayName!);

    if (!canRate) {
      messenger.showSnackBar(
        const SnackBar(
            content: Text('You can only rate members you played with')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Rate $player'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: ratings.keys
                .map((category) => Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(category),
                        Row(
                          children: List.generate(
                              5,
                              (index) => IconButton(
                                    icon: Icon(
                                      index < (ratings[category] ?? 0)
                                          ? Icons.star
                                          : Icons.star_border,
                                      color: Colors.yellowAccent,
                                    ),
                                    onPressed: () => setState(
                                        () => ratings[category] = index + 1),
                                  )),
                        ),
                      ],
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (squadState.displayName != null) {
                try {
                  await squadState.submitRatings(
                    targetMember: player,
                    ratings: ratings,
                    submittedBy: squadState.displayName!,
                  );
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Ratings submitted')),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  static void showSettingsDialog(BuildContext context, SquadState squadState) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Squad Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Image.asset('assets/images/clear_all.png',
                  width: 24, height: 24, color: Colors.redAccent),
              title: const Text('Clear All Spots'),
              onTap: () {
                squadState.clearAllSpots();
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Image.asset('assets/images/timer_off.png',
                  width: 24, height: 24, color: Colors.blueGrey),
              title: const Text('Reset Timers'),
              onTap: () {
                squadState.resetTimers();
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Image.asset('assets/images/people_group.png',
                  width: 24, height: 24, color: Colors.cyanAccent),
              title: const Text('Manage Members'),
              onTap: () {
                Navigator.pop(context);
                showMemberManagementDialog(context, squadState);
              },
            ),
            ListTile(
              leading: Image.asset('assets/images/sword.png',
                  width: 24, height: 24, color: Colors.redAccent),
              title: const Text('Ban Member'),
              onTap: () {
                Navigator.pop(context);
                showBanDialog(context, squadState);
              },
            ),
            ListTile(
              leading: Icon(Icons.games, color: Colors.cyanAccent),
              title: const Text('Manage Games'),
              onTap: () {
                Navigator.pop(context);
                showManageGamesDialog(context, squadState);
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

  static void showMemberManagementDialog(
      BuildContext context, SquadState squadState) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Manage Members'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Add Member'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Remove Member'),
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

  static void showBanDialog(BuildContext context, SquadState squadState) {
    String? selectedPlayer;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Ban a Member'),
        content: Row(
          children: [
            Image.asset('assets/images/sword.png',
                width: 24, height: 24, color: Colors.redAccent),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Select Member'),
                items: squadState.getFilteredMembers
                    .map((player) =>
                        DropdownMenuItem(value: player, child: Text(player)))
                    .toList(),
                onChanged: (value) => selectedPlayer = value,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (selectedPlayer != null && squadState.displayName != null) {
                squadState.addBan(selectedPlayer!, squadState.displayName!);
                Navigator.pop(context);
              }
            },
            child: const Text('Ban'),
          ),
        ],
      ),
    );
  }

  static void showJoinLobbyDialog(
      BuildContext context, String player, SquadState squadState) {
    final visibleLobbies =
        squadState.getVisibleLobbies(squadState.currentGame?['name'] ?? '');

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Join Lobby with $player'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: visibleLobbies.length,
            itemBuilder: (context, index) {
              final lobby = visibleLobbies[index];
              final host = lobby['host'] ?? 'Unknown';
              final players = List<String>.from(lobby['players'] ?? []);
              final game = lobby['game'] ?? 'Unknown';

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  title: Text('$game Lobby - Host: $host'),
                  subtitle:
                      Text('${players.length} players: ${players.join(', ')}'),
                  trailing: ElevatedButton(
                    onPressed: () {
                      squadState.joinLobby(
                          lobby['id'], squadState.displayName ?? '');
                      Navigator.pop(dialogContext);
                    },
                    child: const Text('Join'),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  static void showAddGameDialog(BuildContext context, SquadState squadState) {
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
                labelText: 'Logo Path',
                hintText: 'e.g., assets/images/placeholder.png',
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
                  'logo': gameLogo.isNotEmpty
                      ? gameLogo
                      : 'assets/images/placeholder.png'
                });
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('Add Game'),
          ),
        ],
      ),
    );
  }

  static void showManageGamesDialog(
      BuildContext context, SquadState squadState) {
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
                    showAddGameDialog(context, squadState);
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
                        showEditGameDialog(context, squadState, index);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        showDeleteGameDialog(context, squadState, index);
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

  static void showEditGameDialog(
      BuildContext context, SquadState squadState, int index) {
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
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  static void showDeleteGameDialog(
      BuildContext context, SquadState squadState, int index) {
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
              squadState.deleteGame(index);
              Navigator.pop(dialogContext);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
