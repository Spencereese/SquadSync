import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../chat_screen.dart';
import '../../presentation/notifiers/chat_notifier.dart' as cn;
import '../../domain/entities/message.dart';
import '../dialogs/group_actions_dialog.dart';

class UserGroupsTab extends ConsumerWidget {
  final VoidCallback onTapDM;

  const UserGroupsTab({super.key, required this.onTapDM});

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

  void _showLeaveGroupDialog(
      BuildContext context, String groupId, String groupName, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text(
            'Leave Group',
            style: const TextStyle(color: Colors.white),
          ),
          content: Text(
            'Are you sure you want to leave "$groupName"?',
            style: const TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop(); // Close dialog first
                try {
                  await ref
                      .read(cn.chatNotifierProvider.notifier)
                      .leaveGroup(groupId);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('You left "$groupName"'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to leave group: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text(
                'Leave',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDMCard(BuildContext context, int dmUnreadCount) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
      trailing: dmUnreadCount > 0
          ? Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.cyanAccent,
                shape: BoxShape.circle,
              ),
              child: Text(
                dmUnreadCount.toString(),
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
      onTap: onTapDM,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        debugPrint(
            'UserGroupsTab: loaded ${groups.length} groups from Firestore');

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

        // If no groups, show empty state
        if (groups.isEmpty) {
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              _buildDMCard(context, 0),
              const SizedBox(height: 40),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.group_add,
                      size: 64,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No groups yet',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create a group or join an existing one\nto start chatting!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        // Open group actions dialog
                        showDialog(
                          context: context,
                          builder: (context) => const GroupActionsDialog(),
                        );
                      },
                      icon: const Icon(Icons.add, color: Colors.black),
                      label: const Text(
                        'Create or Join Group',
                        style: TextStyle(color: Colors.black),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyanAccent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        return ListView.separated(
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
              return _buildDMCard(context, 0);
            }

            final groupIndex = index - 1;
            final group = groups[groupIndex];
            final groupData = group.data() as Map<String, dynamic>;
            final groupName = groupData['name'] ?? 'Unnamed Group';
            final lastMessage = groupData['lastMessage'] ?? '';
            final lastMessageTime = groupData['lastMessageTime'] as Timestamp?;
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
                        chatGroupName: groupName,
                      ),
                    ),
                  );
                }
              },
              onLongPress: () {
                // Show leave group confirmation dialog
                _showLeaveGroupDialog(context, group.id, groupName, ref);
              },
            );
          },
        );
      },
    );
  }
}
