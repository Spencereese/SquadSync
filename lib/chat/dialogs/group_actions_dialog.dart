import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../services/auth_service_supabase.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import '../../utils.dart';
import '../../domain/entities/message.dart';
import '../../presentation/notifiers/user_notifier.dart';
import 'package:squad_sync/presentation/notifiers/lobby_notifier.dart' as ln;
import '../../presentation/notifiers/game_notifier.dart';
import '../../presentation/notifiers/chat_notifier.dart';
import '../chat_screen.dart';

/// Unified dialog for all group-related actions: join, create, and browse public groups
class GroupActionsDialog extends ConsumerStatefulWidget {
  final int initialTabIndex;
  final String? initialCode;

  const GroupActionsDialog({
    super.key,
    this.initialTabIndex = 0,
    this.initialCode,
  });

  @override
  ConsumerState<GroupActionsDialog> createState() => _GroupActionsDialogState();
}

class _GroupActionsDialogState extends ConsumerState<GroupActionsDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header with close button
            Row(
              children: [
                const Text(
                  'Group Actions',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tab bar
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(8),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: Colors.cyanAccent,
                  borderRadius: BorderRadius.circular(8),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.black,
                unselectedLabelColor: Colors.white,
                labelPadding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                tabs: const [
                  Tab(text: 'Join'),
                  Tab(text: 'Create'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _JoinGroupTab(initialCode: widget.initialCode),
                  _CreateGroupTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tab for joining a group with invite code, browsing, and suggested groups
class _JoinGroupTab extends ConsumerStatefulWidget {
  final String? initialCode;

  const _JoinGroupTab({this.initialCode});

  @override
  ConsumerState<_JoinGroupTab> createState() => _JoinGroupTabState();
}

class _JoinGroupTabState extends ConsumerState<_JoinGroupTab> {
  final _codeController = TextEditingController();
  final _searchController = TextEditingController();
  final AuthServiceSupabase _authService = AuthServiceSupabase();

  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _suggestedGroups = [];
  bool _isLoading = false;
  bool _isJoining = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null) {
      _codeController.text = widget.initialCode!;
    }
    _loadSuggestedGroups();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestedGroups() async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    try {
      // Get popular public groups (most members first)
      final response = await SupabaseService.client
          .from('chat_groups')
          .select()
          .eq('is_public', true)
          .order('member_count', ascending: false)
          .limit(10);

      final groups = <Map<String, dynamic>>[];

      for (var data in (response as List<dynamic>)) {
        final groupData = data as Map<String, dynamic>;
        final members = List<String>.from(groupData['member_uids'] ?? []);
        final isAlreadyMember = members.contains(currentUser.id);

        // Only show groups the user is not already a member of
        if (!isAlreadyMember) {
          groups.add({
            'id': groupData['id'],
            'data': groupData,
            'type': 'user_group',
          });
        }
      }

      if (mounted) {
        setState(() => _suggestedGroups = groups.take(5).toList());
      }
    } catch (e) {
      debugPrint('Error loading suggested groups: $e');
    }
  }

  Future<void> _joinGroup() async {
    final code = _codeController.text.trim();
    if (code.isEmpty || !mounted) return;

    // Basic validation - group codes should be reasonable length
    if (code.length < 6 || code.length > 20) {
      if (mounted) {
        showSnackBar(context, 'Invalid group code format');
      }
      return;
    }

    // Check for potentially malicious input
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(code)) {
      if (mounted) {
        showSnackBar(context, 'Group code contains invalid characters');
      }
      return;
    }

    setState(() => _isJoining = true);
    try {
      final userNotifier = ref.read(userNotifierProvider.notifier);

      // Try to join as a chat group first (most common case for invite codes)
      try {
        final success = await userNotifier.joinGroup(code);
        if (success) {
          if (mounted) {
            Navigator.pop(context);
            showSnackBar(context, 'Successfully joined group!');
          }
          return;
        } else {
          throw Exception(
              'Failed to join group - group may not exist or you may already be a member');
        }
      } catch (chatGroupError) {
        debugPrint('Chat group join failed: $chatGroupError');

        // If chat group join fails, try squad join as fallback
        try {
          final currentUser = AuthServiceSupabase().currentUser;
          if (currentUser == null) throw Exception('User not authenticated');

          final squadNotifier = ref.read(ln.lobbyNotifierProvider.notifier);
          await squadNotifier.joinSquad(code, currentUser.id);
          if (mounted) {
            Navigator.pop(context);
            showSnackBar(context, 'Successfully joined squad!');
          }
        } catch (squadError) {
          debugPrint('Squad join also failed: $squadError');
          // Both attempts failed, show the more relevant error
          throw chatGroupError; // Chat group error is more likely for invite codes
        }
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Error joining group: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isJoining = false);
      }
    }
  }

  Future<void> _searchGroups(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final results = await _searchPublicGroups(query.trim());
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error searching groups: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        showSnackBar(context, 'Error searching groups. Please try again.');
      }
    }
  }

  Future<List<Map<String, dynamic>>> _searchPublicGroups(String query) async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return [];

    try {
      // Search for public groups using Supabase ilike
      final response = await SupabaseService.client
          .from('chat_groups')
          .select()
          .eq('is_public', true)
          .ilike('name', '%$query%')
          .limit(20);

      final results = <Map<String, dynamic>>[];

      for (var data in (response as List<dynamic>)) {
        final groupData = data as Map<String, dynamic>;
        final members = List<String>.from(groupData['member_uids'] ?? []);
        final isAlreadyMember = members.contains(currentUser.id);

        // Only show groups the user is not already a member of
        if (!isAlreadyMember) {
          results.add({
            'id': groupData['id'],
            'data': groupData,
            'type': 'user_group',
          });
        }
      }

      return results;
    } catch (e) {
      debugPrint('Error searching public groups: $e');
      return [];
    }
  }

  Future<void> _joinPublicGroup(
      String groupId, Map<String, dynamic> groupData) async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    try {
      // Add user to the group's members array
      final existingMembers = List<String>.from(groupData['member_uids'] ?? []);
      if (!existingMembers.contains(currentUser.id)) {
        existingMembers.add(currentUser.id);
      }

      // Update the group with new member
      await SupabaseService.client.from('chat_groups').update({
        'member_uids': existingMembers,
        'member_count': existingMembers.length,
      }).eq('id', groupId);

      // Add group to user's user_groups array
      final userResponse = await SupabaseService.client
          .from('users')
          .select('user_groups')
          .eq('id', currentUser.id)
          .maybeSingle();

      final userGroups = userResponse != null
          ? List<Map<String, dynamic>>.from(userResponse['user_groups'] ?? [])
          : <Map<String, dynamic>>[];

      // Check if group already exists in user_groups
      final existingIndex =
          userGroups.indexWhere((g) => g['chat_group_id'] == groupId);
      if (existingIndex == -1) {
        userGroups.add({
          'chat_group_id': groupId,
          'joined_at': DateTime.now().toIso8601String(),
        });

        await SupabaseService.client
            .from('users')
            .update({'user_groups': userGroups}).eq('id', currentUser.id);
      }

      if (mounted) {
        showSnackBar(context, 'Successfully joined group!');
        // Close the dialog and navigate to the chat screen
        Navigator.of(context).pop();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatType: ChatType.userGroup,
              chatGroupId: groupId,
              chatGroupName: groupData['name'] ?? 'Unnamed Group',
            ),
          ),
        );
        // Refresh search results and suggested groups
        _searchGroups(_searchController.text);
        _loadSuggestedGroups();
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Error joining group: $e');
      }
    }
  }

  Widget _buildGroupListTile(Map<String, dynamic> group,
      {bool showInviteCode = false}) {
    final groupId = group['id'];
    final groupData = group['data'] as Map<String, dynamic>;
    final name = groupData['name'] ?? 'Unnamed Group';
    final memberCount = groupData['memberCount'] ?? 0;
    final gameFocus = groupData['gameFocus'];
    final isPublic = groupData['isPublic'] ?? false;

    return Card(
      color: Colors.grey[800],
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.cyanAccent,
          child: Icon(
            isPublic ? Icons.public : Icons.group,
            color: Colors.black,
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$memberCount members',
              style: const TextStyle(color: Colors.grey),
            ),
            if (gameFocus != null)
              Text(
                '🎮 $gameFocus',
                style: const TextStyle(
                  color: Colors.cyanAccent,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        trailing: showInviteCode
            ? IconButton(
                icon: const Icon(Icons.share, color: Colors.cyanAccent),
                onPressed: () => _showInviteCode(groupId, groupData),
                tooltip: 'Get invite code',
              )
            : ElevatedButton(
                onPressed: () => _joinPublicGroup(groupId, groupData),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Join'),
              ),
      ),
    );
  }

  Future<void> _showInviteCode(
      String groupId, Map<String, dynamic> groupData) async {
    final name = groupData['name'] ?? 'Unnamed Group';
    // For now, we'll use the group ID as the invite code
    // In a real implementation, you might want to generate shorter codes
    final inviteCode = groupId.substring(0, 8).toUpperCase();

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text(
            'Invite Code for $name',
            style: const TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Share this code with friends to invite them to your group:',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        inviteCode,
                        style: const TextStyle(
                          color: Colors.cyanAccent,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, color: Colors.cyanAccent),
                      onPressed: () {
                        // Copy to clipboard functionality would go here
                        showSnackBar(
                            context, 'Invite code copied to clipboard!');
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: Colors.cyan)),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Join a Group',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Invite code section
          const Text(
            'Join with Invite Code',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _codeController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter invite code',
              hintStyle: const TextStyle(color: Colors.grey),
              filled: true,
              fillColor: Colors.grey[800],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(Icons.group_add, color: Colors.cyanAccent),
            ),
            onSubmitted: (_) => _joinGroup(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isJoining ? null : _joinGroup,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isJoining
                  ? const CircularProgressIndicator(color: Colors.black)
                  : const Text('Join Group'),
            ),
          ),

          const SizedBox(height: 24),
          const Divider(color: Colors.grey),

          // Suggested groups section
          const Text(
            'Suggested Groups',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Popular public groups you might like',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 12),

          if (_suggestedGroups.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No suggested groups available',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            Column(
              children: _suggestedGroups
                  .map((group) => _buildGroupListTile(group))
                  .toList(),
            ),

          const SizedBox(height: 24),
          const Divider(color: Colors.grey),

          // Browse section
          const Text(
            'Browse Public Groups',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Search for groups by name',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search groups...',
              hintStyle: const TextStyle(color: Colors.grey),
              filled: true,
              fillColor: Colors.grey[800],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(Icons.search, color: Colors.cyanAccent),
            ),
            onChanged: _searchGroups,
          ),
          const SizedBox(height: 16),

          // Search results
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(color: Colors.cyanAccent),
              ),
            )
          else if (_searchResults.isEmpty && _searchController.text.isNotEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No groups found',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else if (_searchResults.isNotEmpty)
            Column(
              children: _searchResults
                  .map((group) => _buildGroupListTile(group))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

/// Tab for creating a new group
class _CreateGroupTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_CreateGroupTab> createState() => _CreateGroupTabState();
}

class _CreateGroupTabState extends ConsumerState<_CreateGroupTab> {
  final _nameController = TextEditingController();
  bool _isPublic = true;
  bool _isLoading = false;
  final List<String> _selectedGames = [];

  @override
  void dispose() {
    _nameController.dispose();
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
      final currentUser = AuthServiceSupabase().currentUser;
      if (currentUser == null) return;

      // Use proper repository pattern instead of direct Supabase calls
      final chatNotifier = ref.read(chatNotifierProvider.notifier);

      // TODO: Add support for games in group metadata
      final newGroup = await chatNotifier.createGroup(
        groupName,
        _isPublic,
        description: _selectedGames.isNotEmpty
            ? 'Games: ${_selectedGames.join(", ")}'
            : null,
      );

      if (mounted && newGroup != null) {
        // Show invite code dialog for private groups
        if (!_isPublic) {
          _showInviteCodeDialog(newGroup.id, groupName);
        } else {
          Navigator.pop(context);
          // Use addPostFrameCallback to ensure context is valid for navigation
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              showSnackBar(context, 'Group created successfully!');
              // Navigate to the new group
              _openChatGroup(newGroup.id, groupName);
            }
          });
        }
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

  void _showInviteCodeDialog(String groupId, String groupName) {
    // For now, we'll use the group ID as the invite code
    // In a real implementation, you might want to generate shorter codes
    final inviteCode = groupId.substring(0, 8).toUpperCase();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          'Group Created: $groupName',
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Your private group has been created! Share this invite code with friends to let them join:',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      inviteCode,
                      style: const TextStyle(
                        color: Colors.cyanAccent,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, color: Colors.cyanAccent),
                    onPressed: () {
                      // Copy to clipboard functionality would go here
                      showSnackBar(context, 'Invite code copied to clipboard!');
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'You can also share the invite code later from the group chat.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close group actions dialog
              // Use addPostFrameCallback to ensure context is valid for navigation
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  // Navigate to the new group
                  _openChatGroup(groupId, groupName);
                }
              });
            },
            child:
                const Text('Go to Group', style: TextStyle(color: Colors.cyan)),
          ),
        ],
      ),
    );
  }

  void _openChatGroup(String groupId, String groupName) {
    // Use MaterialPageRoute instead of named route
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          chatType: ChatType.userGroup,
          chatGroupId: groupId,
          chatGroupName: groupName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final squadAsync = ref.watch(ln.lobbyNotifierProvider);
    final gameAsync = ref.watch(gameNotifierProvider);
    final gameState = gameAsync.maybeWhen(
        data: (state) => state, orElse: () => GameState.initial());

    final availableGames = squadAsync.maybeWhen(
      data: (squadState) => squadState.availableGames.isNotEmpty
          ? squadState.availableGames
          : gameState.availableGames.map((g) => g.toJson()).toList(),
      orElse: () => gameState.availableGames.map((g) => g.toJson()).toList(),
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Create a Group',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create a new group for chatting and coordinating.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),

          // Group name
          TextField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Group name',
              hintStyle: const TextStyle(color: Colors.grey),
              filled: true,
              fillColor: Colors.grey[800],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(Icons.group, color: Colors.cyanAccent),
            ),
          ),
          const SizedBox(height: 16),

          // Game focus selection - Multi-select with chips
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Selected games chips
              if (_selectedGames.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _selectedGames.map((game) {
                    return Chip(
                      label: Text(
                        game,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      backgroundColor: Colors.cyanAccent.withValues(alpha: 0.2),
                      deleteIcon: const Icon(Icons.close,
                          size: 16, color: Colors.cyanAccent),
                      onDeleted: () {
                        setState(() {
                          _selectedGames.remove(game);
                        });
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(
                            color: Colors.cyanAccent, width: 1),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],

              // Add game search field
              TypeAheadField<String>(
                builder: (context, controller, focusNode) {
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: _selectedGames.isEmpty
                          ? 'Game focus (optional)'
                          : 'Add another game',
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: Colors.grey[800],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon:
                          const Icon(Icons.games, color: Colors.cyanAccent),
                    ),
                  );
                },
                suggestionsCallback: (pattern) async {
                  // Always include "Any Game" option
                  List<String> suggestions = ['Any Game'];

                  // Add available games that haven't been selected yet
                  final unselectedGames = availableGames
                      .where((game) =>
                          !_selectedGames.contains(game['name'] as String))
                      .map((game) => game['name'] as String)
                      .toList();

                  if (pattern.isEmpty) {
                    suggestions.addAll(unselectedGames);
                  } else {
                    // Filter games based on search pattern
                    final filteredGames = unselectedGames
                        .where((game) =>
                            game.toLowerCase().contains(pattern.toLowerCase()))
                        .toList();
                    suggestions.addAll(filteredGames);

                    // If no local matches and pattern is long enough, search IGDB
                    if (filteredGames.isEmpty && pattern.length >= 2) {
                      try {
                        final gameNotifier =
                            ref.read(gameNotifierProvider.notifier);
                        final igdbResults =
                            await gameNotifier.fetchGamesFromIGDB(pattern);
                        final igdbGameNames = igdbResults
                            .where((game) =>
                                !_selectedGames.contains(game['name']))
                            .map((game) => game['name'] as String)
                            .toList();
                        suggestions.addAll(igdbGameNames);
                      } catch (e) {
                        // If IGDB fails, just continue with local suggestions
                      }
                    }
                  }

                  return suggestions;
                },
                itemBuilder: (context, suggestion) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      suggestion,
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                },
                onSelected: (suggestion) {
                  if (!_selectedGames.contains(suggestion)) {
                    setState(() {
                      _selectedGames.add(suggestion);
                    });
                  }
                },
                emptyBuilder: (context) => const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'No games found',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Privacy setting
          Row(
            children: [
              const Text(
                'Public Group',
                style: TextStyle(color: Colors.white),
              ),
              const Spacer(),
              Switch(
                value: _isPublic,
                onChanged: (value) => setState(() => _isPublic = value),
                activeThumbColor: Colors.cyanAccent,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _isPublic
                ? 'Anyone can find and join this group'
                : 'Only people with the invite code can join',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _createGroup,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.black)
                  : const Text('Create Group'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tab for browsing public groups
