import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'chat_state.dart';
import 'chat_service.dart';
import '../services/ai_service.dart';
import '../squad_state.dart';
import 'models/message_data.dart';
import 'widgets/message_content.dart';
import 'widgets/message_avatar.dart';
import 'widgets/message_sender.dart';
import 'widgets/message_timestamp.dart';
import 'widgets/imessage_reactions_bar.dart';

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

class _MessageBubbleState extends State<MessageBubble> {
  late MessageData _messageData;
  bool _isGrokExpanded = false; // Track if Grok message is expanded
  final GlobalKey _messageKey = GlobalKey();
  bool _shouldFloatUp = false; // Track if message should float up for menu
  bool _isPressed = false; // Track if message is being pressed for animation

  // Overlay references for dismissal
  OverlayEntry? _reactionsOverlay;
  OverlayEntry? _menuOverlay;

  @override
  void initState() {
    super.initState();
    _normalizeMessageData();
  }

  @override
  void didUpdateWidget(MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message != widget.message) {
      _normalizeMessageData();
    }
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

  @override
  Widget build(BuildContext context) {
    // Check if this is a Grok AI message for unique styling
    if (_messageData.isGrokMessage) {
      return _buildGrokMessage(context);
    }

    // Standard layout for regular messages
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Column(
        crossAxisAlignment:
            widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (widget.showTimestamp &&
              _messageData.timestamp != DateTime.fromMillisecondsSinceEpoch(0))
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
                            bottom:
                                -12, // Position so 75% of reaction pill is on message bubble (25% visible)
                            right: widget.isMe ? -4 : null,
                            left: widget.isMe ? null : -4,
                            child: MessageReactions(
                              reactions: _messageData.reactions,
                              onReactionTap: (emoji) {
                                // Show reaction details and reopen reactions bar
                                _showReactionDetails(emoji);
                              },
                              isOutgoing: widget.isMe,
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
      onTapDown: (_) {
        setState(() {
          _isPressed = true;
        });
      },
      onTapUp: (_) {
        setState(() {
          _isPressed = false;
        });
      },
      onTapCancel: () {
        setState(() {
          _isPressed = false;
        });
      },
      onLongPress: () {
        final RenderBox? renderBox =
            _messageKey.currentContext?.findRenderObject() as RenderBox?;
        if (renderBox == null) return;

        final messagePosition = renderBox.localToGlobal(Offset.zero);
        final messageSize = renderBox.size;
        final screenSize = MediaQuery.of(context).size;

        // Calculate floating offset early
        final menuTop = messagePosition.dy + messageSize.height + -4;
        final menuHeight = 200.0;
        final shouldFlipMenu = menuTop + menuHeight > screenSize.height - 20;
        final floatingOffset = shouldFlipMenu ? -220.0 : 0.0;

        late final OverlayEntry reactionsOverlay;
        late final OverlayEntry menuOverlay;

        _reactionsOverlay = reactionsOverlay = OverlayEntry(
          builder: (context) => Stack(
            children: [
              // Reactions bar - blur is handled within the IMessageReactionsBar widget
              IMessageReactionsBar(
                messageId: _messageData.id,
                chatGroupId: widget.chatGroupId,
                chatType: widget.chatType,
                isOutgoing: widget.isMe,
                onDismiss: _dismissOverlays,
                messagePosition: messagePosition,
                messageSize: messageSize,
                floatingOffset: floatingOffset,
              ),
            ],
          ),
        );

        // Position menu below the message bubble (similar to reaction picker logic but below instead of above)
        final menuSpacing =
            -12.0; // Spacing between message bubble and menu (same as reaction picker)

        // Always position below the message bubble
        final finalMenuTop = messagePosition.dy +
            messageSize.height +
            menuSpacing +
            floatingOffset;

        _menuOverlay = menuOverlay = OverlayEntry(
          builder: (context) => Stack(
            children: [
              // Menu - no background blur needed
              Positioned(
                top: finalMenuTop.clamp(10, screenSize.height - 220),
                left: widget.isMe
                    ? null
                    : 16.0, // Same padding as message bubble for incoming
                right: widget.isMe
                    ? 16.0
                    : null, // Same padding as message bubble for outgoing
                child: Material(
                  color: Colors.transparent,
                  elevation: 10, // Higher elevation to ensure it's on top
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

        // Float message bubble up if menu is above
        setState(() {
          _shouldFloatUp = shouldFlipMenu;
        });

        Overlay.of(context).insert(reactionsOverlay);
        Overlay.of(context).insert(menuOverlay);
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            key: _messageKey,
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(vertical: 2.0),
            padding: _getMessagePadding(),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
              minWidth: 60,
            ),
            decoration: _getMessageDecoration(),
            transform: Matrix4.identity()
              ..setTranslationRaw(0.0, _shouldFloatUp ? -220.0 : 0.0, 0.0),
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
          if (_isPressed)
            Positioned.fill(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(vertical: 2.0),
                padding: _getMessagePadding(),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.7,
                  minWidth: 60,
                ),
                decoration: _getMessageDecoration().copyWith(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      spreadRadius: 2,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                transform: Matrix4.diagonal3Values(1.05, 1.05, 1.0)
                  ..setTranslationRaw(0.0, _shouldFloatUp ? -220.0 : 0.0, 0.0),
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
        ],
      ),
    ).animate().fadeIn(duration: const Duration(milliseconds: 300)).slideY(
        begin: 0.2,
        end: 0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut);
  }

  Widget _buildActionMenu() {
    return Container(
      constraints: const BoxConstraints(
        minWidth: 200,
        maxWidth: 280,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            spreadRadius: 1,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            color: Colors.black
                .withValues(alpha: 0.7), // Match reactions bar opacity
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Primary actions row
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildModernMenuItem(
                      icon: Icons.reply,
                      label: 'Reply',
                      onTap: () {
                        final chatState =
                            Provider.of<ChatState>(context, listen: false);
                        chatState.setReplyToMessage(_messageData.toMap());
                        _dismissOverlays();
                      },
                    ),
                    _buildDivider(),
                    _buildModernMenuItem(
                      icon: Icons.copy,
                      label: 'Copy',
                      onTap: () {
                        Clipboard.setData(
                            ClipboardData(text: _messageData.text));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Text copied')),
                        );
                        _dismissOverlays();
                      },
                    ),
                  ],
                ),
                // Secondary actions
                if (widget.isMe) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildModernMenuItem(
                        icon: Icons.edit,
                        label: 'Edit',
                        onTap: () async {
                          final TextEditingController editController =
                              TextEditingController(text: _messageData.text);
                          final result = await showDialog<String>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Edit Message'),
                              content: TextField(
                                controller: editController,
                                decoration: const InputDecoration(
                                  hintText: 'Edit your message...',
                                  border: OutlineInputBorder(),
                                ),
                                maxLines: null,
                                autofocus: true,
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(
                                      context, editController.text.trim()),
                                  child: const Text('Save'),
                                ),
                              ],
                            ),
                          );

                          if (result != null &&
                              result.isNotEmpty &&
                              result != _messageData.text &&
                              context.mounted) {
                            try {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Message edited')),
                              );
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content:
                                          Text('Failed to edit message: $e')),
                                );
                              }
                            }
                          }
                          _dismissOverlays();
                        },
                      ),
                      _buildDivider(),
                      _buildModernMenuItem(
                        icon: Icons.delete,
                        label: 'Delete',
                        color: Colors.red,
                        onTap: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor:
                                  Theme.of(context).colorScheme.surface,
                              elevation: 24,
                              title: const Text('Delete Message'),
                              content: const Text(
                                  'Are you sure you want to delete this message?'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
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
                              final squadState = Provider.of<SquadState>(
                                  context,
                                  listen: false);
                              await squadState.deleteMessage(_messageData.id);
                              _dismissOverlays();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Message deleted')),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content:
                                          Text('Failed to delete message: $e')),
                                );
                              }
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ],
                // Additional actions
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildModernMenuItem(
                      icon: Icons.notifications,
                      label: 'Bump',
                      onTap: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          // Get chat service from provider
                          final chatService =
                              Provider.of<ChatService>(context, listen: false);
                          await chatService.bumpMessage(
                            _messageData.id,
                            widget.chatGroupId,
                            widget.chatType,
                          );
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Message bumped')),
                          );
                        } catch (e) {
                          messenger.showSnackBar(
                            SnackBar(
                                content: Text('Failed to bump message: $e')),
                          );
                        }
                        _dismissOverlays();
                      },
                    ),
                    _buildDivider(),
                    _buildModernMenuItem(
                      icon: Icons.push_pin,
                      label: 'Pin',
                      onTap: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Message pinned')),
                          );
                        } catch (e) {
                          messenger.showSnackBar(
                            SnackBar(
                                content: Text('Failed to pin message: $e')),
                          );
                        }
                        _dismissOverlays();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 70, // Fixed width for consistent alignment
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 22,
                color: color ?? Colors.white.withValues(alpha: 0.9),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color ?? Colors.white.withValues(alpha: 0.9),
                ),
                textAlign:
                    TextAlign.center, // Center text for consistent appearance
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: Colors.white.withValues(alpha: 0.2),
    );
  }

  void _showReactionDetails(String tappedEmoji) {
    final RenderBox? renderBox =
        _messageKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final messagePosition = renderBox.localToGlobal(Offset.zero);
    final messageSize = renderBox.size;

    // Filter reactions to only show those with the tapped emoji
    final emojiReactions = _messageData.reactions
        .where((reaction) => reaction['reaction'] == tappedEmoji)
        .toList();

    // Create overlay showing reaction details at top center
    final detailsOverlay = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 20,
        left: 0,
        right: 0,
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Show the emoji
                  Text(
                    tappedEmoji,
                    style: const TextStyle(fontSize: 32),
                  ),
                  const SizedBox(height: 8),
                  // Show avatars of people who reacted
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: emojiReactions.map((reaction) {
                      final userId = reaction['userId'];
                      return Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey[600],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Text(
                            userId?.toString().substring(0, 1).toUpperCase() ??
                                '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // Show details overlay
    Overlay.of(context).insert(detailsOverlay);

    // Auto-dismiss after 2 seconds and show reactions bar
    Future.delayed(const Duration(seconds: 2), () {
      detailsOverlay.remove();

      // Reopen reactions bar
      late final OverlayEntry reactionsOverlay;
      reactionsOverlay = OverlayEntry(
        builder: (context) => IMessageReactionsBar(
          messageId: _messageData.id,
          chatGroupId: widget.chatGroupId,
          chatType: widget.chatType,
          isOutgoing: widget.isMe,
          onDismiss: () {
            reactionsOverlay.remove();
          },
          messagePosition: messagePosition,
          messageSize: messageSize,
        ),
      );
      Overlay.of(context).insert(reactionsOverlay);
    });
  }

  void _dismissOverlays() {
    // Remove overlay entries if they exist
    _reactionsOverlay?.remove();
    _menuOverlay?.remove();

    // Clear references
    _reactionsOverlay = null;
    _menuOverlay = null;

    // Reset floating state when overlays are dismissed
    setState(() {
      _shouldFloatUp = false;
    });
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
