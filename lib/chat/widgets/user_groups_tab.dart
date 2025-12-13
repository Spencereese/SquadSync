import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../chat_screen.dart';
import '../../presentation/notifiers/chat_notifier.dart' as cn;
import '../../domain/entities/message.dart';
import '../../domain/entities/chat_state.dart';
import '../dialogs/group_actions_dialog.dart';

class UserGroupsTab extends ConsumerStatefulWidget {
  final VoidCallback onTapDM;

  const UserGroupsTab({super.key, required this.onTapDM});

  @override
  ConsumerState<UserGroupsTab> createState() => _UserGroupsTabState();
}

class _UserGroupsTabState extends ConsumerState<UserGroupsTab> {
  // No need to call loadUserGroups here - it's already called in ChatGroupsScreen
  // and we're watching the provider which will rebuild when state changes

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
      onTap: widget.onTapDM,
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatStateAsync = ref.watch(cn.chatNotifierProvider);

    return chatStateAsync.when(
      loading: () {
        return const Center(
          child: CircularProgressIndicator(color: Colors.cyanAccent),
        );
      },
      error: (error, stack) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Error: $error',
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.read(cn.chatNotifierProvider.notifier).loadUserGroups();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      },
      data: (chatState) => _buildContent(context, chatState),
    );
  }

  Widget _buildContent(BuildContext context, ChatState chatState) {
    // Convert ChatGroup entities to map format for compatibility
    final groups = chatState.userChatGroups.values
        .map((group) => {
              'id': group.id,
              'name': group.name,
              'is_public': group.isPublic,
              'member_uids': group.memberUids,
              'description': group.description,
              'avatar_url': group.avatarUrl,
              'last_message_time': group.lastActivity?.toIso8601String(),
              'member_count': group.memberCount,
            })
        .toList();

    // Sort groups by last_message_time in memory
    groups.sort((a, b) {
      final aTime = a['last_message_time'] as String?;
      final bTime = b['last_message_time'] as String?;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return DateTime.parse(bTime)
          .compareTo(DateTime.parse(aTime)); // Descending
    });

    // If no groups, show empty state
    if (groups.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          await ref.read(cn.chatNotifierProvider.notifier).loadUserGroups();
        },
        color: Colors.cyanAccent,
        child: ListView(
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
                      // Open create group dialog
                      showDialog(
                        context: context,
                        builder: (context) => const GroupActionsDialog(),
                      );
                    },
                    icon: const Icon(Icons.add, color: Colors.black),
                    label: const Text(
                      'Create Group',
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
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(cn.chatNotifierProvider.notifier).loadUserGroups();
      },
      color: Colors.cyanAccent,
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
            return _buildDMCard(context, 0);
          }

          final groupIndex = index - 1;
          final group = groups[groupIndex];
          final groupName = (group['name'] as String?) ?? 'Unnamed Group';
          final lastMessage = (group['last_message'] as String?) ?? '';
          final lastMessageTime = group['last_message_time'] as String?;
          final memberCount = (group['member_count'] as int?) ?? 0;
          final isPublic = (group['is_public'] as bool?) ?? false;
          final imageUrl = group['image_url'] as String?;

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            leading: CircleAvatar(
              radius: 28,
              backgroundColor: Colors.grey[800],
              backgroundImage: imageUrl != null ? NetworkImage(imageUrl) : null,
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
                      _formatTime(DateTime.parse(lastMessageTime)),
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
              final groupId = group['id'] as String?;
              debugPrint('DEBUG UserGroupsTab: Tapping on user group $groupId');
              if (groupId != null && groupId.isNotEmpty) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      chatType: ChatType.userGroup,
                      chatGroupId: groupId,
                      chatGroupName: groupName,
                    ),
                  ),
                );
              }
            },
            onLongPress: () {
              final groupId = group['id'] as String?;
              // Show leave group confirmation dialog
              if (groupId != null) {
                _showLeaveGroupDialog(context, groupId, groupName, ref);
              }
            },
          );
        },
      ),
    );
  }
}
