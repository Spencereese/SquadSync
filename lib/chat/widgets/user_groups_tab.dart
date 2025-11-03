import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../chat_screen.dart';
import '../chat_state.dart';
import '../../services/ai_service.dart';

class UserGroupsTab extends StatelessWidget {
  const UserGroupsTab({super.key});

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

  Widget _buildDMCard(BuildContext context) {
    return Consumer<ChatState>(
      builder: (context, chatState, child) {
        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          leading: CircleAvatar(
            radius: 28,
            backgroundColor: Colors.grey[800],
            child: const Icon(
              Icons.message,
              color: Colors.cyanAccent,
              size: 24,
            ),
          ),
          title: const Text(
            'Direct Messages',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          subtitle: const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Text(
              'Private conversations',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          trailing: chatState.dmUnreadCount > 0
              ? Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.cyanAccent,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    chatState.dmUnreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : null,
          onTap: () => chatState.setDMView(true),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final User currentUser = FirebaseAuth.instance.currentUser!;

    return StreamBuilder<QuerySnapshot>(
      key: ValueKey('user_groups_${currentUser.uid}'),
      stream: firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('chat_groups')
          .snapshots(),
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

        final groups = snapshot.data?.docs ?? [];

        // Sort groups by lastMessageTime in memory to avoid frequent rebuilds
        // caused by orderBy in Firestore query
        groups.sort((a, b) {
          final aTime = (a.data() as Map<String, dynamic>)['lastMessageTime']
              as Timestamp?;
          final bTime = (b.data() as Map<String, dynamic>)['lastMessageTime']
              as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime); // Descending order
        });

        return Container(
          color: Colors.black,
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: groups.length + 1, // +1 for DM card
            separatorBuilder: (context, index) => const Divider(
              color: Colors.grey,
              height: 0.5,
              indent: 72,
              thickness: 0.5,
            ),
            itemBuilder: (context, index) {
              if (index == 0) {
                // DM card
                return _buildDMCard(context);
              }

              final groupIndex = index - 1;
              final group = groups[groupIndex];
              final groupData = group.data() as Map<String, dynamic>;
              final groupName = groupData['name'] ?? 'Unnamed Group';
              final lastMessage = groupData['lastMessage'] ?? '';
              final lastMessageTime =
                  groupData['lastMessageTime'] as Timestamp?;
              final memberCount = groupData['memberCount'] ?? 0;
              final isPublic = groupData['isPublic'] ?? false;
              final imageUrl = groupData['imageUrl'];

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                leading: CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.grey[800],
                  backgroundImage:
                      imageUrl != null ? NetworkImage(imageUrl) : null,
                  child: imageUrl == null
                      ? Icon(
                          isPublic ? Icons.public : Icons.group,
                          color: Colors.cyanAccent,
                          size: 24,
                        )
                      : null,
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        groupName,
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
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastMessage.isNotEmpty
                              ? lastMessage
                              : '$memberCount members',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                onTap: () {
                  // Navigate to chat screen for this group
                  debugPrint(
                      'DEBUG UserGroupsTab: Tapping on user group ${group.id}');
                  if (group.id.isNotEmpty) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          chatType: ChatType.userGroup,
                          chatGroupId: group.id,
                        ),
                      ),
                    );
                  } else {
                    debugPrint(
                        'DEBUG UserGroupsTab: group id is invalid, not navigating');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Unable to open group chat')),
                    );
                  }
                },
              );
            },
          ),
        );
      },
    );
  }
}
