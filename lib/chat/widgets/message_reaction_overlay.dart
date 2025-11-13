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

    return GestureDetector(
      onTap: widget.onDismiss,
      child: Container(
        color: Colors.black.withValues(alpha: 0.3), // Simplified backdrop
        child: Stack(
          children: [
            // Reaction buttons positioned above message (centered like iMessage)
            Positioned(
              top: widget.messagePosition != null
                  ? (widget.messagePosition!.dy - 120).clamp(20, MediaQuery.of(context).size.height - 200) // Position above message with bounds
                  : MediaQuery.of(context).size.height * 0.3,
              left: 20,
              right: 20,
              child: AnimatedBuilder(
                animation: Listenable.merge([_scaleAnimation, _fadeAnimation]),
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Reaction emojis row
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width - 40,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(
                                  alpha: 0.7), // iMessage-style dark grey
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.transparent, width: 0), // Explicitly no border
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
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
                                      padding: const EdgeInsets.all(8),
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 2),
                                      child: Text(
                                        emoji,
                                        style: const TextStyle(fontSize: 24),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Message content
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width - 40,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(
                                  alpha: 0.7), // iMessage-style dark grey
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: MessageContent(
                              message: widget.messageData,
                              isFromCurrentUser: widget.isMe,
                              chatGroupId: widget.chatGroupId,
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Action buttons below
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width - 40,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(
                                  alpha: 0.7), // iMessage-style dark grey
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.transparent, width: 0), // Explicitly no border
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              physics: const NeverScrollableScrollPhysics(), // Disable scrolling for action buttons
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
                        ],
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
          children: [
            Icon(
              icon,
              size: 20,
              color: color ?? Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: color ?? Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
