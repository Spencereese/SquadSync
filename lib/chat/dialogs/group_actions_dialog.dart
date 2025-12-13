import 'package:flutter/material.dart';
import '../../services/auth_service_supabase.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils.dart';
import '../../domain/entities/message.dart';
import '../../presentation/notifiers/chat_notifier.dart';
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
  String? _selectedGame;
  final List<String> _popularGames = [
    'Call of Duty',
    'Fortnite',
    'Apex Legends',
    'Valorant',
    'League of Legends',
    'Rocket League',
    'Overwatch 2',
    'Counter-Strike 2',
    'Minecraft',
    'Among Us',
    'Any Game',
  ];

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
      if (_selectedGame != null && _selectedGame != 'Any Game') {
        description = description != null
            ? '$description\n🎮 $_selectedGame'
            : '🎮 $_selectedGame';
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
          const Text(
            'Game Focus (Optional)',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _selectedGame,
                hint: const Text(
                  'Select a game...',
                  style: TextStyle(color: Colors.grey),
                ),
                dropdownColor: Colors.grey[800],
                icon:
                    const Icon(Icons.arrow_drop_down, color: Colors.cyanAccent),
                style: const TextStyle(color: Colors.white, fontSize: 16),
                items: _popularGames.map((game) {
                  return DropdownMenuItem(
                    value: game,
                    child: Row(
                      children: [
                        if (game != 'Any Game')
                          const Icon(Icons.videogame_asset,
                              color: Colors.cyanAccent, size: 20),
                        if (game != 'Any Game') const SizedBox(width: 8),
                        Text(game),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedGame = value);
                },
              ),
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
