import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/ai_service.dart';
import '../chat_state.dart';
import '../models/message_data.dart';
import '../services/reaction_service.dart';
import 'message_content.dart';

/// iMessage-style reaction overlay that appears above messages
class MessageReactionOverlay extends StatefulWidget {
  final MessageData messageData;
  final bool isMe;
  final String? chatGroupId;
  final ChatType chatType;
  final VoidCallback onDismiss;
  final VoidCallback onReply;
  final VoidCallback onCopy;
  final VoidCallback onDelete;
  final Function(String)? onEdit;
  final VoidCallback? onPin;
  final Offset? messagePosition; // Position of the message bubble
  final Size? messageSize; // Size of the message bubble

  const MessageReactionOverlay({
    super.key,
    required this.messageData,
    required this.isMe,
    this.chatGroupId,
    required this.chatType,
    required this.onDismiss,
    required this.onReply,
    required this.onCopy,
    required this.onDelete,
    this.onEdit,
    this.onPin,
    this.messagePosition,
    this.messageSize,
  });

  @override
  State<MessageReactionOverlay> createState() => _MessageReactionOverlayState();
}

class _MessageReactionOverlayState extends State<MessageReactionOverlay>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _fadeController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    // Start animations
    _scaleController.forward();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = Provider.of<ChatState>(context, listen: false);
    final quickReactions = chatState.quickReactionEmojis;
    final screenWidth = MediaQuery.of(context).size.width;
    final avatarSpace = 60.0; // Space for avatar (60px width + padding)
    final messageMaxWidth = screenWidth * 0.7;

    // Calculate positions based on message side
    final isMessageOnRight = widget.isMe;
    final messageAreaStart =
        isMessageOnRight ? screenWidth - messageMaxWidth - 16 : avatarSpace;
    final messageAreaEnd =
        isMessageOnRight ? screenWidth - 16 : screenWidth - avatarSpace;

    return GestureDetector(
      onTap: widget.onDismiss,
      child: Container(
        color: Colors.black.withValues(alpha: 0.3), // Simplified backdrop
        child: Stack(
          children: [
            // Reaction buttons - span full message area
            Positioned(
              top: widget.messagePosition != null
                  ? widget.messagePosition!.dy - 80 // Position above message
                  : MediaQuery.of(context).size.height * 0.3,
              left: messageAreaStart,
              right: screenWidth - messageAreaEnd,
              child: AnimatedBuilder(
                animation: Listenable.merge([_scaleAnimation, _fadeAnimation]),
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            mainAxisSize: MainAxisSize.max,
                            children: quickReactions.map((emoji) {
                              return GestureDetector(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  ReactionService.addReaction(
                                    context,
                                    emoji,
                                    widget.messageData.id,
                                    widget.chatGroupId,
                                    widget.chatType,
                                  );
                                  widget.onDismiss();
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 2),
                                  child: Text(
                                    emoji,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Message content - positioned in center, styled like original bubble
            Positioned(
              top: widget.messagePosition != null
                  ? widget.messagePosition!.dy - 20 // Slight upward movement
                  : MediaQuery.of(context).size.height * 0.45,
              left: messageAreaStart,
              right: screenWidth - messageAreaEnd,
              child: AnimatedBuilder(
                animation: Listenable.merge([_scaleAnimation, _fadeAnimation]),
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: Transform.scale(
                      scale:
                          _scaleAnimation.value * 1.05, // Slight growth effect
                      child: Align(
                        alignment: isMessageOnRight
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          constraints: BoxConstraints(
                            maxWidth: messageMaxWidth,
                          ),
                          decoration: BoxDecoration(
                            color: widget.isMe
                                ? const Color(
                                    0xFF007AFF) // iMessage blue for sent messages
                                : const Color(
                                    0xFF2C2C2E), // Dark gray for received messages
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(21),
                              topRight: const Radius.circular(21),
                              bottomLeft: widget.isMe
                                  ? const Radius.circular(21)
                                  : const Radius.circular(4),
                              bottomRight: widget.isMe
                                  ? const Radius.circular(4)
                                  : const Radius.circular(21),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: MessageContent(
                            message: widget.messageData,
                            isFromCurrentUser: widget.isMe,
                            chatGroupId: widget.chatGroupId,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Action menu - positioned on same side of message
            Positioned(
              top: widget.messagePosition != null
                  ? widget.messagePosition!.dy -
                      40 // Slightly above message center
                  : MediaQuery.of(context).size.height * 0.4,
              left: isMessageOnRight
                  ? (screenWidth - messageAreaEnd + 8)
                      .clamp(8.0, screenWidth - 148)
                  : null, // Right of message area for right-aligned messages, clamped to screen
              right: isMessageOnRight
                  ? null
                  : (messageAreaStart - 140).clamp(
                      8.0,
                      screenWidth -
                          148), // Left of message area for left-aligned messages, clamped to screen
              child: AnimatedBuilder(
                animation: Listenable.merge([_scaleAnimation, _fadeAnimation]),
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Container(
                        width: 140,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildActionButton(
                              icon: Icons.reply,
                              label: 'Reply',
                              onTap: () {
                                HapticFeedback.lightImpact();
                                widget.onReply();
                                widget.onDismiss();
                              },
                            ),
                            _buildActionButton(
                              icon: Icons.copy,
                              label: 'Copy',
                              onTap: () {
                                HapticFeedback.lightImpact();
                                widget.onCopy();
                                widget.onDismiss();
                              },
                            ),
                            if (widget.onEdit != null)
                              _buildActionButton(
                                icon: Icons.edit,
                                label: 'Edit',
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  _showEditDialog(context);
                                },
                              ),
                            if (widget.onPin != null)
                              _buildActionButton(
                                icon: Icons.push_pin,
                                label: 'Pin',
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  widget.onPin!();
                                  widget.onDismiss();
                                },
                              ),
                            _buildActionButton(
                              icon: Icons.delete,
                              label: 'Delete',
                              color: Colors.red,
                              onTap: () {
                                HapticFeedback.lightImpact();
                                widget.onDelete();
                                widget.onDismiss();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    widget.onDismiss(); // Dismiss the overlay first
    TextEditingController editController =
        TextEditingController(text: widget.messageData.text);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        title: const Text('Edit Message'),
        content: Semantics(
          label: 'Edit message',
          child: TextField(
            controller: editController,
            decoration: InputDecoration(
              hintText: 'Edit your message...',
              hintStyle: TextStyle(color: Colors.grey[600]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              widget.onEdit!(editController.text);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 20,
              color: color ?? Colors.white,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: color ?? Colors.white,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.none,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
