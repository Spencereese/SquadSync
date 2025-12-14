import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../chat_screen.dart';
import '../../presentation/notifiers/chat_notifier.dart' as cn;
import '../../domain/entities/message.dart';
import '../../domain/entities/chat_state.dart';
import '../dialogs/group_actions_dialog.dart';
import '../../services/auth_service_supabase.dart';
import '../../services/supabase_service.dart';
import '../../utils.dart';

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

  Widget _buildDMStoryBar(BuildContext context) {
    final currentUser = AuthServiceSupabase().currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: SupabaseService.client
          .from('chat_groups')
          .select()
          .contains('member_uids', [currentUser.id])
          .eq('is_dm', true)
          .order('updated_at', ascending: false),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final dmChats = snapshot.data!.where((data) {
          final participants = List<String>.from(data['participants'] ?? []);
          return participants.length == 2;
        }).toList();

        if (dmChats.isEmpty) return const SizedBox.shrink();

        return Container(
          height: 100,
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            border: Border(
              bottom: BorderSide(
                color: Colors.grey.withOpacity(0.2),
                width: 0.5,
              ),
            ),
          ),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            itemCount: dmChats.length,
            itemBuilder: (context, index) {
              final chat = dmChats[index];
              final participants =
                  List<String>.from(chat['participants'] ?? []);
              final otherUserId = participants.firstWhere(
                (id) => id != currentUser.id,
                orElse: () => '',
              );

              return FutureBuilder<Map<String, dynamic>?>(
                future: _getUserProfile(otherUserId),
                builder: (context, userSnapshot) {
                  final userData = userSnapshot.data;
                  final displayName =
                      safeDisplayName(userData?['display_name']);
                  final profileImage = userData?['photo_url'];

                  return GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            chatGroupId: chat['id'],
                            chatGroupName: displayName,
                            chatType: ChatType.dm,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: 70,
                      margin: const EdgeInsets.only(right: 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.cyanAccent,
                                width: 2,
                              ),
                            ),
                            child: CircleAvatar(
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
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
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
    // Now shows ALL groups (squad, userGroup, dm) not just userChatGroups
    final groups = chatState.chatGroups.values
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
        child: Column(
          children: [
            // DM Story Bar at the top even when no groups
            _buildDMStoryBar(context),
            Expanded(
              child: Center(
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
                      'Create a group to start chatting!\n(Join groups from the Discover tab)',
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
      child: Column(
        children: [
          // DM Story Bar at the top
          _buildDMStoryBar(context),
          // Groups list
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: groups.length,
              separatorBuilder: (context, index) => const Divider(
                color: Colors.grey,
                height: 0.5,
                indent: 80,
                thickness: 0.5,
              ),
              itemBuilder: (context, index) {
                final group = groups[index];
                final groupId = group['id'] as String?;
                final groupName = (group['name'] as String?) ?? 'Unnamed Group';
                final lastMessageTime = group['last_message_time'] as String?;
                final memberCount = (group['member_count'] as int?) ?? 0;
                final isPublic = (group['is_public'] as bool?) ?? false;
                final imageUrl = group['image_url'] as String?;

                // Fetch last message details from chat_groups
                return FutureBuilder<Map<String, dynamic>?>(
                  future: groupId != null
                      ? SupabaseService.client
                          .from('chat_groups')
                          .select('last_message, last_message_sender_id')
                          .eq('id', groupId)
                          .maybeSingle()
                      : Future.value(null),
                  builder: (context, msgSnapshot) {
                    final lastMessage =
                        msgSnapshot.data?['last_message'] as String?;
                    final lastSenderId =
                        msgSnapshot.data?['last_message_sender_id'] as String?;

                    // Fetch sender display name if we have last message
                    return FutureBuilder<String?>(
                      future: lastSenderId != null
                          ? _getUserProfile(lastSenderId).then((profile) =>
                              safeDisplayName(profile?['display_name']))
                          : Future.value(null),
                      builder: (context, senderSnapshot) {
                        final senderName = senderSnapshot.data;
                        String subtitleText;

                        if (lastMessage != null &&
                            lastMessage.isNotEmpty &&
                            senderName != null) {
                          subtitleText = '$senderName: $lastMessage';
                        } else if (lastMessage != null &&
                            lastMessage.isNotEmpty) {
                          subtitleText = lastMessage;
                        } else {
                          subtitleText = '$memberCount members';
                        }

                        return _buildGroupTile(
                          context: context,
                          groupId: groupId,
                          groupName: groupName,
                          imageUrl: imageUrl,
                          isPublic: isPublic,
                          subtitleText: subtitleText,
                          lastMessageTime: lastMessageTime,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupTile({
    required BuildContext context,
    required String? groupId,
    required String groupName,
    required String? imageUrl,
    required bool isPublic,
    required String subtitleText,
    required String? lastMessageTime,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16, // Increased from 12 to make tiles larger
      ),
      leading: CircleAvatar(
        radius: 32, // Increased from 28 to make groups larger
        backgroundColor: Colors.grey[800],
        backgroundImage: imageUrl != null ? NetworkImage(imageUrl) : null,
        child: imageUrl == null
            ? Icon(
                isPublic ? Icons.public : Icons.group,
                color: Colors.cyanAccent,
                size: 28, // Increased from 24
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
                fontSize: 17, // Increased from 16
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
        padding: const EdgeInsets.only(top: 4), // Increased spacing
        child: Text(
          subtitleText,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          maxLines: 2, // Allow 2 lines for longer messages
          overflow: TextOverflow.ellipsis,
        ),
      ),
      onTap: () {
        // Navigate to chat screen for this group
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
        // Show leave group confirmation dialog
        if (groupId != null) {
          _showLeaveGroupDialog(context, groupId, groupName, ref);
        }
      },
    );
  }
}
