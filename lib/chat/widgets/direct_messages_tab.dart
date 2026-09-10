import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/chat_list_loader.dart';
import '../../services/auth_service_supabase.dart';
import '../../services/supabase_service.dart';
import '../../widgets/chat_surface_feedback.dart';
import '../chat_screen.dart';
import '../dialogs/add_friend_dialog.dart';
import '../../domain/entities/message.dart';
import '../../utils.dart';

class DirectMessagesTab extends ConsumerStatefulWidget {
  const DirectMessagesTab({super.key});

  @override
  ConsumerState<DirectMessagesTab> createState() => _DirectMessagesTabState();
}

class _DirectMessagesTabState extends ConsumerState<DirectMessagesTab> {
  int _loadGeneration = 0;

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
    debugPrint('Opening DM chat: $chatId with $displayName');
    Navigator.of(context).push(
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddFriendDialog(),
    );
  }

  Future<ChatListLoad<Map<String, dynamic>>> _loadDms() {
    return loadChatList(fetch: () async {
      final currentUser = AuthServiceSupabase().currentUser;
      if (currentUser == null) return <Map<String, dynamic>>[];
      final rows = await SupabaseService.client
          .from('chat_groups')
          .select()
          .contains('member_uids', [currentUser.id])
          .eq('is_dm', true)
          .order('updated_at', ascending: false);
      return List<Map<String, dynamic>>.from(rows as List);
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = AuthServiceSupabase().currentUser;

    return FutureBuilder<ChatListLoad<Map<String, dynamic>>>(
      key: ValueKey('dm_list_${currentUser?.id}_$_loadGeneration'),
      future: _loadDms(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const ChatSurfaceFeedback(
            kind: ChatSurfaceKind.list,
            phase: ChatSurfacePhase.loading,
          );
        }

        if (snapshot.hasError || snapshot.data?.hasError == true) {
          return ChatSurfaceFeedback(
            kind: ChatSurfaceKind.list,
            phase: ChatSurfacePhase.error,
            error: snapshot.error ?? snapshot.data?.error,
            onRetry: () => setState(() => _loadGeneration++),
          );
        }

        final chats = snapshot.data?.items ?? [];
        final dmChats = chats.where((data) {
          final participants = List<String>.from(data['participants'] ?? []);
          return participants.length == 2;
        }).toList();

        if (dmChats.isEmpty) {
          return ChatSurfaceFeedback(
            kind: ChatSurfaceKind.list,
            phase: ChatSurfacePhase.empty,
            message: 'No direct messages yet',
            hint: 'Add a friend to start chatting!',
            onAction: () => _showAddFriendDialog(context),
            actionLabel: 'Add Friend',
          );
        }

        if (currentUser == null) {
          return ChatSurfaceFeedback(
            kind: ChatSurfaceKind.list,
            phase: ChatSurfacePhase.error,
            error: 'Not signed in',
            onRetry: () => setState(() => _loadGeneration++),
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
                final profileImage =
                    userData?['photo_url']; // Changed from profile_image

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
