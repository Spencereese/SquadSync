import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../app_theme.dart';
import '../chat_state.dart';

/// Dialog for message reactions and actions (reply, copy, delete)
class MessageReactionDialog extends StatefulWidget {
  final dynamic message;
  final bool isMe;
  final Map<String, dynamic> data;
  final VoidCallback onReply;
  final VoidCallback onCopy;
  final VoidCallback onDelete;
  final Function(String) onEmojiSelect;
  final String? chatGroupId;

  const MessageReactionDialog({
    super.key,
    required this.message,
    required this.isMe,
    required this.data,
    required this.onReply,
    required this.onCopy,
    required this.onDelete,
    required this.onEmojiSelect,
    this.chatGroupId,
  });

  @override
  State<MessageReactionDialog> createState() => _MessageReactionDialogState();
}

class _MessageReactionDialogState extends State<MessageReactionDialog> {
  final TextEditingController _reactionController = TextEditingController();
  bool _showReactionInput = false;

  @override
  void dispose() {
    _reactionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = Provider.of<ChatState>(context, listen: false);
    final quickReactions = chatState.quickReactionEmojis;
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Stack(
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
            child: Container(
              color: Colors.black.withValues(alpha: 0.1),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Message preview (top, iMessage-style)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 12.0),
                    constraints: const BoxConstraints(maxWidth: 300),
                    decoration: BoxDecoration(
                      color: widget.isMe
                          ? AppTheme.accentColor.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 0.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: widget.isMe
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.data['content']?.isNotEmpty ?? false)
                          Text(
                            widget.data['content'],
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w400,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (widget.data['photos']?.isNotEmpty ?? false)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 60,
                                height: 60,
                                color: Colors.grey[700],
                                child: const Icon(
                                  Icons.image,
                                  color: Colors.white54,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(
                      duration: const Duration(milliseconds: 300),
                      delay: const Duration(milliseconds: 100),
                    ),
                // Emoji reactions row (below message, iMessage-style)
                Container(
                  margin: const EdgeInsets.only(top: 12.0),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 12.0),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...quickReactions.map((emoji) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              widget.onEmojiSelect(emoji);
                              Navigator.pop(context);
                            },
                            child: AnimatedScale(
                              scale: 1.0,
                              duration: const Duration(milliseconds: 100),
                              child: Text(
                                emoji,
                                style: const TextStyle(fontSize: 28),
                              ),
                            ),
                          ),
                        ).animate().scale(
                              duration: const Duration(milliseconds: 300),
                              begin: const Offset(0.8, 0.8),
                              end: const Offset(1.0, 1.0),
                              curve: Curves.elasticOut,
                              delay: Duration(
                                  milliseconds:
                                      (50 * quickReactions.indexOf(emoji))
                                          .toInt()),
                            );
                      }),
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() {
                              _showReactionInput = !_showReactionInput;
                            });
                          },
                          child: AnimatedScale(
                            scale: 1.0,
                            duration: const Duration(milliseconds: 100),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _showReactionInput ? Icons.close : Icons.add,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().slideY(
                      duration: const Duration(milliseconds: 400),
                      begin: -0.2,
                      end: 0.0,
                      curve: Curves.easeOutBack,
                    ),
                // Custom reaction input
                if (_showReactionInput)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 12.0),
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                            width: 0.5,
                          ),
                        ),
                        child: TextField(
                          controller: _reactionController,
                          decoration: InputDecoration(
                            hintText: 'Type your reaction...',
                            hintStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5)),
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 12.0),
                          ),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16),
                          onSubmitted: (value) {
                            if (value.isNotEmpty) {
                              widget.onEmojiSelect(value);
                              Navigator.pop(context);
                            }
                          },
                        ),
                      ),
                    ),
                  ).animate().slideY(
                        duration: const Duration(milliseconds: 300),
                        begin: 0.2,
                        end: 0.0,
                        curve: Curves.easeOutBack,
                      ),
                // Action buttons (more subtle, bottom sheet style)
                Container(
                  margin: const EdgeInsets.only(top: 16.0),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                          width: 0.5,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildActionTile(
                            icon: Icons.reply,
                            label: 'Reply',
                            onTap: () {
                              Navigator.pop(context);
                              widget.onReply();
                            },
                          ),
                          Divider(
                              height: 1,
                              color: Colors.white.withValues(alpha: 0.1)),
                          _buildActionTile(
                            icon: Icons.copy,
                            label: 'Copy',
                            onTap: () {
                              Navigator.pop(context);
                              widget.onCopy();
                            },
                          ),
                          Divider(
                              height: 1,
                              color: Colors.white.withValues(alpha: 0.1)),
                          _buildActionTile(
                            icon: Icons.delete,
                            label: 'Delete',
                            onTap: () {
                              Navigator.pop(context);
                              widget.onDelete();
                            },
                            isDestructive: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ).animate().slideY(
                      duration: const Duration(milliseconds: 400),
                      begin: 0.3,
                      end: 0.0,
                      curve: Curves.easeOutBack,
                      delay: const Duration(milliseconds: 200),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive
                  ? Colors.redAccent
                  : Colors.white.withValues(alpha: 0.8),
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: isDestructive
                    ? Colors.redAccent
                    : Colors.white.withValues(alpha: 0.9),
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
