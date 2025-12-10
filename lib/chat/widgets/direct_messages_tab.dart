import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../../services/auth_service_supabase.dart';
import '../../services/supabase_service.dart';
import '../chat_screen.dart';
import '../../domain/entities/message.dart';
import '../../utils.dart';

class DirectMessagesTab extends StatelessWidget {
  const DirectMessagesTab({super.key});

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'now';
    }
  }

  Future<Map<String, dynamic>?> _getUserProfile(String userId) async {
    try {
      final profile = await SupabaseService.client
          .from('users')
          .select()
          .eq('uid', userId)
          .maybeSingle();
      return profile;
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
      return null;
    }
  }

  void _openDMChat(BuildContext context, String chatId, String displayName) {
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

  void _showAddFriendDialog(BuildContext context) {
    final searchController = TextEditingController();
    List<Map<String, dynamic>> searchResults = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => DraggableScrollableSheet(
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
                // Search
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search users...',
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: Colors.grey[800],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    ),
                    onChanged: (query) async {
                      if (query.trim().isEmpty) {
                        setState(() => searchResults = []);
                        return;
                      }

                      try {
                        // For now, we'll show a simple message
                        // In a real implementation, this would search users
                        setState(() => searchResults = []);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('Friend search not implemented yet')),
                        );
                      } catch (e) {
                        debugPrint('Error searching users: $e');
                      }
                    },
                  ),
                ),
                // Results
                Expanded(
                  child: searchResults.isEmpty
                      ? const Center(
                          child: Text(
                            'Start typing to search for friends',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: searchResults.length,
                          itemBuilder: (context, index) {
                            final user = searchResults[index];
                            final displayName =
                                safeDisplayName(user['displayName']);

                            return ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Colors.grey,
                                child: Icon(Icons.person, color: Colors.white),
                              ),
                              title: Text(
                                displayName,
                                style: const TextStyle(color: Colors.white),
                              ),
                              onTap: () {
                                // Add friend logic would go here
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content:
                                          Text('Added $displayName as friend')),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final supabase.User currentUser = AuthServiceSupabase().currentUser!;

    return FutureBuilder<List<Map<String, dynamic>>>(
      key: ValueKey('dm_list_${currentUser.id}'),
      future: SupabaseService.client
          .from('chats')
          .select()
          .contains('participants', [currentUser.id]).order('last_message_time',
              ascending: false),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: Colors.white),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.cyanAccent),
          );
        }

        final chats = snapshot.data ?? [];
        final dmChats = chats.where((data) {
          final participants = List<String>.from(data['participants'] ?? []);
          return participants.length == 2;
        }).toList();

        if (dmChats.isEmpty) {
          return Container(
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.message,
                    size: 64,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No direct messages yet',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add a friend to start chatting!',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.cyanAccent,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: InkWell(
                      onTap: () => _showAddFriendDialog(context),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person_add,
                            color: Colors.black,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Add Friend',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: dmChats.length,
          separatorBuilder: (context, index) => const Divider(
            color: Colors.grey,
            height: 0.5,
            indent: 72,
            thickness: 0.5,
          ),
          itemBuilder: (context, index) {
            final chat = dmChats[index];
            final chatData = chat;
            final participants =
                List<String>.from(chatData['participants'] ?? []);
            final otherUserId =
                participants.firstWhere((id) => id != currentUser.id);
            final lastMessage = chatData['last_message'] ?? '';
            final lastMessageTime = chatData['last_message_time'];
            final unreadCount =
                (chatData['unread_count'] as Map?)?[currentUser.id] ?? 0;

            return FutureBuilder<Map<String, dynamic>?>(
              future: _getUserProfile(otherUserId),
              builder: (context, userSnapshot) {
                final userData = userSnapshot.data;
                final displayName = safeDisplayName(userData?['display_name']);
                final profileImage = userData?['profile_image'];

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  leading: CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.grey[800],
                    backgroundImage: profileImage != null
                        ? NetworkImage(profileImage)
                        : null,
                    child: profileImage == null
                        ? Text(
                            displayName.isNotEmpty
                                ? displayName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 16),
                          )
                        : null,
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (lastMessageTime != null) ...[
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            _formatTime(lastMessageTime.toDate()),
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      lastMessage.isNotEmpty
                          ? lastMessage
                          : 'Start a conversation',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  trailing: unreadCount > 0
                      ? Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.cyanAccent,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : null,
                  onTap: () => _openDMChat(context, chat['id'], displayName),
                );
              },
            );
          },
        );
      },
    );
  }
}
