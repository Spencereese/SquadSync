import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
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
  final _searchController = TextEditingController();
  final _codeController = TextEditingController();
  final _authService = AuthServiceSupabase();
  bool _isPublic = false; // Default to private
  bool _isLoading = false;
  bool _isJoining = false;
  final List<String> _selectedGames = ['Any Game']; // Default to "Any Game"
  final Set<String> _selectedFriendUids = {};
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _suggestedGroups = [];

  @override
  void initState() {
    super.initState();
    _loadSuggestedGroups();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  /// Create group - allows zero members (just yourself)
  // ignore: unused_element
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

      // Build description with games (exclude "Any Game")
      final gamesList = _selectedGames.where((g) => g != 'Any Game').toList();
      final description =
          gamesList.isNotEmpty ? 'Games: ${gamesList.join(", ")}' : null;

      // Create group
      final newGroup = await chatNotifier.createGroup(
        groupName,
        _isPublic,
        description: description,
      );

      if (mounted && newGroup != null) {
        // Add selected friends to group (without requiring acceptance)
        if (_selectedFriendUids.isNotEmpty) {
          try {
            // Use joinGroup method for each friend (automatically adds them)
            for (final friendUid in _selectedFriendUids) {
              try {
                await SupabaseService.client.rpc(
                  'append_group_member',
                  params: {
                    'group_id': newGroup.id,
                    'user_id': friendUid,
                  },
                );
              } catch (e) {
                debugPrint('Error adding friend $friendUid: $e');
              }
            }
          } catch (e) {
            debugPrint('Error adding friends to group: $e');
            // Don't fail group creation if friend-adding fails
          }
        }

        Navigator.pop(context);
        showSnackBar(context, 'Group "$groupName" created successfully!');

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
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadSuggestedGroups() async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    try {
      final response = await SupabaseService.client
          .from('chat_groups')
          .select()
          .eq('is_public', true)
          .order('created_at', ascending: false)
          .limit(5);

      final results = <Map<String, dynamic>>[];
      for (var data in (response as List<dynamic>)) {
        final groupData = data as Map<String, dynamic>;
        final members = List<String>.from(groupData['member_uids'] ?? []);
        final isAlreadyMember = members.contains(currentUser.id);

        if (!isAlreadyMember) {
          results.add({
            'id': groupData['id'],
            'data': groupData,
            'type': 'user_group',
          });
        }
      }

      if (mounted) {
        setState(() => _suggestedGroups = results);
      }
    } catch (e) {
      debugPrint('Error loading suggested groups: $e');
    }
  }

  Future<void> _joinGroup() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      showSnackBar(context, 'Please enter an invite code');
      return;
    }

    setState(() => _isJoining = true);

    try {
      final response = await SupabaseService.client
          .from('chat_groups')
          .select()
          .eq('invite_code', code)
          .maybeSingle();

      if (response == null) {
        if (mounted) {
          showSnackBar(context, 'Invalid invite code');
        }
        return;
      }

      final groupId = response['id'];
      final groupData = response;
      await _joinPublicGroup(groupId, groupData);
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
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', groupId);

      // Add group to user's user_groups array
      final userResponse = await SupabaseService.client
          .from('users')
          .select('user_groups')
          .eq('uid', currentUser.id)
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
            .update({'user_groups': userGroups}).eq('uid', currentUser.id);
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

/// Tab for creating a new group with optional members and games
/// Tab for browsing public groups
