import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/message_data.dart';
import '../message_bubble.dart';
import '../chat_service.dart';
import '../../domain/entities/message.dart';

/// Widget for displaying a group of messages with proper grouping by sender
class MessageGroup extends StatefulWidget {
  final List<MessageData> messages;
  final bool showSender;
  final bool showTimestamp;
  final bool showReadIndicator;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Map<String, bool> sendingStatus;
  final String? chatGroupId;
  final ChatType chatType;
  final ChatService? chatService;
  final String? squadId;

  const MessageGroup({
    super.key,
    required this.messages,
    required this.showSender,
    required this.showTimestamp,
    required this.showReadIndicator,
    required this.onTap,
    required this.onLongPress,
    required this.sendingStatus,
    this.chatGroupId,
    required this.chatType,
    this.chatService,
    this.squadId,
  });

  @override
  State<MessageGroup> createState() => _MessageGroupState();
}

class _MessageGroupState extends State<MessageGroup> {
  @override
  Widget build(BuildContext context) {
    // Group messages by consecutive sender
    final groupedMessages = _groupMessagesBySender(widget.messages);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timestamp header if needed (use first message)
        if (widget.messages.isNotEmpty &&
            widget.messages.first.shouldShowTimestamp)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Text(
                  _formatTimestamp(widget.messages.first.timestamp),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),

        // Render grouped messages
        ...groupedMessages.map((group) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Add margin between groups (12px)
              if (groupedMessages.indexOf(group) > 0)
                const SizedBox(height: 12),

              // Render messages in this group
              ...group.asMap().entries.map((entry) {
                final index = entry.key;
                final message = entry.value;
                final isFirstInGroup = index == 0 ||
                    group[index - 1].senderUid != message.senderUid;
                final isLastInGroup = index == group.length - 1 ||
                    group[index + 1].senderUid != message.senderUid;
                final isMe = message.senderUid == _getCurrentUserId();

                return Padding(
                  padding: EdgeInsets.only(
                    // 3px margin between messages in same group
                    top: index > 0 ? 3.0 : 0.0,
                  ),
                  child: MessageBubble(
                    message: message,
                    isMe: isMe,
                    showSender: widget.showSender,
                    showAvatar: isLastInGroup &&
                        !isMe, // Only show avatar on last message of group for received messages
                    showTimestamp: widget.showTimestamp,
                    showReadIndicator: widget.showReadIndicator,
                    isFirstInGroup: isFirstInGroup,
                    isLastInGroup: isLastInGroup,
                    onTap: widget.onTap,
                    onLongPress: widget.onLongPress,
                    sendingStatus: widget.sendingStatus,
                    chatGroupId: widget.chatGroupId,
                    chatType: widget.chatType,
                    chatService: widget.chatService,
                    squadId: widget.squadId,
                  ),
                );
              }),
            ],
          );
        }),
      ],
    );
  }

  /// Group consecutive messages from the same sender
  List<List<MessageData>> _groupMessagesBySender(List<MessageData> messages) {
    final groups = <List<MessageData>>[];

    for (final message in messages) {
      if (groups.isEmpty || groups.last.last.senderUid != message.senderUid) {
        // Start a new group
        groups.add([message]);
      } else {
        // Add to existing group
        groups.last.add(message);
      }
    }

    return groups;
  }

  /// Get current user ID
  String? _getCurrentUserId() {
    return FirebaseAuth.instance.currentUser?.uid;
  }

  /// Format timestamp for display
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0) {
      // Today - show time
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      // Yesterday
      return 'Yesterday ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      // This week - show day name
      final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return '${days[timestamp.weekday - 1]} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else {
      // Older - show date
      return '${timestamp.month.toString().padLeft(2, '0')}/${timestamp.day.toString().padLeft(2, '0')} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
}
