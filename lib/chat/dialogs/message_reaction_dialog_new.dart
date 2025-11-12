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
          // Subtle backdrop
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
            child: Container(
              color: Colors.black.withValues(alpha: 0.05),
            ),
          ),
          // Compact menu positioned near center
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Emoji reactions row - more compact
                Container(
                  margin: const EdgeInsets.only(bottom: 8.0),
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...quickReactions.map((emoji) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6.0),
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              widget.onEmojiSelect(emoji);
                              Navigator.pop(context);
                            },
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                        );
                      }),
                      // Add custom reaction button
                      Padding(
                        padding: const EdgeInsets.only(left: 4.0),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _showReactionInput = !_showReactionInput;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _showReactionInput ? Icons.close : Icons.add,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().slideY(
                      duration: const Duration(milliseconds: 300),
                      begin: -0.1,
                      end: 0.0,
                      curve: Curves.easeOutBack,
                    ),
                // Custom reaction input (when expanded)
                if (_showReactionInput)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8.0),
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: SizedBox(
                      width: 200,
                      child: TextField(
                        controller: _reactionController,
                        decoration: InputDecoration(
                          hintText: 'Type reaction...',
                          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8.0),
                        ),
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        textAlign: TextAlign.center,
                        onSubmitted: (value) {
                          if (value.isNotEmpty) {
                            widget.onEmojiSelect(value);
                            Navigator.pop(context);
                          }
                        },
                      ),
                    ),
                  ).animate().fadeIn(
                        duration: const Duration(milliseconds: 200),
                      ),
                // Action buttons - more compact, iMessage-style
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(12),
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
                      Divider(height: 1, color: Colors.white.withValues(alpha: 0.1)),
                      _buildActionTile(
                        icon: Icons.copy,
                        label: 'Copy',
                        onTap: () {
                          Navigator.pop(context);
                          widget.onCopy();
                        },
                      ),
                      Divider(height: 1, color: Colors.white.withValues(alpha: 0.1)),
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
                ).animate().slideY(
                      duration: const Duration(milliseconds: 300),
                      begin: 0.1,
                      end: 0.0,
                      curve: Curves.easeOutBack,
                      delay: const Duration(milliseconds: 100),
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
      onTap: onTap,
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
