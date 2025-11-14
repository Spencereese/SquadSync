import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
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

    // Calculate positions - leave space on left for avatars, cover most screen width
    final leftOffset = avatarSpace + 8.0; // Avatar space + small padding
    final pillWidth =
        screenWidth - leftOffset - 16.0; // Cover most width, small right margin

    // Position above the message
    final pillTop = widget.messagePosition != null
        ? widget.messagePosition!.dy - 120 // Position well above message
        : MediaQuery.of(context).size.height * 0.3;

    // Connector position - depends on message alignment
    final isMessageOnRight = widget.isMe;
    final connectorX = isMessageOnRight
        ? screenWidth -
            120 // Near right edge for outgoing messages (upper left of bubble)
        : leftOffset +
            60; // Near left edge for incoming messages (upper right of bubble)

    return GestureDetector(
      onTap: widget.onDismiss,
      child: Container(
        color: Colors.transparent, // Allow backdrop filter to show through
        child: Stack(
          children: [
            // Backdrop blur for the entire overlay
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
              child: Container(
                color: Colors.black.withValues(alpha: 0.3),
              ),
            ),

            // Reactions pill - iMessage style
            Positioned(
              top: pillTop,
              left: leftOffset,
              child: AnimatedBuilder(
                animation: Listenable.merge([_scaleAnimation, _fadeAnimation]),
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Container(
                        width: pillWidth,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                            width: 0.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(25),
                          child: BackdropFilter(
                            filter:
                                ImageFilter.blur(sigmaX: 40.0, sigmaY: 40.0),
                            child: Container(
                              color: Colors.black.withValues(alpha: 0.1),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: Row(
                                children: [
                                  // Grey smiley connector (start)
                                  GestureDetector(
                                    onTap: () => _showEmojiPicker(context),
                                    child: Container(
                                      width: 36,
                                      height: 36,
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 4),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.grey.withValues(alpha: 0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.emoji_emotions_outlined,
                                        color: Colors.grey,
                                        size: 18,
                                      ),
                                    ),
                                  ),

                                  // Horizontal swipeable emoji list
                                  Expanded(
                                    child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      physics: const BouncingScrollPhysics(),
                                      padding: EdgeInsets.zero,
                                      itemCount: quickReactions.length +
                                          1, // +1 for end smiley
                                      itemBuilder: (context, index) {
                                        if (index == quickReactions.length) {
                                          // Grey smiley at the end
                                          return GestureDetector(
                                            onTap: () =>
                                                _showEmojiPicker(context),
                                            child: Container(
                                              width: 36,
                                              height: 36,
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.grey
                                                    .withValues(alpha: 0.2),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.emoji_emotions_outlined,
                                                color: Colors.grey,
                                                size: 18,
                                              ),
                                            ),
                                          );
                                        }

                                        final emoji = quickReactions[index];
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
                                            width: 36,
                                            height: 36,
                                            margin: const EdgeInsets.symmetric(
                                                horizontal: 1),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.transparent,
                                            ),
                                            child: Center(
                                              child: Text(
                                                emoji,
                                                style: const TextStyle(
                                                  fontSize: 22,
                                                  decoration:
                                                      TextDecoration.none,
                                                ),
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
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Visual connector - small bubble/tail with grey smiley
            Positioned(
              top: pillTop + 42, // Just below the pill, slightly nestled
              left: connectorX - 12, // Center the connector
              child: AnimatedBuilder(
                animation: Listenable.merge([_scaleAnimation, _fadeAnimation]),
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Container(
                        width: 24,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(12),
                            bottomRight: Radius.circular(12),
                            topLeft: Radius.circular(6),
                            topRight: Radius.circular(6),
                          ),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                            width: 0.5,
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            '😊',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Message content - positioned below the pill
            Positioned(
              top: widget.messagePosition != null
                  ? widget.messagePosition!.dy + 20 // Below the connector
                  : MediaQuery.of(context).size.height * 0.45,
              left: isMessageOnRight ? screenWidth - 300 : leftOffset,
              right: isMessageOnRight ? 16 : null,
              child: AnimatedBuilder(
                animation: Listenable.merge([_scaleAnimation, _fadeAnimation]),
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: Transform.scale(
                      scale: _scaleAnimation.value * 1.02,
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: 280,
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: widget.isMe
                              ? const Color(0xFF007AFF) // iMessage blue
                              : const Color(0xFF2C2C2E), // Dark gray
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
                  );
                },
              ),
            ),

            // Action menu - positioned on same side as message
            Positioned(
              top: widget.messagePosition != null
                  ? widget.messagePosition!.dy + 80
                  : MediaQuery.of(context).size.height * 0.5,
              left: isMessageOnRight
                  ? (screenWidth - 160).clamp(16.0, screenWidth - 164)
                  : leftOffset,
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

  void _showEmojiPicker(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.4,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Header with close button
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey, width: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Choose Reaction',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 20,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Emoji picker
              Expanded(
                child: EmojiPicker(
                  onEmojiSelected: (category, emoji) {
                    ReactionService.addReaction(
                      context,
                      emoji.emoji,
                      widget.messageData.id,
                      widget.chatGroupId,
                      widget.chatType,
                    );
                    Navigator.pop(context); // Close picker
                    widget.onDismiss(); // Dismiss overlay
                  },
                ),
              ),
            ],
          ),
        );
      },
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
