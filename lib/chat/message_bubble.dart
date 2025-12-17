import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/message_service.dart';
import '../services/auth_service_supabase.dart';
import '../domain/entities/message.dart';
import '../presentation/notifiers/chat_notifier.dart' as cn;
import 'package:squad_sync/presentation/notifiers/lobby_notifier.dart' as ln;
import 'models/message_data.dart' as models
    show MessageData, MessageType, MessageStatus;
import 'widgets/message_content.dart';
import 'widgets/message_reactions.dart';
import 'widgets/message_avatar.dart';
import 'widgets/imessage_reactions_bar.dart';
import '../presentation/notifiers/user_notifier.dart';
import 'widgets/smart_reply_bottom_sheet.dart';
import 'widgets/grok_message_bubble.dart';
import 'services/reaction_service.dart';

/// Enhanced message bubble with iMessage-style tails and animations
class _AnimatedMessageBubble extends StatefulWidget {
  final models.MessageData messageData;
  final bool isMe;
  final bool isFirstInGroup;
  final bool isLastInGroup;
  final String? chatGroupId;
  final MessageService? chatService;
  final ChatType chatType;
  final String? squadId;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Function(Offset, Size, double) onLongPressDetails;
  final int index; // For stagger animation

  const _AnimatedMessageBubble({
    required this.messageData,
    required this.isMe,
    required this.isFirstInGroup,
    required this.isLastInGroup,
    this.chatGroupId,
    this.chatService,
    required this.chatType,
    this.squadId,
    required this.onTap,
    required this.onLongPress,
    required this.onLongPressDetails,
    required this.index,
  });

  @override
  State<_AnimatedMessageBubble> createState() => _AnimatedMessageBubbleState();
}

class _AnimatedMessageBubbleState extends State<_AnimatedMessageBubble>
    with TickerProviderStateMixin {
  final GlobalKey _messageKey = GlobalKey();
  bool _isPressed = false;
  late AnimationController _reactionController;
  late Animation<double> _reactionAnimation;

  @override
  void initState() {
    super.initState();
    _reactionController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _reactionAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _reactionController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _reactionController.dispose();
    super.dispose();
  }

  BorderRadius get borderRadius {
    if (widget.isFirstInGroup && widget.isLastInGroup)
      return BorderRadius.circular(20);
    if (widget.isFirstInGroup)
      return BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
          bottomLeft: widget.isMe ? Radius.circular(20) : Radius.circular(6),
          bottomRight: widget.isMe ? Radius.circular(6) : Radius.circular(20));
    if (widget.isLastInGroup)
      return BorderRadius.only(
          topLeft: widget.isMe ? Radius.circular(20) : Radius.circular(6),
          topRight: widget.isMe ? Radius.circular(6) : Radius.circular(20),
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20));
    // middle
    return BorderRadius.only(
        topLeft: widget.isMe ? Radius.circular(20) : Radius.circular(6),
        topRight: widget.isMe ? Radius.circular(6) : Radius.circular(20),
        bottomLeft: widget.isMe ? Radius.circular(20) : Radius.circular(6),
        bottomRight: widget.isMe ? Radius.circular(6) : Radius.circular(20));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
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
          // Main bubble with pill shape and glass effect
          AnimatedBuilder(
            animation: _reactionAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _reactionAnimation.value,
                child: ClipRRect(
                  borderRadius: borderRadius,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: Container(
                      key: _messageKey,
                      margin: const EdgeInsets.symmetric(vertical: 1.0),
                      decoration: BoxDecoration(
                        gradient: widget.isMe
                            ? LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: _isPressed
                                    ? [
                                        const Color(0xFF007AFF)
                                            .withValues(alpha: 0.85),
                                        const Color(0xFF0051D5)
                                            .withValues(alpha: 0.85),
                                      ]
                                    : [
                                        const Color(0xFF007AFF)
                                            .withValues(alpha: 0.92),
                                        const Color(0xFF0051D5)
                                            .withValues(alpha: 0.92),
                                      ],
                              )
                            : LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: _isPressed
                                    ? [
                                        const Color(0xFF3C3C3E)
                                            .withValues(alpha: 0.85),
                                        const Color(0xFF2C2C2E)
                                            .withValues(alpha: 0.85),
                                      ]
                                    : [
                                        const Color(0xFF3C3C3E)
                                            .withValues(alpha: 0.92),
                                        const Color(0xFF2C2C2E)
                                            .withValues(alpha: 0.92),
                                      ],
                              ),
                        borderRadius: borderRadius,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 0.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                          BoxShadow(
                            color: widget.isMe
                                ? const Color(0xFF007AFF)
                                    .withValues(alpha: 0.15)
                                : Colors.black.withValues(alpha: 0.1),
                            blurRadius: 20,
                            spreadRadius: -5,
                          ),
                        ],
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.center,
                            colors: [
                              Colors.white.withValues(alpha: 0.15),
                              Colors.white.withValues(alpha: 0.0),
                            ],
                          ),
                          borderRadius: borderRadius,
                        ),
                        padding: _getMessagePadding(),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.7,
                        ),
                        child: Semantics(
                          label: 'Message from ${widget.messageData.sender}',
                          child: IntrinsicWidth(
                            child: MessageContent(
                              message: widget.messageData,
                              isFromCurrentUser: widget.isMe,
                              chatGroupId: widget.chatGroupId,
                              chatService: widget.chatService,
                              chatType: widget.chatType,
                              squadId: widget.squadId,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          if (widget.messageData.status == models.MessageStatus.sending)
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
      )
          // Enhanced send-in animation with stagger
          .animate()
          .fadeIn(
            duration: const Duration(milliseconds: 400),
            delay: Duration(milliseconds: widget.index * 100), // 100ms stagger
          )
          .slideY(
            begin: 0.3,
            end: 0.0,
            duration: const Duration(milliseconds: 400),
            delay: Duration(milliseconds: widget.index * 100),
            curve: Curves.easeOutQuart,
          )
          .scale(
            begin: const Offset(0.8, 0.8),
            end: const Offset(1.0, 1.0),
            duration: const Duration(milliseconds: 300),
            delay: Duration(milliseconds: widget.index * 100 + 50),
            curve: Curves.elasticOut,
          ),
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
      bottom: -10,
      right: isOutgoing ? 8 : null,
      left: isOutgoing ? null : 8,
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
  final bool isFirstInGroup;
  final bool isLastInGroup;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Map<String, bool> sendingStatus;
  final String? chatGroupId;
  final ChatType chatType;
  final MessageService? chatService; // Add optional MessageService parameter
  final String? squadId;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.showSender,
    required this.showAvatar,
    required this.showTimestamp,
    required this.showReadIndicator,
    required this.isFirstInGroup,
    required this.isLastInGroup,
    required this.onTap,
    required this.onLongPress,
    required this.sendingStatus,
    this.chatGroupId,
    required this.chatType,
    this.chatService, // Optional parameter
    this.squadId,
  });

  @override
  ConsumerState<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends ConsumerState<MessageBubble> {
  late models.MessageData _messageData;

  // Overlay references for dismissal
  OverlayEntry? _reactionsOverlay;
  OverlayEntry? _menuOverlay;
  OverlayEntry? _messageBubbleOverlay;

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
    if (widget.message is models.MessageData) {
      _messageData = widget.message;
    } else {
      // Fallback for backward compatibility - convert from old format
      _messageData =
          models.MessageData.fromMap(widget.message as Map<String, dynamic>);
    }

    // Debug reactions
    // if (kDebugMode) {
    //   debugPrint(
    //       '💬 MessageBubble: Message ${_messageData.id} has ${_messageData.reactions.length} reactions');
    //   if (_messageData.reactions.isNotEmpty) {
    //     debugPrint('💬 Reactions data: ${_messageData.reactions}');
    //   }
    // }
  }

  void _dismissOverlays() {
    // Remove overlay entries if they exist
    _messageBubbleOverlay?.remove();
    _reactionsOverlay?.remove();
    _menuOverlay?.remove();

    // Clear references
    _messageBubbleOverlay = null;
    _reactionsOverlay = null;
    _menuOverlay = null;
  }

  Widget _buildFloatingMessageBubble(Size messageSize) {
    final color =
        widget.isMe ? const Color(0xFF007AFF) : const Color(0xFF2C2C2E);

    BorderRadius getBorderRadius() {
      if (widget.isFirstInGroup && widget.isLastInGroup)
        return BorderRadius.circular(20);
      if (widget.isFirstInGroup)
        return BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: widget.isMe ? Radius.circular(20) : Radius.circular(6),
            bottomRight:
                widget.isMe ? Radius.circular(6) : Radius.circular(20));
      if (widget.isLastInGroup)
        return BorderRadius.only(
            topLeft: widget.isMe ? Radius.circular(20) : Radius.circular(6),
            topRight: widget.isMe ? Radius.circular(6) : Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20));
      return BorderRadius.only(
          topLeft: widget.isMe ? Radius.circular(20) : Radius.circular(6),
          topRight: widget.isMe ? Radius.circular(6) : Radius.circular(20),
          bottomLeft: widget.isMe ? Radius.circular(20) : Radius.circular(6),
          bottomRight: widget.isMe ? Radius.circular(6) : Radius.circular(20));
    }

    return ClipRect(
      child: Container(
        width: messageSize.width,
        height: messageSize.height,
        clipBehavior: Clip.hardEdge,
        margin: const EdgeInsets.symmetric(vertical: 1.0),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: color,
          borderRadius: getBorderRadius(),
        ),
        child: OverflowBox(
          maxHeight: messageSize.height - 20.0, // Account for padding
          maxWidth: messageSize.width - 32.0,
          alignment: Alignment.topLeft,
          child: MessageContent(
            message: _messageData,
            isFromCurrentUser: widget.isMe,
            chatGroupId: widget.chatGroupId,
            chatService: widget.chatService,
            chatType: widget.chatType,
            squadId: widget.squadId,
          ),
        ),
      ),
    );
  }

  void _showOverlays(
      Offset messagePosition, Size messageSize, double floatingOffset) {
    final screenSize = MediaQuery.of(context).size;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    final menuSpacing = 4.0;
    final availableHeight = screenSize.height - keyboardHeight - 20;

    // Capture these BEFORE building the overlay to ensure we have proper context
    final squadId = ref.read(ln.lobbyNotifierProvider).maybeWhen(
          data: (data) => data.selectedLobbyId,
          orElse: () => null,
        );
    final messenger = ScaffoldMessenger.of(context);
    final widgetContext = context; // Capture the widget's context

    late final OverlayEntry reactionsOverlay;
    late final OverlayEntry menuOverlay;
    late final OverlayEntry messageBubbleOverlay;

    // Add floating message bubble overlay only if floatingOffset is active
    if (floatingOffset != 0.0) {
      _messageBubbleOverlay = messageBubbleOverlay = OverlayEntry(
        builder: (overlayContext) => TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: floatingOffset),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          builder: (context, offset, child) => Positioned(
            left: messagePosition.dx,
            top: messagePosition.dy + offset,
            child: Opacity(
              opacity: 1.0,
              child: _buildFloatingMessageBubble(messageSize),
            ),
          ),
        ),
      );
    }

    _reactionsOverlay = reactionsOverlay = OverlayEntry(
      builder: (overlayContext) => Stack(
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
            squadId: squadId,
            scaffoldMessenger: messenger,
          ),
        ],
      ),
    );

    final finalMenuTop =
        messagePosition.dy + messageSize.height + menuSpacing + floatingOffset;

    _menuOverlay = menuOverlay = OverlayEntry(
      builder: (context) => GestureDetector(
        onTap: () {
          debugPrint('🔸 Overlay background tapped, dismissing');
          _dismissOverlays();
        },
        behavior: HitTestBehavior
            .translucent, // Allow taps to pass through to reactions bar
        child: Container(
          color: Colors.transparent,
          child: Stack(
            children: [
              // Menu positioned to receive taps
              Positioned(
                top: finalMenuTop.clamp(10, availableHeight - 220),
                left: widget.isMe ? null : 16.0,
                right: widget.isMe ? 16.0 : null,
                child: GestureDetector(
                  onTap: () {
                    debugPrint('🔹 Menu area tapped (preventing dismiss)');
                    // Prevent tap from bubbling to parent
                  },
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
                          child: _buildActionMenu(widgetContext, messenger),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    debugPrint('📱 Inserting overlays for message ${_messageData.id}');
    if (floatingOffset != 0.0) {
      Overlay.of(context).insert(messageBubbleOverlay);
    }
    // Insert menu overlay first, then reactions on top so reactions can capture taps
    Overlay.of(context).insert(menuOverlay);
    Overlay.of(context).insert(reactionsOverlay);
    debugPrint('✅ Overlays inserted successfully');
  }

  @override
  Widget build(BuildContext context) {
    // Removed excessive debug logging - this method is called on every frame

    // Check if this is a Grok AI message - use dedicated Grok UI
    if (_messageData.isGrokMessage) {
      return GrokMessageBubble(
        messageData: _messageData,
        index: 0, // Will be set by parent if needed
      );
    }

    // Standard layout for regular messages
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
      child: Column(
        crossAxisAlignment:
            widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                widget.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Avatar for received messages (on the left)
              if (!widget.isMe && widget.showAvatar)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: MessageAvatar(
                    senderName: _messageData.sender,
                    senderUid: _messageData.senderUid,
                    isFromCurrentUser: widget.isMe,
                  ),
                ),
              // Message bubble
              Flexible(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _AnimatedMessageBubble(
                      messageData: _messageData,
                      isMe: widget.isMe,
                      chatGroupId: widget.chatGroupId,
                      chatService: widget.chatService,
                      chatType: widget.chatType,
                      squadId: widget.squadId,
                      onTap: widget.onTap,
                      onLongPress: widget.onLongPress,
                      onLongPressDetails: (position, size, offset) {
                        _showOverlays(position, size, offset);
                      },
                      index: 0, // Will be set by parent
                      isFirstInGroup: widget.isFirstInGroup,
                      isLastInGroup: widget.isLastInGroup,
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
              // Spacing for received messages without avatars to keep alignment
              if (!widget.isMe && !widget.showAvatar)
                const SizedBox(width: 40), // 32 (avatar) + 8 (padding) = 40
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionMenu(
      BuildContext widgetContext, ScaffoldMessengerState messenger) {
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
                        try {
                          // Use Riverpod chat notifier instead of legacy ChatState
                          final chatNotifier =
                              ref.read(cn.chatNotifierProvider.notifier);

                          // Create Message from MessageData
                          MessageType domainMessageType;
                          switch (_messageData.type) {
                            case models.MessageType.text:
                              domainMessageType = MessageType.text;
                              break;
                            case models.MessageType.image:
                              domainMessageType = MessageType.image;
                              break;
                            case models.MessageType.video:
                              domainMessageType = MessageType.video;
                              break;
                            case models.MessageType.audio:
                              domainMessageType = MessageType.audio;
                              break;
                            default:
                              domainMessageType = MessageType.text;
                          }

                          final message = Message(
                            id: _messageData.id,
                            senderId: _messageData.senderUid,
                            text: _messageData.text,
                            timestamp: _messageData.timestamp,
                            messageType: domainMessageType,
                          );

                          debugPrint(
                              'MessageBubble: Setting reply to message ${message.id}');
                          chatNotifier.setReplyingToMessageObject(message);
                          debugPrint('✅ Reply message set in notifier');

                          _dismissOverlays();

                          // Show feedback
                          try {
                            messenger.showSnackBar(
                              const SnackBar(
                                  content: Text('Reply mode activated'),
                                  duration: Duration(seconds: 1)),
                            );
                            debugPrint('✅ Reply SnackBar shown');
                          } catch (e) {
                            debugPrint('⚠️ Could not show reply SnackBar: $e');
                          }
                        } catch (e) {
                          debugPrint('Error setting reply: $e');
                          if (widgetContext.mounted) {
                            messenger.showSnackBar(
                              SnackBar(
                                  content: Text('Failed to start reply: $e')),
                            );
                          }
                        }
                      },
                    ),
                    _buildDivider(),
                    _buildModernMenuItem(
                      icon: Icons.copy,
                      label: 'Copy',
                      onTap: () {
                        try {
                          Clipboard.setData(
                              ClipboardData(text: _messageData.text));
                          debugPrint('✅ Text copied to clipboard');

                          messenger.showSnackBar(
                            const SnackBar(
                                content: Text('Text copied'),
                                duration: Duration(seconds: 1)),
                          );
                          _dismissOverlays();
                        } catch (e) {
                          debugPrint('❌ Error copying text: $e');
                          messenger.showSnackBar(
                            SnackBar(content: Text('Failed to copy: $e')),
                          );
                        }
                      },
                    ),
                  ],
                ),
                // Smart Reply for received messages (spans 2 spaces)
                if (!widget.isMe) ...[
                  const SizedBox(height: 8),
                  _buildWideMenuItem(
                    icon: Icons.smart_toy,
                    label: 'Smart Reply',
                    onTap: () => _showSmartReplyBottomSheet(),
                  ),
                ],
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

                          if (!context.mounted) return;

                          final TextEditingController editController =
                              TextEditingController(text: _messageData.text);

                          final result = await showDialog<String>(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              backgroundColor:
                                  Theme.of(dialogContext).colorScheme.surface,
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
                                  onPressed: () => Navigator.pop(dialogContext),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    final text = editController.text.trim();
                                    Navigator.pop(dialogContext, text);
                                  },
                                  child: const Text('Save'),
                                ),
                              ],
                            ),
                          );

                          if (result != null &&
                              result.isNotEmpty &&
                              result != _messageData.text) {
                            if (!context.mounted) return;

                            try {
                              debugPrint(
                                  'Editing message ${_messageData.id} with new text: $result');

                              // Use the provided chatService or create a new instance
                              final chatService =
                                  widget.chatService ?? MessageService();
                              final squadState =
                                  ref.read(ln.lobbyNotifierProvider).maybeWhen(
                                        data: (data) => data,
                                        orElse: () => null,
                                      );

                              if (squadState != null) {
                                final squadId = squadState.selectedLobbyId;
                                if (squadId != null) {
                                  await chatService.editMessage(
                                      _messageData.id, result, squadId,
                                      chatGroupId: widget.chatGroupId,
                                      chatType: widget.chatType);

                                  debugPrint('Message edited successfully');
                                  try {
                                    messenger.showSnackBar(
                                      const SnackBar(
                                          content: Text('Message edited'),
                                          duration: Duration(seconds: 2)),
                                    );
                                  } catch (e) {
                                    debugPrint(
                                        '⚠️ Could not show SnackBar: $e');
                                  }
                                } else {
                                  throw Exception('Squad ID is null');
                                }
                              } else {
                                throw Exception('Squad state is null');
                              }
                            } catch (e) {
                              debugPrint('Error editing message: $e');
                              try {
                                messenger.showSnackBar(
                                  SnackBar(
                                      content:
                                          Text('Failed to edit message: $e'),
                                      duration: const Duration(seconds: 3)),
                                );
                              } catch (snackBarError) {
                                debugPrint(
                                    '⚠️ Could not show error SnackBar: $snackBarError');
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

                          if (!context.mounted) return;

                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              backgroundColor:
                                  Theme.of(dialogContext).colorScheme.surface,
                              elevation: 24,
                              title: const Text('Delete Message'),
                              content: const Text(
                                  'Are you sure you want to delete this message?'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, true),
                                  child: const Text('Delete',
                                      style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            if (!context.mounted) return;

                            // Unfocus keyboard to prevent it from popping up with error message
                            FocusScope.of(context).unfocus();

                            try {
                              debugPrint('Deleting message ${_messageData.id}');

                              // Use the provided chatService or create a new instance
                              final chatService =
                                  widget.chatService ?? MessageService();
                              final squadState =
                                  ref.read(ln.lobbyNotifierProvider).maybeWhen(
                                        data: (data) => data,
                                        orElse: () => null,
                                      );

                              if (squadState != null) {
                                final squadId = squadState.selectedLobbyId;
                                if (squadId != null) {
                                  await chatService.deleteMessage(
                                      _messageData.id, squadId,
                                      chatGroupId: widget.chatGroupId,
                                      chatType: widget.chatType);

                                  debugPrint('Message deleted successfully');
                                  if (!context.mounted) return;

                                  try {
                                    messenger.showSnackBar(
                                      const SnackBar(
                                          content: Text('Message deleted'),
                                          duration: Duration(seconds: 2)),
                                    );
                                    debugPrint('✅ Delete SnackBar shown');
                                  } catch (e) {
                                    debugPrint(
                                        '⚠️ Could not show delete SnackBar: $e');
                                  }
                                } else {
                                  throw Exception('Squad ID is null');
                                }
                              } else {
                                throw Exception('Squad state is null');
                              }
                            } catch (e) {
                              debugPrint('Error deleting message: $e');
                              if (!context.mounted) return;

                              // Ensure keyboard stays dismissed
                              FocusScope.of(context).unfocus();

                              // Add a small delay to ensure the error message is visible
                              await Future.delayed(
                                  const Duration(milliseconds: 100));

                              if (!context.mounted) return;

                              try {
                                messenger.showSnackBar(
                                  SnackBar(
                                      content:
                                          Text('Failed to delete message: $e'),
                                      duration: const Duration(seconds: 4),
                                      behavior: SnackBarBehavior.floating,
                                      margin: const EdgeInsets.only(
                                        bottom:
                                            80, // Position above keyboard area
                                        left: 16,
                                        right: 16,
                                      )),
                                );
                              } catch (snackBarError) {
                                debugPrint(
                                    '⚠️ Could not show error SnackBar: $snackBarError');
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
                        debugPrint(
                            '🔔 Bump button tapped for message ${_messageData.id}');
                        try {
                          _dismissOverlays();

                          // Call MessageService to bump the message
                          final chatGroupId = widget.chatGroupId;
                          if (chatGroupId == null) {
                            if (widgetContext.mounted) {
                              ScaffoldMessenger.of(widgetContext).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Cannot bump message: No chat group'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                            return;
                          }

                          final messageService = MessageService();
                          final result = await messageService.bumpMessage(
                            messageId: _messageData.id,
                            chatGroupId: chatGroupId,
                            chatType: widget.chatType,
                          );

                          // Show feedback
                          if (widgetContext.mounted) {
                            if (result.success) {
                              messenger.showSnackBar(
                                const SnackBar(
                                    content: Text('💬 Message bumped to top'),
                                    duration: Duration(seconds: 2)),
                              );
                              debugPrint(
                                  '✅ Message bumped: ${result.messageId}');
                            } else {
                              messenger.showSnackBar(
                                SnackBar(
                                    content: Text(
                                        'Failed to bump: ${result.errorMessage}'),
                                    duration: const Duration(seconds: 2)),
                              );
                              debugPrint(
                                  '❌ Bump failed: ${result.errorMessage}');
                            }
                          }
                        } catch (e) {
                          debugPrint('❌ Error bumping message: $e');
                          if (widgetContext.mounted) {
                            messenger.showSnackBar(
                              SnackBar(
                                  content: Text('Failed to bump: $e'),
                                  duration: const Duration(seconds: 2)),
                            );
                          }
                        }
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

  Widget _buildWideMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 148, // Double width (70 * 2 + 8 divider) for spanning 2 spaces
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.white.withValues(alpha: 0.1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 22,
              color: color ?? Colors.white.withValues(alpha: 0.9),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color ?? Colors.white.withValues(alpha: 0.9),
              ),
              textAlign: TextAlign.center,
            ),
          ],
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
    return GestureDetector(
      onTap: () {
        debugPrint('🔘 Menu item tapped: $label');
        onTap();
      },
      child: Container(
        width: 70, // Fixed width for consistent alignment
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.white
              .withValues(alpha: 0.1), // Add slight background for tap feedback
        ),
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
    // Group reactions by emoji with user lists
    final reactionsByEmoji = <String, List<String>>{};

    for (final reaction in _messageData.reactions) {
      final emoji = reaction['emoji']?.toString() ??
          reaction['reaction']?.toString() ??
          '';
      final userId = reaction['userId']?.toString() ?? '';

      if (emoji.isNotEmpty && userId.isNotEmpty) {
        reactionsByEmoji.putIfAbsent(emoji, () => []).add(userId);
      }
    }

    if (reactionsByEmoji.isEmpty) return;

    final currentUserId = AuthServiceSupabase().currentUser?.id;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Reactions',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                  ),
                ),
                const SizedBox(height: 16),
                // Reactions list
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: reactionsByEmoji.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: Colors.white.withOpacity(0.1),
                    ),
                    itemBuilder: (context, index) {
                      final emoji = reactionsByEmoji.keys.elementAt(index);
                      final userIds = reactionsByEmoji[emoji]!;
                      final currentUserReacted = currentUserId != null &&
                          userIds.contains(currentUserId);

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Emoji
                            Text(
                              emoji,
                              style: const TextStyle(fontSize: 28),
                            ),
                            const SizedBox(width: 16),
                            // User names
                            Expanded(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: userIds.map((userId) {
                                  final displayName = ref
                                          .read(userNotifierProvider.notifier)
                                          .getDisplayNameForUid(userId) ??
                                      'Unknown';
                                  final isCurrentUser = userId == currentUserId;

                                  return GestureDetector(
                                    onTap: isCurrentUser
                                        ? () async {
                                            // Remove reaction
                                            HapticFeedback.lightImpact();
                                            try {
                                              await ReactionService.addReaction(
                                                context,
                                                emoji,
                                                _messageData.id,
                                                widget.chatGroupId,
                                                widget.chatType,
                                                widget.squadId,
                                              );
                                              if (context.mounted) {
                                                Navigator.of(context).pop();
                                              }
                                            } catch (e) {
                                              debugPrint(
                                                  'Error removing reaction: $e');
                                            }
                                          }
                                        : null,
                                    child: Chip(
                                      label: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            displayName,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: isCurrentUser
                                                  ? Colors.white
                                                  : Colors.white
                                                      .withOpacity(0.9),
                                              fontWeight: isCurrentUser
                                                  ? FontWeight.w600
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                          if (isCurrentUser) ...[
                                            const SizedBox(width: 4),
                                            Icon(
                                              Icons.close,
                                              size: 14,
                                              color:
                                                  Colors.white.withOpacity(0.8),
                                            ),
                                          ],
                                        ],
                                      ),
                                      backgroundColor: isCurrentUser
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withOpacity(0.5)
                                          : Colors.white.withOpacity(0.15),
                                      side: BorderSide(
                                        color: isCurrentUser
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                                .withOpacity(0.7)
                                            : Colors.white.withOpacity(0.2),
                                        width: 1,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            // Remove button for current user's reactions
                            if (currentUserReacted)
                              IconButton(
                                icon: const Icon(Icons.remove_circle,
                                    color: Colors.red, size: 24),
                                onPressed: () async {
                                  HapticFeedback.lightImpact();
                                  try {
                                    await ReactionService.addReaction(
                                      context,
                                      emoji,
                                      _messageData.id,
                                      widget.chatGroupId,
                                      widget.chatType,
                                      widget.squadId,
                                    );
                                    if (context.mounted) {
                                      Navigator.of(context).pop();
                                    }
                                  } catch (e) {
                                    debugPrint('Error removing reaction: $e');
                                  }
                                },
                                tooltip: 'Remove your reaction',
                              ),
                          ],
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
    );
  }

  void _showSmartReplyBottomSheet() {
    _dismissOverlays();

    // Get last 5 messages for context
    final chatState = ref.read(cn.chatNotifierProvider).maybeWhen(
          data: (data) => data,
          orElse: () => null,
        );

    if (chatState == null) return;

    final messages = chatState.chatMessages[widget.chatGroupId] ?? [];
    final lastFiveMessages = messages.take(5).map((m) => m.text).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SmartReplyBottomSheet(
        lastFiveMessages: lastFiveMessages,
        onReplySelected: null, // Will copy to clipboard
      ),
    );
  }
}
