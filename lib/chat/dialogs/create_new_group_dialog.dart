import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils.dart';
import '../../presentation/notifiers/user_notifier.dart';
import '../../presentation/notifiers/squad_notifier.dart' as sn;
import '../../domain/entities/game.dart';
import '../../presentation/notifiers/game_notifier.dart';
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
  Game? _selectedGame;

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
      final squadAsync = ref.watch(sn.squadNotifierProvider);
      final squadStateData = squadAsync.maybeWhen(
        data: (state) => state,
        orElse: () => null,
      );

      if (squadStateData == null) {
        // Handle case where squad state is not available
        return;
      }

      // Use UserNotifier to create the group
      final userNotifier = ref.read(userNotifierProvider.notifier);
      final groupId = await userNotifier.createGroup(
        name: groupName,
        isPublic: _isPublic,
        gameId: _selectedGame?.igdbId?.toString(),
        squadId: squadStateData.selectedSquadId,
      );

      if (groupId == null) {
        if (mounted) {
          showErrorSnackBar(context, 'Failed to create group');
        }
        return;
      }

      if (mounted) {
        Navigator.pop(context);
        showSnackBar(context, 'Group created successfully!');

        // Navigate to the new group
        _openChatGroup(groupId, groupName);
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

  Widget _buildGameList(List<Game> games) {
    return ListView.builder(
      itemCount: games.length,
      itemBuilder: (context, index) {
        final game = games[index];
        return RadioListTile<Game>(
          title: Text(game.name, style: const TextStyle(color: Colors.white)),
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
                ref.read(gameNotifierProvider.notifier).searchGames(value);
              }
            },
          ),
          AsyncValueWidget<GameState>(
            value: ref.watch(gameNotifierProvider),
            data: (gameState) => SizedBox(
              height: 200,
              child: _buildGameList(gameState.availableGames),
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
                            .read(gameNotifierProvider.notifier)
                            .searchGames(_gameSearchController.text);
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
