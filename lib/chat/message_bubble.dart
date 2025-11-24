import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as p;
import 'chat_service.dart';
import '../services/ai_service.dart';
import '../providers.dart';
import '../presentation/notifiers/chat_notifier.dart' as cn;
import 'models/message_data.dart';
import 'widgets/message_content.dart';
import 'widgets/message_reactions.dart';
import 'widgets/message_avatar.dart';
import 'widgets/message_sender.dart';
import 'widgets/imessage_reactions_bar.dart';

/// Sub-widget for the bubble header (avatar and sender)
class _BubbleHeader extends StatelessWidget {
  final MessageData messageData;
  final bool isMe;
  final bool showSender;
  final bool showAvatar;

  const _BubbleHeader({
    required this.messageData,
    required this.isMe,
    required this.showSender,
    required this.showAvatar,
  });

  @override
  Widget build(BuildContext context) {
    if (isMe) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showAvatar)
          MessageAvatar(
            senderName: messageData.sender,
            isFromCurrentUser: isMe,
          ),
        if (showAvatar) const SizedBox(width: 8),
        if (showSender) MessageSender(message: messageData),
      ],
    );
  }
}

/// Sub-widget for the bubble content (message container)
class _BubbleContent extends StatefulWidget {
  final MessageData messageData;
  final bool isMe;
  final String? chatGroupId;
  final ChatService? chatService;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Function(Offset, Size, double) onLongPressDetails;

  const _BubbleContent({
    required this.messageData,
    required this.isMe,
    this.chatGroupId,
    this.chatService,
    required this.onTap,
    required this.onLongPress,
    required this.onLongPressDetails,
  });

  @override
  State<_BubbleContent> createState() => _BubbleContentState();
}

class _BubbleContentState extends State<_BubbleContent> {
  final GlobalKey _messageKey = GlobalKey();
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Remove haptics to avoid overload
        FocusScope.of(context).unfocus();
        widget.onTap();
      },
      onTapDown: (_) {
        setState(() => _isPressed = true);
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
      },
      onLongPress: () {
        FocusScope.of(context).unfocus();
        final RenderBox? renderBox =
            _messageKey.currentContext?.findRenderObject() as RenderBox?;
        if (renderBox == null) return;

        final messagePosition = renderBox.localToGlobal(Offset.zero);
        final messageSize = renderBox.size;
        final screenSize = MediaQuery.of(context).size;
        final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

        final menuSpacing = 4.0;
        final menuTop = messagePosition.dy + messageSize.height + menuSpacing;
        final menuHeight = 200.0;
        final availableHeight = screenSize.height - keyboardHeight - 20;
        final shouldFlipMenu = menuTop + menuHeight > availableHeight;
        final floatingOffset = shouldFlipMenu ? -220.0 : 0.0;

        widget.onLongPressDetails(messagePosition, messageSize, floatingOffset);
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
            ),
            decoration: _getMessageDecoration().copyWith(
              boxShadow: _isPressed
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 6,
                        spreadRadius: 1,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : _getMessageDecoration().boxShadow,
            ),
            child: Semantics(
              label: 'Message from ${widget.messageData.sender}',
              child: IntrinsicWidth(
                child: MessageContent(
                  message: widget.messageData,
                  isFromCurrentUser: widget.isMe,
                  chatGroupId: widget.chatGroupId,
                  chatService: widget.chatService,
                ),
              ),
            ),
          ),
          // Pending sync indicator
          if (!widget.messageData.delivered)
            Positioned(
              bottom: -2,
              right: widget.isMe ? 8 : null,
              left: widget.isMe ? null : 8,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.access_time,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ).animate().fadeIn(duration: const Duration(milliseconds: 300)).slideY(
          begin: 0.2,
          end: 0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut),
    );
  }

  BoxDecoration _getMessageDecoration() {
    if (widget.messageData.isGrokMessage) {
      return BoxDecoration(
        color: const Color(0xFF0A0A0A),
        border: Border.all(
          color: const Color(0xFF8B0000),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(2),
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

    return BoxDecoration(
      color: widget.isMe ? const Color(0xFF007AFF) : const Color(0xFF2C2C2E),
      borderRadius: BorderRadius.only(
        topLeft: const Radius.circular(16),
        topRight: const Radius.circular(16),
        bottomLeft:
            widget.isMe ? const Radius.circular(16) : const Radius.circular(4),
        bottomRight:
            widget.isMe ? const Radius.circular(4) : const Radius.circular(16),
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
    if (widget.messageData.isGrokMessage) {
      return const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0);
    }
    return const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0);
  }
}

/// Sub-widget for bubble reactions
class _BubbleReactions extends StatelessWidget {
  final List<Map<String, dynamic>> reactions;
  final bool isOutgoing;
  final ValueChanged<String> onReactionTap;

  const _BubbleReactions({
    required this.reactions,
    required this.isOutgoing,
    required this.onReactionTap,
  });

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();

    return Positioned(
      bottom: -20,
      right: isOutgoing ? -4 : null,
      left: isOutgoing ? null : -4,
      child: MessageReactions(
        reactions: reactions,
        onReactionTap: onReactionTap,
        isOutgoing: isOutgoing,
      ),
    );
  }
}

/// Refactored MessageBubble using decomposed components
/// This replaces the 1183-line monolithic MessageBubble with a clean, maintainable structure
class MessageBubble extends ConsumerStatefulWidget {
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
  final ChatService? chatService; // Add optional ChatService parameter

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
    this.chatService, // Optional parameter
  });

  @override
  ConsumerState<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends ConsumerState<MessageBubble> {
  late MessageData _messageData;
  bool _isGrokExpanded = false; // Track if Grok message is expanded
  final GlobalKey _messageKey = GlobalKey();

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

  void _dismissOverlays() {
    // Remove overlay entries if they exist
    _reactionsOverlay?.remove();
    _menuOverlay?.remove();

    // Clear references
    _reactionsOverlay = null;
    _menuOverlay = null;
  }

  void _showOverlays(
      Offset messagePosition, Size messageSize, double floatingOffset) {
    final screenSize = MediaQuery.of(context).size;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    final menuSpacing = 4.0;
    final availableHeight = screenSize.height - keyboardHeight - 20;

    late final OverlayEntry reactionsOverlay;
    late final OverlayEntry menuOverlay;

    _reactionsOverlay = reactionsOverlay = OverlayEntry(
      builder: (context) => Stack(
        children: [
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

    final finalMenuTop =
        messagePosition.dy + messageSize.height + menuSpacing + floatingOffset;

    _menuOverlay = menuOverlay = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _dismissOverlays,
              behavior: HitTestBehavior.translucent,
            ),
          ),
          Positioned(
            top: finalMenuTop.clamp(10, availableHeight - 220),
            left: widget.isMe ? null : 16.0,
            right: widget.isMe ? 16.0 : null,
            child: Material(
              color: Colors.transparent,
              elevation: 20,
              shadowColor: Colors.black.withValues(alpha: 0.5),
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

    Overlay.of(context).insert(reactionsOverlay);
    Overlay.of(context).insert(menuOverlay);
  }

  @override
  Widget build(BuildContext context) {
    // DEBUG: Log message details for troubleshooting
    debugPrint(
        'DEBUG MessageBubble.build: senderId=${_messageData.senderUid}, isOwnMessage=${widget.isMe}, messageType=${_messageData.type}, showTimestamp=${widget.showTimestamp}');

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
          Row(
            mainAxisAlignment:
                widget.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!widget.isMe)
                _BubbleHeader(
                  messageData: _messageData,
                  isMe: widget.isMe,
                  showSender: widget.showSender,
                  showAvatar: widget.showAvatar,
                ),
              Flexible(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _BubbleContent(
                      messageData: _messageData,
                      isMe: widget.isMe,
                      chatGroupId: widget.chatGroupId,
                      chatService: widget.chatService,
                      onTap: widget.onTap,
                      onLongPress: widget.onLongPress,
                      onLongPressDetails: (position, size, offset) {
                        _showOverlays(position, size, offset);
                      },
                    ),
                    if (_messageData.reactions.isNotEmpty)
                      _BubbleReactions(
                        reactions: _messageData.reactions,
                        isOutgoing: widget.isMe,
                        onReactionTap: (emoji) => _showReactionDetails(emoji),
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
                        // Use Riverpod chat notifier instead of legacy ChatState
                        final chatNotifier = ref.read(cn.chatNotifierProvider.notifier);
                        chatNotifier.setReplyingToMessage(_messageData.id);
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
                          _dismissOverlays(); // Dismiss menu before showing dialog
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
                              // Use the provided chatService or try to get from Provider
                              final chatService = widget.chatService ??
                                  p.Provider.of<ChatService>(context,
                                      listen: false);
                              final squadState =
                                  ref.read(squadStateNotifierProvider);
                              final squadId = squadState.selectedSquadId;
                              if (squadId != null) {
                                await chatService.editMessage(
                                    _messageData.id, result, squadId,
                                    chatGroupId: widget.chatGroupId,
                                    chatType: widget.chatType);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Message edited')),
                                  );
                                }
                              }
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
                        },
                      ),
                      _buildDivider(),
                      _buildModernMenuItem(
                        icon: Icons.delete,
                        label: 'Delete',
                        color: Colors.red,
                        onTap: () async {
                          _dismissOverlays(); // Dismiss menu before showing dialog
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
                              // Use the provided chatService or try to get from Provider
                              final chatService = widget.chatService ??
                                  p.Provider.of<ChatService>(context,
                                      listen: false);
                              final squadState =
                                  ref.read(squadStateNotifierProvider);
                              final squadId = squadState.selectedSquadId;
                              if (squadId != null) {
                                await chatService.deleteMessage(
                                    _messageData.id, squadId,
                                    chatGroupId: widget.chatGroupId,
                                    chatType: widget.chatType);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Message deleted')),
                                  );
                                }
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
                          // Use the provided chatService or try to get from Provider
                          final chatService = widget.chatService ??
                              p.Provider.of<ChatService>(context,
                                  listen: false);
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
}
