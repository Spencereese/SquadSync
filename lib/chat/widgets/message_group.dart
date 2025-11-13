import 'package:flutter/material.dart';
import '../models/message_data.dart';
import '../message_bubble.dart';
import 'connecting_line_painter.dart';
import '../../services/ai_service.dart';

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
  final VoidCallback? onViewThread;

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
    this.onViewThread,
  });

  @override
  State<MessageGroup> createState() => _MessageGroupState();
}

class _MessageGroupState extends State<MessageGroup> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        ),

        // Reply count label (if there are replies)
        if (widget.replies.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 60, top: 4, bottom: 4),
            child: GestureDetector(
              onTap: widget.onViewThread ??
                  () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
              child: Text(
                '${widget.replies.length} ${widget.replies.length == 1 ? 'Reply' : 'Replies'}',
                style: TextStyle(
                  color: Colors.blue[400],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],

        // Replies (if expanded)
        if (_isExpanded && widget.replies.isNotEmpty) ...[
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
                  ),
                ),
              ],
            );
          }),
        ],
      ],
    );
  }
}
