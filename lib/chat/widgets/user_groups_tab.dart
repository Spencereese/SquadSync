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
import 'group_chat_context_menu.dart';

class UserGroupsTab extends ConsumerStatefulWidget {
  final VoidCallback onTapDM;

  const UserGroupsTab({super.key, required this.onTapDM});

  @override
  ConsumerState<UserGroupsTab> createState() => _UserGroupsTabState();
}

class _UserGroupsTabState extends ConsumerState<UserGroupsTab> {
  // Cache futures to prevent constant rebuilds during scrolling
  final Map<String, Future<Map<String, dynamic>?>> _groupDataCache = {};
  final Map<String, Future<String?>> _userProfileCache = {};
  final Map<String, Future<Map<String, dynamic>>> _groupMetadataCache = {};

  // Debouncing for navigation to prevent rapid taps creating multiple channels
  String? _lastNavigatedGroupId;
  DateTime? _lastNavigationTime;
  static const _navigationDebounceMs = 500;

  @override
  void dispose() {
    _groupDataCache.clear();
    _userProfileCache.clear();
    _groupMetadataCache.clear();
    super.dispose();
  }

  Future<Map<String, dynamic>> _getGroupMetadata(String groupId) async {
    final currentUser = AuthServiceSupabase().currentUser;
    if (currentUser == null) return {};

    try {
      final userData = await SupabaseService.client
          .from('users')
          .select('user_groups')
          .eq('uid', currentUser.id)
          .maybeSingle();

      final userGroups =
          List<Map<String, dynamic>>.from(userData?['user_groups'] ?? []);
      final groupMeta = userGroups.firstWhere(
        (g) => g['id'] == groupId,
        orElse: () => <String, dynamic>{},
      );

      return groupMeta;
    } catch (e) {
      debugPrint('Error fetching group metadata: $e');
      return {};
    }
  }

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

    // Pre-fetch all metadata for sorting (will be cached for later use)
    for (var group in groups) {
      final groupId = group['id'] as String?;
      if (groupId != null && !_groupMetadataCache.containsKey(groupId)) {
        _groupMetadataCache[groupId] = _getGroupMetadata(groupId);
      }
    }

    // Sort groups: pinned first, then by last_message_time
    // Note: This is a simplified sort that doesn't wait for async metadata
    // The actual pinned status will be reflected when tiles render
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
                        // Open create group full-page screen
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const GroupActionsDialog(),
                          ),
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
              padding: const EdgeInsets.only(
                  top: 8,
                  bottom: 100), // Add bottom padding to avoid nav bar overlap
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
                final imageUrl = group['avatar_url'] as String?;

                // Fetch last message details from chat_groups (cached)
                if (groupId != null && !_groupDataCache.containsKey(groupId)) {
                  _groupDataCache[groupId] = SupabaseService.client
                      .from('chat_groups')
                      .select('last_message, last_message_sender_id')
                      .eq('id', groupId)
                      .maybeSingle();
                }

                // Fetch group metadata (mute, pin, unread, etc.) (cached)
                if (groupId != null &&
                    !_groupMetadataCache.containsKey(groupId)) {
                  _groupMetadataCache[groupId] = _getGroupMetadata(groupId);
                }

                return FutureBuilder<Map<String, dynamic>?>(
                  future: groupId != null
                      ? _groupDataCache[groupId]
                      : Future.value(null),
                  builder: (context, msgSnapshot) {
                    final lastMessage =
                        msgSnapshot.data?['last_message'] as String?;
                    final lastSenderId =
                        msgSnapshot.data?['last_message_sender_id'] as String?;

                    // Cache user profile lookup
                    if (lastSenderId != null &&
                        !_userProfileCache.containsKey(lastSenderId)) {
                      _userProfileCache[lastSenderId] =
                          _getUserProfile(lastSenderId).then((profile) =>
                              safeDisplayName(profile?['display_name']));
                    }

                    // Fetch sender display name if we have last message
                    return FutureBuilder<String?>(
                      future: lastSenderId != null
                          ? _userProfileCache[lastSenderId]
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

                        // Fetch metadata and build tile
                        return FutureBuilder<Map<String, dynamic>>(
                          future: groupId != null
                              ? _groupMetadataCache[groupId]
                              : Future.value({}),
                          builder: (context, metaSnapshot) {
                            final metadata = metaSnapshot.data ?? {};
                            return _buildGroupTile(
                              context: context,
                              groupId: groupId,
                              groupName: groupName,
                              imageUrl: imageUrl,
                              isPublic: isPublic,
                              subtitleText: subtitleText,
                              lastMessageTime: lastMessageTime,
                              isMuted: metadata['is_muted'] as bool? ?? false,
                              hasUnread:
                                  metadata['has_unread'] as bool? ?? false,
                              unreadCount:
                                  metadata['unread_count'] as int? ?? 0,
                              isPinned: metadata['is_pinned'] as bool? ?? false,
                            );
                          },
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
    bool isMuted = false,
    bool hasUnread = false,
    int unreadCount = 0,
    bool isPinned = false,
  }) {
    return InkWell(
      onTap: () async {
        // Navigate to chat screen for this group
        debugPrint('DEBUG UserGroupsTab: Tapping on user group $groupId');
        if (groupId == null || groupId.isEmpty) {
          debugPrint('ERROR: groupId is null or empty, cannot navigate');
          return;
        }

        // Debounce rapid navigation to prevent channel buildup
        final now = DateTime.now();
        if (_lastNavigatedGroupId == groupId && _lastNavigationTime != null) {
          final timeSinceLastNav =
              now.difference(_lastNavigationTime!).inMilliseconds;
          if (timeSinceLastNav < _navigationDebounceMs) {
            debugPrint(
                'UserGroupsTab: Debouncing rapid tap (${timeSinceLastNav}ms ago)');
            return;
          }
        }

        _lastNavigatedGroupId = groupId;
        _lastNavigationTime = now;

        try {
          // Load messages for this group first
          debugPrint('Loading messages for group: $groupId');
          await ref
              .read(cn.chatNotifierProvider.notifier)
              .loadMessages(groupId);

          if (!context.mounted) {
            debugPrint('Context not mounted, aborting navigation');
            return;
          }

          debugPrint(
              'Navigating to ChatScreen for group: $groupName ($groupId)');
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                chatType: ChatType.userGroup,
                chatGroupId: groupId,
                chatGroupName: groupName,
              ),
            ),
          );
          debugPrint('Returned from ChatScreen');
        } catch (e) {
          debugPrint('ERROR navigating to chat: $e');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to open chat: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      },
      onLongPress: () async {
        // Show context menu with all group actions
        if (groupId == null) return;

        // Fetch group metadata from users.user_groups
        final currentUser = AuthServiceSupabase().currentUser;
        if (currentUser == null) return;

        try {
          final userData = await SupabaseService.client
              .from('users')
              .select('user_groups')
              .eq('uid', currentUser.id)
              .maybeSingle();

          final userGroups =
              List<Map<String, dynamic>>.from(userData?['user_groups'] ?? []);
          final groupMeta = userGroups.firstWhere(
            (g) => g['id'] == groupId,
            orElse: () => <String, dynamic>{},
          );

          final isMuted = groupMeta['is_muted'] as bool? ?? false;
          final isPinned = groupMeta['is_pinned'] as bool? ?? false;

          // Check if user is creator
          final groupData = await SupabaseService.client
              .from('chat_groups')
              .select('created_by')
              .eq('id', groupId)
              .maybeSingle();
          final createdBy = groupData?['created_by'] as String? ?? '';
          final isCreator = createdBy == currentUser.id;

          if (!context.mounted) return;

          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            builder: (context) => GroupChatContextMenu(
              groupId: groupId,
              groupName: groupName,
              createdBy: createdBy,
              isMuted: isMuted,
              isPinned: isPinned,
              onMarkUnread: () async {
                await ref
                    .read(cn.chatNotifierProvider.notifier)
                    .markGroupAsUnread(groupId);
                if (context.mounted) Navigator.pop(context);
              },
              onTogglePinned: () async {
                await ref
                    .read(cn.chatNotifierProvider.notifier)
                    .togglePinGroup(groupId, isPinned);
                if (context.mounted) Navigator.pop(context);
              },
              onToggleMute: () async {
                await ref
                    .read(cn.chatNotifierProvider.notifier)
                    .toggleMuteGroup(groupId, isMuted);
                if (context.mounted) Navigator.pop(context);
              },
              onIgnore: () async {
                await ref
                    .read(cn.chatNotifierProvider.notifier)
                    .ignoreGroup(groupId);
                if (context.mounted) Navigator.pop(context);
              },
              onLeave: () async {
                Navigator.pop(context);
                _showLeaveGroupDialog(context, groupId, groupName, ref);
              },
              onDelete: isCreator
                  ? () async {
                      try {
                        await ref
                            .read(cn.chatNotifierProvider.notifier)
                            .deleteGroup(groupId);
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Deleted "$groupName"'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to delete: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    }
                  : null,
            ),
          );
        } catch (e) {
          debugPrint('Error showing context menu: $e');
        }
      },
      child: ListTile(
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
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Unread badge
            if (hasUnread && unreadCount > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.cyanAccent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  unreadCount > 99 ? '99+' : unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            // Pinned indicator
            if (isPinned) ...[
              const Icon(
                Icons.push_pin,
                color: Colors.amber,
                size: 18,
              ),
              const SizedBox(width: 8),
            ],
            // Muted indicator (on far right as requested)
            if (isMuted)
              const Icon(
                Icons.notifications_off,
                color: Colors.grey,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
