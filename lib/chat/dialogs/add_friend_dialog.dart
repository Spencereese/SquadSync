import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as p;
import '../../domain/entities/message.dart';
import '../../utils.dart';
import '../chat_screen.dart';
import '../chat_state.dart';
import '../../presentation/notifiers/user_notifier.dart';

/// Dialog for adding friends and starting direct messages
class AddFriendDialog extends ConsumerStatefulWidget {
  const AddFriendDialog({super.key});

  @override
  ConsumerState<AddFriendDialog> createState() => _AddFriendDialogState();
}

class _AddFriendDialogState extends ConsumerState<AddFriendDialog>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.length >= 2) {
      final userNotifier = ref.read(userNotifierProvider.notifier);
      final results = await userNotifier.searchUsers(query);
      if (mounted) setState(() => _searchResults = results);
    } else {
      if (mounted) setState(() => _searchResults = []);
    }
  }

  Future<void> _startDM(Map<String, dynamic> user) async {
    Navigator.pop(context); // Close search
    await ref.read(userNotifierProvider.notifier).startDMThread(user['uid']);
    final chatId = 'dm_${user['uid']}'; // Temporary chat ID generation
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => p.ChangeNotifierProvider<ChatState>(
          create: (_) => ChatState(),
          child: ChatScreen(
            chatGroupId: chatId,
            chatGroupName: safeDisplayName(user['displayName'] as String?),
            chatType: ChatType.dm,
          ),
        ),
      ),
    );
  }

  Future<void> _startDMWithFriend(String? friendId) async {
    if (friendId == null) return;
    Navigator.pop(context); // Close dialog
    await ref.read(userNotifierProvider.notifier).startDMThread(friendId);
    final chatId = 'dm_${friendId}'; // Temporary chat ID generation
    final displayName = ref
            .read(userNotifierProvider.notifier)
            .getDisplayNameForUid(friendId) ??
        'Unknown';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => p.ChangeNotifierProvider<ChatState>(
          create: (_) => ChatState(),
          child: ChatScreen(
            chatGroupId: chatId,
            chatGroupName: displayName,
            chatType: ChatType.dm,
          ),
        ),
      ),
    );
  }

  Future<void> _removeFriend(String? friendId) async {
    if (friendId == null) return;
    final userNotifier = ref.read(userNotifierProvider.notifier);
    await userNotifier.removeFriend(friendId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Friend removed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  const Text(
                    'Add Friend',
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
            ),
            // Tabs
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Search Users'),
                Tab(text: 'Friends'),
              ],
              labelColor: Colors.cyanAccent,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.cyanAccent,
            ),
            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Search Users Tab
                  _buildSearchTab(scrollController),
                  // Friends Tab
                  _buildFriendsTab(scrollController),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchTab(ScrollController scrollController) {
    return Column(
      children: [
        // Search
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search users...',
              hintStyle: TextStyle(color: Colors.grey[400]),
              filled: true,
              fillColor: Colors.grey[800],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon: IconButton(
                icon: const Icon(Icons.send, color: Colors.cyanAccent),
                onPressed: () => _searchUsers(_searchController.text.trim()),
              ),
            ),
            onSubmitted: _searchUsers,
          ),
        ),
        // Results
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              final user = _searchResults[index];
              final displayName =
                  safeDisplayName(user['displayName'] as String?);
              final profileImage = user['profileImage'];
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage:
                      profileImage != null ? NetworkImage(profileImage) : null,
                  child: profileImage == null
                      ? Text(displayName.isNotEmpty
                          ? displayName[0].toUpperCase()
                          : '?')
                      : null,
                ),
                title: Text(displayName,
                    style: const TextStyle(color: Colors.white)),
                subtitle: Text('@${user['uid']}',
                    style: TextStyle(color: Colors.grey[400])),
                trailing: ElevatedButton(
                  onPressed: () => _startDM(user),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Start DM'),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFriendsTab(ScrollController scrollController) {
    final friendsStream =
        ref.watch(userNotifierProvider.notifier).streamFriends();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: friendsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.cyanAccent),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading friends: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        final friends = snapshot.data ?? [];

        if (friends.isEmpty) {
          return const Center(
            child: Text(
              'No friends yet. Search for users to add them as friends!',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          );
        }

        return ListView.builder(
          controller: scrollController,
          itemCount: friends.length,
          itemBuilder: (context, index) {
            final friend = friends[index];
            final friendId = friend['id'] as String?;
            final displayName =
                safeDisplayName(friend['displayName'] as String?);

            return ListTile(
              leading: CircleAvatar(
                child: Text(displayName.isNotEmpty
                    ? displayName[0].toUpperCase()
                    : '?'),
              ),
              title: Text(displayName,
                  style: const TextStyle(color: Colors.white)),
              subtitle:
                  Text('Friend', style: TextStyle(color: Colors.grey[400])),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.message, color: Colors.cyanAccent),
                    onPressed: () => _startDMWithFriend(friendId),
                    tooltip: 'Start DM',
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                    onPressed: () => _removeFriend(friendId),
                    tooltip: 'Remove Friend',
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
