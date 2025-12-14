import 'package:flutter/material.dart';
import '../../services/auth_service_supabase.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/game.dart';
import '../../presentation/notifiers/chat_notifier.dart';
import '../../presentation/notifiers/game_notifier.dart';
import '../../widgets/game_tile.dart';
import '../../widgets/unified_game_selection_sheet.dart';
import '../chat_screen.dart';

/// Dialog for creating a new group with enhanced UI
class GroupActionsDialog extends ConsumerStatefulWidget {
  const GroupActionsDialog({super.key});

  @override
  ConsumerState<GroupActionsDialog> createState() => _GroupActionsDialogState();
}

class _GroupActionsDialogState extends ConsumerState<GroupActionsDialog> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.grey[900]!,
              Colors.grey[850]!,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.cyanAccent.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.cyanAccent.withValues(alpha: 0.1),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with gradient and close button
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.cyanAccent.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.cyanAccent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.group_add,
                      color: Colors.cyanAccent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create New Group',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Build your gaming community',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _CreateGroupTab(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tab for creating a new group with optional members and games
class _CreateGroupTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_CreateGroupTab> createState() => _CreateGroupTabState();
}

class _CreateGroupTabState extends ConsumerState<_CreateGroupTab> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isPublic = false; // Default to private
  bool _isCreating = false;
  Game? _selectedGame;
  List<Game> _popularGames = [];
  bool _loadingGames = false;

  @override
  void initState() {
    super.initState();
    _loadPopularGames();
  }

  Future<void> _loadPopularGames() async {
    setState(() => _loadingGames = true);
    try {
      final result =
          await ref.read(gameNotifierProvider.notifier).loadPopularGames();
      result.when(
        data: (games) {
          if (mounted) {
            setState(() {
              _popularGames = games.take(10).toList(); // Top 10 popular games
              _loadingGames = false;
            });
          }
        },
        loading: () {},
        error: (e, st) {
          if (mounted) {
            setState(() => _loadingGames = false);
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _loadingGames = false);
      }
    }
  }

  Future<void> _showGameSearch() async {
    await UnifiedGameSelectionSheet.show(
      context,
      title: 'Select Game Focus',
      subtitle: 'Choose a game for this group',
      showPinnedGames: false,
      showSearchButton: true,
      showMaxSpotSelector: false,
      onGameSelected: (game) {
        if (mounted) {
          setState(() {
            _selectedGame = game;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Create group
  Future<void> _createGroup() async {
    final groupName = _nameController.text.trim();
    if (groupName.isEmpty) {
      showSnackBar(context, 'Please enter a group name');
      return;
    }

    setState(() => _isCreating = true);

    try {
      final currentUser = AuthServiceSupabase().currentUser;
      if (currentUser == null) return;

      // Use proper repository pattern
      final chatNotifier = ref.read(chatNotifierProvider.notifier);

      // Build description
      String? description = _descriptionController.text.trim();
      if (description.isEmpty) description = null;

      // Add game focus to description if selected
      if (_selectedGame != null) {
        final gameName = _selectedGame!.name;
        description =
            description != null ? '$description\n🎮 $gameName' : '🎮 $gameName';
      }

      // Create group
      final newGroup = await chatNotifier.createGroup(
        groupName,
        _isPublic,
        description: description,
      );

      if (mounted && newGroup != null) {
        Navigator.pop(context);
        showSnackBar(context, '✅ Group "$groupName" created!');

        // Navigate to the new chat screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatType: ChatType.userGroup,
              chatGroupId: newGroup.id,
              chatGroupName: newGroup.name,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Error creating group: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group Name
          const Text(
            'Group Name *',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Enter group name...',
              hintStyle: const TextStyle(color: Colors.grey),
              filled: true,
              fillColor: Colors.grey[800],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(Icons.group, color: Colors.cyanAccent),
            ),
            textCapitalization: TextCapitalization.words,
          ),

          const SizedBox(height: 24),

          // Description (Optional)
          const Text(
            'Description (Optional)',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descriptionController,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'What is this group about?',
              hintStyle: const TextStyle(color: Colors.grey),
              filled: true,
              fillColor: Colors.grey[800],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            textCapitalization: TextCapitalization.sentences,
          ),

          const SizedBox(height: 24),

          // Game Focus (Optional)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Game Focus (Optional)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton.icon(
                onPressed: _showGameSearch,
                icon: const Icon(Icons.search,
                    size: 18, color: Colors.cyanAccent),
                label: const Text(
                  'Search IGDB',
                  style: TextStyle(color: Colors.cyanAccent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_selectedGame != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.cyanAccent.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              child: Stack(
                children: [
                  GameTile(
                    game: _selectedGame!,
                    style: GameTileStyle.list,
                    onTap: () {
                      setState(() => _selectedGame = null);
                    },
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.red.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        onTap: () {
                          setState(() => _selectedGame = null);
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[800]?.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey[700]!,
                  width: 1,
                ),
              ),
              child: _loadingGames
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Colors.cyanAccent,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  : _popularGames.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              const Icon(Icons.videogame_asset_off,
                                  color: Colors.grey, size: 32),
                              const SizedBox(height: 8),
                              const Text(
                                'No popular games loaded',
                                style: TextStyle(color: Colors.grey),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: _loadPopularGames,
                                child: const Text(
                                  'Retry',
                                  style: TextStyle(color: Colors.cyanAccent),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(12),
                              child: Text(
                                'Popular Games',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            SizedBox(
                              height: 120,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                itemCount: _popularGames.length,
                                itemBuilder: (context, index) {
                                  final game = _popularGames[index];
                                  return Container(
                                    width: 140,
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                    child: GameTile(
                                      game: game,
                                      style: GameTileStyle.grid,
                                      onTap: () {
                                        setState(() => _selectedGame = game);
                                      },
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
            ),

          const SizedBox(height: 24),

          // Privacy Setting
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[800]?.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isPublic
                    ? Colors.cyanAccent.withValues(alpha: 0.3)
                    : Colors.grey.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _isPublic ? Icons.public : Icons.lock,
                      color: Colors.cyanAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Group Privacy',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: _isPublic,
                  onChanged: (value) => setState(() => _isPublic = value),
                  title: Text(
                    _isPublic ? 'Public Group' : 'Private Group',
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    _isPublic
                        ? 'Anyone can find and join this group'
                        : 'Invite-only, members need an invite code',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  activeColor: Colors.cyanAccent,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Create Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isCreating ? null : _createGroup,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent,
                foregroundColor: Colors.black,
                disabledBackgroundColor: Colors.grey[700],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
              child: _isCreating
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: Colors.black,
                        strokeWidth: 2,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_circle, size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Create Group',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 16),

          // Info text
          Text(
            'You\'ll be able to invite members after creating the group',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
