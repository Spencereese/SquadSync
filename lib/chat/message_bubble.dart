import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'chat_state.dart';
import 'models/message_data.dart';
import 'widgets/message_content.dart';
import 'widgets/message_reactions.dart';
import 'widgets/message_avatar.dart';
import 'widgets/message_sender.dart';
import 'widgets/message_timestamp.dart';
import 'services/reaction_service.dart';
import '../services/ai_service.dart';

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
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  // Long press interaction state
  bool _isLongPressed = false;
  late AnimationController _longPressController;
  late Animation<double> _longPressScaleAnimation;
  late Animation<Offset> _longPressOffsetAnimation;
  OverlayEntry? _reactionsOverlay;
  OverlayEntry? _menuOverlay;

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
      end: Offset.zero, // Disable position animation completely
    ).animate(CurvedAnimation(
      parent: _positionController,
      curve: Curves.easeOut,
    ));

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.02, // Slight growth effect
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOut,
    ));

    _longPressController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _longPressScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _longPressController,
      curve: Curves.easeOut,
    ));

    _longPressOffsetAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -2),
    ).animate(CurvedAnimation(
      parent: _longPressController,
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
    _scaleController.dispose();
    _longPressController.dispose();
    _reactionsOverlay?.remove();
    _menuOverlay?.remove();
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

  void _handleLongPress() {
    if (_isLongPressed) return; // Prevent multiple long presses

    setState(() {
      _isLongPressed = true;
    });

    // Start the lift animation
    _longPressController.forward();

    // Add background blur after 200ms
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted && _isLongPressed) {
        _showBackgroundBlur();
      }
    });

    // Show reactions after a short delay
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && _isLongPressed) {
        _showReactionsPicker();
      }
    });
  }

  void _showBackgroundBlur() {
    // This would be implemented by adding a BackdropFilter to the parent widget
    // For now, we'll just ensure the overlays provide the visual feedback
  }

  void _showReactionsPicker() {
    final RenderBox? renderBox =
        _messageKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final messagePosition = renderBox.localToGlobal(Offset.zero);
    final messageSize = renderBox.size;
    final screenSize = MediaQuery.of(context).size;

    // Position reactions above the message, flip below if not enough space
    final reactionsTop = messagePosition.dy - 60;
    final shouldFlipReactions = reactionsTop < 20;

    final finalReactionsTop = shouldFlipReactions
        ? messagePosition.dy + messageSize.height + 8
        : reactionsTop;
    final reactionsLeft = widget.isMe
        ? messagePosition.dx +
            messageSize.width -
            200 // Align to right edge for sent messages
        : messagePosition.dx; // Align to left edge for received messages

    _reactionsOverlay = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Background tap to dismiss
          GestureDetector(
            onTap: _dismissOverlays,
            child: Container(
              color: Colors.transparent,
              width: screenSize.width,
              height: screenSize.height,
            ),
          ),
          // Reactions picker
          Positioned(
            top: finalReactionsTop.clamp(10, screenSize.height - 100),
            left: reactionsLeft.clamp(10, screenSize.width - 220),
            child: Material(
              color: Colors.transparent,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                builder: (context, value, child) => Transform.scale(
                  scale: value,
                  child: _buildReactionsPicker(),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_reactionsOverlay!);

    // Show menu below reactions after another delay
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted && _isLongPressed) {
        _showActionMenu();
      }
    });
  }

  void _showActionMenu() {
    final RenderBox? renderBox =
        _messageKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final messagePosition = renderBox.localToGlobal(Offset.zero);
    final messageSize = renderBox.size;
    final screenSize = MediaQuery.of(context).size;

    // Position menu below the message, flip to top if not enough space
    final menuTop = messagePosition.dy + messageSize.height + 8;
    final menuHeight = 120.0; // Approximate menu height
    final shouldFlipMenu = menuTop + menuHeight > screenSize.height - 20;

    final finalMenuTop =
        shouldFlipMenu ? messagePosition.dy - menuHeight - 8 : menuTop;
    final menuLeft = widget.isMe
        ? messagePosition.dx +
            messageSize.width -
            140 // Align to right for sent messages
        : messagePosition.dx; // Align to left for received messages

    _menuOverlay = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Background tap to dismiss (already handled by reactions overlay)
          // Menu
          Positioned(
            top: finalMenuTop.clamp(10, screenSize.height - 150),
            left: menuLeft.clamp(10, screenSize.width - 150),
            child: Material(
              color: Colors.transparent,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                builder: (context, value, child) => Transform.translate(
                  offset: Offset(0, 10 * (1 - value)),
                  child: Opacity(
                    opacity: value,
                    child: _buildActionMenu(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_menuOverlay!);
  }

  Widget _buildReactionsPicker() {
    final quickReactions = ['❤️', '👍', '👎', '😂', '😮', '🙌', '❗', '❓'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[800]!.withValues(alpha: 0.9)
            : Colors.grey[100]!.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...quickReactions.map((emoji) {
            final currentUserId = FirebaseAuth.instance.currentUser?.uid;
            final hasReaction = _messageData.reactions.any((reaction) =>
                reaction['userId'] == currentUserId &&
                reaction['reaction'] == emoji);
            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                ReactionService.addReaction(
                  context,
                  emoji,
                  _messageData.id,
                  widget.chatGroupId,
                  widget.chatType,
                );
                _dismissOverlays();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: hasReaction
                      ? Colors.blue.withValues(alpha: 0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            );
          }),
          GestureDetector(
            onTap: () {
              // TODO: Open full emoji picker
              _dismissOverlays();
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(left: 4),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.add,
                size: 24,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionMenu() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[800]!.withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMenuItem(
            icon: Icons.reply,
            label: 'Reply',
            onTap: () {
              final chatState = Provider.of<ChatState>(context, listen: false);
              chatState.setReplyToMessage(widget.message);
              _dismissOverlays();
            },
          ),
          const SizedBox(height: 8),
          _buildMenuItem(
            icon: Icons.copy,
            label: 'Copy',
            onTap: () {
              Clipboard.setData(ClipboardData(text: _messageData.text));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Text copied')),
              );
              _dismissOverlays();
            },
          ),
          if (widget.isMe) ...[
            const SizedBox(height: 8),
            _buildMenuItem(
              icon: Icons.delete,
              label: 'Delete',
              color: Colors.red,
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Message'),
                    content: const Text(
                        'Are you sure you want to delete this message?'),
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
                  // TODO: Implement delete
                  _dismissOverlays();
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 20,
            color: color ??
                (Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: color ??
                  (Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  void _dismissOverlays() {
    _reactionsOverlay?.remove();
    _menuOverlay?.remove();
    _reactionsOverlay = null;
    _menuOverlay = null;
    _longPressController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _isLongPressed = false;
        });
      }
    });
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
    return AnimatedBuilder(
      animation: Listenable.merge([
        _scaleAnimation,
        _longPressScaleAnimation,
        _longPressOffsetAnimation
      ]),
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value * _longPressScaleAnimation.value,
          child: Transform.translate(
            offset: _longPressOffsetAnimation.value,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onTap();
              },
              onLongPress: () {
                HapticFeedback.lightImpact();
                _handleLongPress();
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
            ),
          ),
        );
      },
    );
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
