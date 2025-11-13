import 'package:flutter/material.dart';
import '../models/message_data.dart';
import '../models/thread_data.dart';
import '../services/thread_service.dart';
import '../message_bubble.dart';
import '../../services/ai_service.dart';

/// Widget for displaying threaded message conversations
class ThreadBubble extends StatefulWidget {
  final ThreadData thread;
  final String currentUserId;
  final VoidCallback onTap;
  final bool showFullThread;
  final String? chatGroupId;
  final ChatType chatType;

  const ThreadBubble({
    super.key,
    required this.thread,
    required this.currentUserId,
    required this.onTap,
    this.showFullThread = false,
    this.chatGroupId,
    this.chatType = ChatType.userGroup, // Default to userGroup for threads
  });

  @override
  State<ThreadBubble> createState() => _ThreadBubbleState();
}

class _ThreadBubbleState extends State<ThreadBubble> {
  List<MessageData> _threadMessages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.showFullThread) {
      _loadThreadMessages();
    }
  }

  Future<void> _loadThreadMessages() async {
    final threadService = ThreadService();
    final messages = await threadService.getThreadMessages(widget.thread.id);
    if (mounted) {
      setState(() {
        _threadMessages = messages;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.showFullThread) {
      return _buildFullThreadView();
    } else {
      return _buildThreadPreview();
    }
  }

  Widget _buildThreadPreview() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thread header
              Row(
                children: [
                  Icon(
                    _getThreadIcon(),
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.thread.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildThreadBadge(),
                ],
              ),
              const SizedBox(height: 8),

              // Thread info
              Row(
                children: [
                  Text(
                    'Started by ${widget.thread.creatorName}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatTimeAgo(widget.thread.lastActivityAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Reply count and participants
              Row(
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.thread.getPreviewText(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  if (widget.thread.participantUids.length > 1) ...[
                    const SizedBox(width: 12),
                    Icon(
                      Icons.people_outline,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.thread.participantUids.length} participants',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFullThreadView() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Column(
      children: [
        // Thread header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(
            children: [
              Icon(
                _getThreadIcon(),
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.thread.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      'Started by ${widget.thread.creatorName} • ${widget.thread.getPreviewText()}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),

        // Thread messages
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: _threadMessages.length,
            itemBuilder: (context, index) {
              final message = _threadMessages[index];
              return _buildThreadedMessage(message, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildThreadedMessage(MessageData message, int index) {
    final depth = message.threadDepth;
    final isReply = depth > 0;

    return Row(
      children: [
        // Indentation for thread hierarchy
        SizedBox(width: depth * 32.0),

        // Thread line indicator
        if (isReply) ...[
          Container(
            width: 2,
            height: 40,
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            margin: const EdgeInsets.only(right: 8),
          ),
        ] else ...[
          const SizedBox(width: 10),
        ],

        // Message bubble
        Expanded(
          child: MessageBubble(
            message: message.toMap(),
            isMe: message.senderUid == widget.currentUserId,
            showSender: true,
            showAvatar: true,
            showTimestamp: true,
            showReadIndicator: false,
            onTap: () {},
            onLongPress: () {},
            sendingStatus: const {},
            chatGroupId: widget.chatGroupId,
            chatType: widget.chatType,
          ),
        ),
      ],
    );
  }

  Widget _buildThreadBadge() {
    if (widget.thread.replyCount == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'New',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '${widget.thread.replyCount}',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  IconData _getThreadIcon() {
    switch (widget.thread.type) {
      case ThreadType.question:
        return Icons.help_outline;
      case ThreadType.discussion:
        return Icons.forum_outlined;
      case ThreadType.announcement:
        return Icons.campaign_outlined;
      case ThreadType.reply:
        return Icons.chat_bubble_outline;
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
