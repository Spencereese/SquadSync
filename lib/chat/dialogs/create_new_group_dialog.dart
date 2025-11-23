import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils.dart';
import '../../providers.dart' as p;
import '../../managers/game_manager.dart';
import '../../widgets/async_value_widget.dart';

/// Dialog for creating a new chat group
class CreateNewGroupDialog extends ConsumerStatefulWidget {
  const CreateNewGroupDialog({super.key});

  @override
  ConsumerState<CreateNewGroupDialog> createState() =>
      _CreateNewGroupDialogState();
}

class _CreateNewGroupDialogState extends ConsumerState<CreateNewGroupDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _gameSearchController = TextEditingController();
  bool _isPublic = true;
  bool _isLoading = false;
  Map<String, dynamic>? _selectedGame;

  @override
  void dispose() {
    _nameController.dispose();
    _gameSearchController.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    final groupName = _nameController.text.trim();
    if (groupName.isEmpty) {
      showSnackBar(context, 'Please enter a group name');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final squadStateData = ref.watch(p.squadStateNotifierProvider);
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Create group document - use user-specific or squad-specific based on context
      DocumentReference groupRef;

      if (squadStateData.selectedSquadId != null) {
        // Squad context - create squad group
        groupRef = FirebaseFirestore.instance
            .collection('squads')
            .doc(squadStateData.selectedSquadId)
            .collection('chat_groups')
            .doc();
      } else {
        // No squad - create user-specific group
        groupRef = FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .collection('chat_groups')
            .doc();
      }

      await groupRef.set({
        'name': groupName,
        'isPublic': _isPublic,
        'createdBy': currentUser.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'memberCount': 1,
        'members': [currentUser.uid],
        'imageUrl': null,
        'gameId': _selectedGame?['id'],
      });

      if (mounted) {
        Navigator.pop(context);
        showSnackBar(context, 'Group created successfully!');

        // Navigate to the new group
        _openChatGroup(groupRef.id, groupName);
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Error creating group: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _openChatGroup(String groupId, String groupName) {
    // This would need to be passed as a callback or handled by the parent
    // For now, we'll emit an event or use a navigation service
    Navigator.pushNamed(
      context,
      '/chat',
      arguments: {
        'chatGroupId': groupId,
        'chatGroupName': groupName,
        'chatType': 'group',
      },
    );
  }

  Widget _buildGameList(List<Map<String, dynamic>> games) {
    return ListView.builder(
      itemCount: games.length,
      itemBuilder: (context, index) {
        final game = games[index];
        return RadioListTile<Map<String, dynamic>>(
          title:
              Text(game['name'], style: const TextStyle(color: Colors.white)),
          value: game,
          groupValue: _selectedGame,
          onChanged: (value) {
            // ignore: deprecated_member_use
            setState(() => _selectedGame = value);
          },
          activeColor: Colors.cyanAccent,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title: const Text(
        'Create New Group',
        style: TextStyle(color: Colors.white),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Group Name',
              labelStyle: TextStyle(color: Colors.cyanAccent),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.cyanAccent),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.cyanAccent),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              const Text(
                'Privacy:',
                style: TextStyle(color: Colors.white),
              ),
              ChoiceChip(
                label: const Text('Public'),
                selected: _isPublic,
                onSelected: (selected) {
                  setState(() => _isPublic = selected);
                },
                selectedColor: Colors.cyanAccent.withValues(alpha: 0.3),
                backgroundColor: Colors.grey[700],
                labelStyle: TextStyle(
                  color: _isPublic ? Colors.cyanAccent : Colors.white,
                ),
              ),
              ChoiceChip(
                label: const Text('Private'),
                selected: !_isPublic,
                onSelected: (selected) {
                  setState(() => _isPublic = !selected);
                },
                selectedColor: Colors.cyanAccent.withValues(alpha: 0.3),
                backgroundColor: Colors.grey[700],
                labelStyle: TextStyle(
                  color: !_isPublic ? Colors.cyanAccent : Colors.white,
                ),
              ),
            ],
          ),
          if (!_isPublic) ...[
            const SizedBox(height: 16),
            const Text(
              'Private groups require manual member approval',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),
          const Text('Select Game (optional)',
              style: TextStyle(color: Colors.white)),
          TextField(
            controller: _gameSearchController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Search games',
              labelStyle: TextStyle(color: Colors.cyanAccent),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.cyanAccent),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.cyanAccent),
              ),
            ),
            onChanged: (value) {
              if (value.isNotEmpty) {
                ref
                    .read(gameManagerProvider.notifier)
                    .fetchGamesFromIGDB(value);
              }
            },
          ),
          AsyncValueWidget<GameState>(
            value: ref.watch(gameManagerProvider),
            data: (gameState) => SizedBox(
              height: 200,
              child: gameState.isOffline
                  ? Banner(
                      message: 'Using offline cache',
                      location: BannerLocation.topEnd,
                      child: _buildGameList(gameState.games),
                    )
                  : _buildGameList(gameState.games),
            ),
            loading: () => const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stack) => SizedBox(
              height: 200,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline,
                        size: 48, color: Theme.of(context).colorScheme.error),
                    const SizedBox(height: 16),
                    Text('API error: ${error.toString()}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        ref
                            .read(gameManagerProvider.notifier)
                            .fetchGamesFromIGDB(_gameSearchController.text);
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _isLoading ? null : _createGroup,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.cyanAccent,
                  ),
                )
              : const Text('Create',
                  style: TextStyle(color: Colors.cyanAccent)),
        ),
      ],
    );
  }
}
