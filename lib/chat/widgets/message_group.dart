import 'package:flutter/material.dart';
import '../models/message_data.dart';
import '../message_bubble.dart';
import '../chat_service.dart';
import 'connecting_line_painter.dart';
import '../../domain/entities/message.dart';

/// Widget for displaying a message and its replies inline with connecting lines
class MessageGroup extends StatefulWidget {
  final MessageData parentMessage;
  final List<MessageData> replies;
  final bool isMe;
  final bool showSender;
  final bool showAvatar;
  final bool showTimestamp;
  final bool showReadIndicator;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Map<String, bool> sendingStatus;
  final String? chatGroupId;
  final ChatType chatType;
  final ChatService? chatService;

  const MessageGroup({
    super.key,
    required this.parentMessage,
    required this.replies,
    required this.isMe,
    required this.showSender,
    required this.showAvatar,
    required this.showTimestamp,
    required this.showReadIndicator,
    required this.onTap,
    required this.onLongPress,
    required this.sendingStatus,
    this.chatGroupId,
    required this.chatType,
    this.chatService,
  });

  @override
  State<MessageGroup> createState() => _MessageGroupState();
}

class _MessageGroupState extends State<MessageGroup> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timestamp header if needed
        if (widget.parentMessage.shouldShowTimestamp)
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
                  _formatTimestamp(widget.parentMessage.timestamp),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),

        // Parent message
        MessageBubble(
          message: widget.parentMessage,
          isMe: widget.isMe,
          showSender: widget.showSender,
          showAvatar: widget.showAvatar,
          showTimestamp: widget.showTimestamp,
          showReadIndicator: widget.showReadIndicator,
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          sendingStatus: widget.sendingStatus,
          chatGroupId: widget.chatGroupId,
          chatType: widget.chatType,
          chatService: widget.chatService,
        ),

        // Replies (if any)
        if (widget.replies.isNotEmpty) ...[
          ...widget.replies.asMap().entries.map((entry) {
            final index = entry.key;
            final reply = entry.value;
            final isLastReply = index == widget.replies.length - 1;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Connecting line
                SizedBox(
                  width: 60,
                  height: 40, // Approximate message bubble height
                  child: CustomPaint(
                    painter: ConnectingLinePainter(
                      isLast: isLastReply,
                      color: Colors.grey[600]!,
                    ),
                  ),
                ),

                // Reply message
                Expanded(
                  child: MessageBubble(
                    message: reply,
                    isMe: reply.senderUid == widget.parentMessage.senderUid,
                    showSender: true,
                    showAvatar: true,
                    showTimestamp: widget.showTimestamp,
                    showReadIndicator: widget.showReadIndicator,
                    onTap: widget.onTap,
                    onLongPress: widget.onLongPress,
                    sendingStatus: widget.sendingStatus,
                    chatGroupId: widget.chatGroupId,
                    chatType: widget.chatType,
                    chatService: widget.chatService,
                  ),
                ),
              ],
            );
          }),
        ],
      ],
    );
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
