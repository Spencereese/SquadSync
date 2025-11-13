import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_state.dart';
import 'models/message_data.dart';
import 'widgets/message_content.dart';
import 'widgets/message_reactions.dart';
import 'widgets/message_avatar.dart';
import 'widgets/message_sender.dart';
import 'widgets/message_timestamp.dart';
import 'services/reaction_service.dart';
import '../services/ai_service.dart';
import 'chat_service.dart';
import 'widgets/message_reaction_overlay.dart';

/// Refactored MessageBubble using decomposed components
/// This replaces the 1183-line monolithic MessageBubble with a clean, maintainable structure
class MessageBubble extends StatefulWidget {
  final dynamic message; // Keep for backward compatibility during transition
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

  const MessageBubble({
    super.key,
    required this.message,
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
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with TickerProviderStateMixin {
  late MessageData _messageData;
  bool _isGrokExpanded = false; // Track if Grok message is expanded
  final GlobalKey _messageKey = GlobalKey(); // Key to get message position
  late AnimationController _positionController;
  late Animation<Offset> _positionAnimation;

  @override
  void initState() {
    super.initState();
    _normalizeMessageData();

    _positionController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _positionAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -60), // Move up by 60 pixels
    ).animate(CurvedAnimation(
      parent: _positionController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void didUpdateWidget(MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message != widget.message) {
      _normalizeMessageData();
    }
  }

  @override
  void dispose() {
    _positionController.dispose();
    super.dispose();
  }

  void _normalizeMessageData() {
    // Convert the dynamic message to MessageData
    if (widget.message is MessageData) {
      _messageData = widget.message;
    } else {
      // Fallback for backward compatibility - convert from old format
      _messageData =
          MessageData.fromMap(widget.message as Map<String, dynamic>);
    }
  }

  void _showMessageReactionOverlay(BuildContext context) {
    // Get the position and size of the message bubble
    final RenderBox? renderBox =
        _messageKey.currentContext?.findRenderObject() as RenderBox?;
    Offset? messagePosition;
    Size? messageSize;

    if (renderBox != null) {
      messagePosition = renderBox.localToGlobal(Offset.zero);
      messageSize = renderBox.size;
    }

    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => MessageReactionOverlay(
        messageData: _messageData,
        isMe: widget.isMe,
        chatGroupId: widget.chatGroupId,
        chatType: widget.chatType,
        messagePosition: messagePosition,
        messageSize: messageSize,
        onDismiss: () {
          overlayEntry.remove();
          _positionController.reverse(); // Animate message back down
        },
        onReply: () {
          final chatState = Provider.of<ChatState>(context, listen: false);
          chatState.setReplyToMessage(widget.message);
        },
        onCopy: () {
          Clipboard.setData(ClipboardData(text: _messageData.text));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Text copied')),
          );
        },
        onDelete: () async {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Delete Message'),
              content:
                  const Text('Are you sure you want to delete this message?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );
          if (confirm == true && context.mounted) {
            try {
              String collectionPath;
              final userId = FirebaseAuth.instance.currentUser?.uid;
              if (userId == null) return;

              if (widget.chatType == ChatType.userGroup) {
                collectionPath =
                    'users/$userId/chat_groups/${widget.chatGroupId}/messages';
              } else {
                // For DMs, use the chats collection
                collectionPath = 'chats/${widget.chatGroupId}/messages';
              }

              await FirebaseFirestore.instance
                  .collection(collectionPath)
                  .doc(_messageData.id)
                  .delete();

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Message deleted')),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to delete message: $e')),
                );
              }
            }
          }
        },
        onEdit: widget.isMe
            ? (String newText) async {
                // Implement edit functionality
                try {
                  String collectionPath;
                  final userId = FirebaseAuth.instance.currentUser?.uid;
                  if (userId == null) return;

                  if (widget.chatType == ChatType.userGroup) {
                    collectionPath =
                        'users/$userId/chat_groups/${widget.chatGroupId}/messages';
                  } else {
                    // For DMs, use the chats collection
                    collectionPath = 'chats/${widget.chatGroupId}/messages';
                  }

                  await FirebaseFirestore.instance
                      .collection(collectionPath)
                      .doc(_messageData.id)
                      .update({
                    'text': newText,
                    'edited': true,
                    'editedAt': FieldValue.serverTimestamp(),
                  });

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Message edited')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to edit message: $e')),
                    );
                  }
                }
              }
            : null,
        onPin: () async {
          // Implement pin functionality
          try {
            final chatService = ChatService();
            await chatService.pinMessage(
                _messageData.id, widget.chatGroupId, widget.chatType);

            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Message pinned')),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to pin message: $e')),
              );
            }
          }
        },
      ),
    );

    overlay.insert(overlayEntry);
    _positionController.forward(); // Animate message up
  }

  @override
  Widget build(BuildContext context) {
    // Check if this is a Grok AI message for unique styling
    if (_messageData.isGrokMessage) {
      return _buildGrokMessage(context);
    }

    // Standard layout for regular messages
    return SlideTransition(
      position: _positionAnimation,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: Column(
          crossAxisAlignment:
              widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (widget.showTimestamp &&
                _messageData.timestamp !=
                    DateTime.fromMillisecondsSinceEpoch(0))
              MessageTimestamp(timestamp: _messageData.timestamp),
            Row(
              mainAxisAlignment:
                  widget.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!widget.isMe && widget.showAvatar)
                  MessageAvatar(
                    senderName: _messageData.sender,
                    isFromCurrentUser: widget.isMe,
                  ),
                if (!widget.isMe && widget.showAvatar) const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: widget.isMe
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      if (widget.showSender && !widget.isMe)
                        MessageSender(message: _messageData),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _buildMessageContainer(context),
                          if (_messageData.reactions.isNotEmpty)
                            Positioned(
                              bottom: -8,
                              right: widget.isMe ? -8 : null,
                              left: widget.isMe ? null : -8,
                              child: MessageReactions(
                                reactions: _messageData.reactions,
                                onReactionTap: (emoji) {
                                  ReactionService.addReaction(
                                    context,
                                    emoji,
                                    _messageData.id,
                                    widget.chatGroupId,
                                    widget.chatType,
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrokMessage(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        children: [
          if (widget.showTimestamp &&
              _messageData.timestamp != DateTime.fromMillisecondsSinceEpoch(0))
            MessageTimestamp(timestamp: _messageData.timestamp),
          // HAL-like collapsed state initially
          Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              transitionBuilder: (child, animation) {
                return ScaleTransition(
                  scale: animation,
                  child: FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                );
              },
              child: _isGrokExpanded
                  ? _buildExpandedGrokMessage()
                  : _buildCollapsedGrokMessage(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsedGrokMessage() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _isGrokExpanded = true;
        });
      },
      child: Semantics(
        label: 'Grok message - tap to expand',
        child: Container(
          width: 27,
          height: 27,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black,
            border: Border.all(
              color: const Color(0xFF8B0000),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B0000).withValues(alpha: 0.6),
                blurRadius: 7,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.8),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 3,
              height: 3,
              decoration: const BoxDecoration(
                color: Color(0xFF8B0000),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedGrokMessage() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _isGrokExpanded = false;
        });
      },
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0A), // Very dark background
          border: Border.all(
            color: const Color(0xFF8B0000), // Dark red border
            width: 2.0,
          ),
          borderRadius: BorderRadius.circular(4), // Minimal rounding
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B0000).withValues(alpha: 0.4),
              blurRadius: 12,
              spreadRadius: 2,
              offset: const Offset(0, 0),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.8),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header bar with subtle glow
            Container(
              width: double.infinity,
              height: 6,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF8B0000).withValues(alpha: 0.8),
                    const Color(0xFF8B0000).withValues(alpha: 0.4),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            // Message content
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Terminal-like prompt indicator
                  Container(
                    margin: const EdgeInsets.only(right: 8.0, top: 2.0),
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF8B0000),
                      shape: BoxShape.circle,
                    ),
                  ),
                  // Text content
                  Expanded(
                    child: Text(
                      _messageData.text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontFamily: 'monospace', // Terminal-like font
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageContainer(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onLongPress: () {
        HapticFeedback.heavyImpact();
        _showMessageReactionOverlay(context);
      },
      child: AnimatedContainer(
        key: _messageKey,
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 2.0),
        padding: _getMessagePadding(),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
          minWidth: 60,
        ),
        decoration: _getMessageDecoration(),
        child: Semantics(
          label: 'Message from ${_messageData.sender}',
          child: IntrinsicWidth(
            child: MessageContent(
              message: _messageData,
              isFromCurrentUser: widget.isMe,
              chatGroupId: widget.chatGroupId,
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: const Duration(milliseconds: 300)).slideY(
        begin: 0.2,
        end: 0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut);
  }

  BoxDecoration _getMessageDecoration() {
    // Futuristic design for Grok AI messages
    if (_messageData.isGrokMessage) {
      return BoxDecoration(
        color: const Color(0xFF0A0A0A), // Very dark background
        border: Border.all(
          color: const Color(0xFF8B0000), // Dark red border
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(2), // Sharp, angular corners
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B0000).withValues(alpha: 0.3),
            blurRadius: 8,
            spreadRadius: 1,
            offset: const Offset(0, 0),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.7),
            blurRadius: 15,
            offset: const Offset(0, 3),
          ),
        ],
      );
    }

    // iMessage-style bubbles
    return BoxDecoration(
      color: widget.isMe
          ? const Color(0xFF007AFF) // iMessage blue for sent messages
          : const Color(
              0xFF2C2C2E), // Dark gray for received messages in dark theme
      borderRadius: BorderRadius.only(
        topLeft: const Radius.circular(21),
        topRight: const Radius.circular(21),
        bottomLeft:
            widget.isMe ? const Radius.circular(21) : const Radius.circular(4),
        bottomRight:
            widget.isMe ? const Radius.circular(4) : const Radius.circular(21),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ],
    );
  }

  EdgeInsets _getMessagePadding() {
    // Compact padding for futuristic Grok messages
    if (_messageData.isGrokMessage) {
      return const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0);
    }

    // iMessage-style padding - generous for comfortable reading
    return const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0);
  }
}
