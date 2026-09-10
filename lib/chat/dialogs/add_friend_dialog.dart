import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/message.dart';
import '../../utils.dart';
import '../chat_screen.dart';
import '../../presentation/notifiers/user_notifier.dart';
import '../../presentation/widgets/friend_search_widget.dart';
import '../../widgets/presence_badge_row.dart';

/// Dialog for adding friends and starting direct messages
class AddFriendDialog extends ConsumerStatefulWidget {
  const AddFriendDialog({super.key});

  @override
  ConsumerState<AddFriendDialog> createState() => _AddFriendDialogState();
}

class _AddFriendDialogState extends ConsumerState<AddFriendDialog>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _acceptFriendRequest(String requestId, String fromName) async {
    HapticFeedback.lightImpact();
    try {
      final userNotifier = ref.read(userNotifierProvider.notifier);
      await userNotifier.acceptFriendRequest(requestId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You are now friends with $fromName!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accepting friend request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _declineFriendRequest(String requestId) async {
    HapticFeedback.lightImpact();
    try {
      final userNotifier = ref.read(userNotifierProvider.notifier);
      await userNotifier.declineFriendRequest(requestId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Friend request declined'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error declining request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
        builder: (context) => ChatScreen(
          chatGroupId: chatId,
          chatGroupName: displayName,
          chatType: ChatType.dm,
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
                Tab(text: 'Search'),
                Tab(text: 'Requests'),
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
                  // Friend Requests Tab
                  _buildRequestsTab(scrollController),
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
    return const FriendSearchWidget(
      showDMButton: true,
      showAddButton: true,
    );
  }

  Widget _buildRequestsTab(ScrollController scrollController) {
    final requestsStream =
        ref.watch(userNotifierProvider.notifier).streamPendingRequests();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: requestsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.cyanAccent),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading friend requests',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final requests = snapshot.data ?? [];

        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mail_outline, size: 64, color: Colors.grey[600]),
                const SizedBox(height: 16),
                Text(
                  'No pending friend requests',
                  style: TextStyle(color: Colors.grey[400], fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            final requestId = request['id'] as String;
            final fromUid = request['from_uid'] as String;
            final message = request['message'] as String?;
            final createdAt = request['created_at'] as String?;

            // Display name would come from joined user data
            final fromName = safeDisplayName(fromUid); // Fallback to UID

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey[900],
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.purple.withOpacity(0.3),
                  child: Text(
                    fromName.isNotEmpty ? fromName[0].toUpperCase() : '?',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(
                  fromName,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (message != null && message.isNotEmpty)
                      Text(message,
                          style:
                              TextStyle(color: Colors.grey[400], fontSize: 12)),
                    if (createdAt != null)
                      Text(
                        'Received: ${_formatTimestamp(createdAt)}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 11),
                      ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      onPressed: () =>
                          _acceptFriendRequest(requestId, fromName),
                      tooltip: 'Accept',
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      onPressed: () => _declineFriendRequest(requestId),
                      tooltip: 'Decline',
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inDays > 0) return '${diff.inDays}d ago';
      if (diff.inHours > 0) return '${diff.inHours}h ago';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
      return 'Just now';
    } catch (e) {
      return '';
    }
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
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Error loading friends',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final friends = snapshot.data ?? [];

        if (friends.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey[600]),
                const SizedBox(height: 16),
                Text(
                  'No friends yet',
                  style: TextStyle(color: Colors.grey[400], fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Search for users to add them as friends!',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: friends.length,
          itemBuilder: (context, index) {
            final friend = friends[index];
            final friendUid = friend['friend_uid'] as String;
            final status = friend['status'] as String?;
            final createdAt = friend['created_at'] as String?;

            // Display name - fallback to UID
            final displayName = safeDisplayName(friendUid);

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey[900],
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.withOpacity(0.3),
                  child: Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(
                  displayName,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          status == 'accepted'
                              ? Icons.check_circle
                              : Icons.pending,
                          size: 12,
                          color: status == 'accepted'
                              ? Colors.green
                              : Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          status == 'accepted' ? 'Friend' : status ?? 'Unknown',
                          style:
                              TextStyle(color: Colors.grey[400], fontSize: 12),
                        ),
                      ],
                    ),
                    if (createdAt != null)
                      Text(
                        'Friends since ${_formatTimestamp(createdAt)}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 11),
                      ),
                    PresenceBadgesHost(userId: friendUid),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.message, color: Colors.cyanAccent),
                      onPressed: () => _startDMWithFriend(friendUid),
                      tooltip: 'Start DM',
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline,
                          color: Colors.red),
                      onPressed: () =>
                          _showRemoveFriendConfirmation(friendUid, displayName),
                      tooltip: 'Remove Friend',
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showRemoveFriendConfirmation(String friendId, String displayName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title:
            const Text('Remove Friend?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to remove $displayName from your friends?',
          style: TextStyle(color: Colors.grey[300]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _removeFriend(friendId);
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
