import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/reaction_service.dart';
import '../../services/ai_service.dart';

/// iMessage-style reactions bar that appears above messages
/// Features pill-shaped blur background, horizontal swipeable emojis, and visual connector
class IMessageReactionsBar extends StatefulWidget {
  final String messageId;
  final String? chatGroupId;
  final ChatType chatType;
  final bool isOutgoing;
  final VoidCallback onDismiss;
  final Offset messagePosition;
  final Size messageSize;
  final double floatingOffset;

  const IMessageReactionsBar({
    super.key,
    required this.messageId,
    this.chatGroupId,
    required this.chatType,
    required this.isOutgoing,
    required this.onDismiss,
    required this.messagePosition,
    required this.messageSize,
    this.floatingOffset = 0.0,
  });

  @override
  State<IMessageReactionsBar> createState() => _IMessageReactionsBarState();
}

class _IMessageReactionsBarState extends State<IMessageReactionsBar>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  final ScrollController _scrollController = ScrollController();
  final List<String> _commonEmojis = [
    '❤️',
    '👍',
    '👎',
    '😂',
    '😮',
    '🙌',
    '😢',
    '😡',
    '🤔',
    '😴',
    '🤗',
    '🤩',
    '🥳',
    '🤪',
    '😇',
    '🤓',
    '😎',
    '🥺',
    '😭',
    '😤',
    '🤬',
    '🤯',
    '🤐',
    '🤨',
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _dismiss() {
    _animationController.reverse().then((_) {
      widget.onDismiss();
    });
  }

  void _addReaction(String emoji) {
    HapticFeedback.lightImpact();
    ReactionService.addReaction(
      context,
      emoji,
      widget.messageId,
      widget.chatGroupId,
      widget.chatType,
    );
    _dismiss();
  }

  void _openEmojiPicker() {
    HapticFeedback.lightImpact();
    // TODO: Implement native iOS emoji keyboard or Flutter emoji picker
    // For now, just dismiss
    _dismiss();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    // Calculate position above the message - lower and towards the message bubble
    final barHeight = 56.0;
    final connectorHeight = 16.0;
    final spacing =
        -12.0; // More negative spacing to bring even closer to message bubble
    final totalHeight = barHeight + connectorHeight + spacing;

    // Position bar so connector touches message bubble
    final barTop =
        widget.messagePosition.dy - totalHeight + widget.floatingOffset;
    final shouldShowBelow = barTop < MediaQuery.of(context).padding.top + 20;

    final finalBarTop = shouldShowBelow
        ? widget.messagePosition.dy +
            widget.messageSize.height +
            spacing +
            widget.floatingOffset
        : barTop;

    // Calculate horizontal position - cover most of screen width with padding on opposite side
    final padding = 16.0; // Minimal padding from screen edges
    final avatarSpace = 60.0; // Space needed for avatars

    // For outgoing messages (right-aligned), more padding on left (opposite side)
    // For incoming messages (left-aligned), more padding on right (opposite side)
    final leftPadding = widget.isOutgoing ? avatarSpace : padding;
    final rightPadding = widget.isOutgoing ? padding : avatarSpace;

    final barWidth = screenSize.width - leftPadding - rightPadding;
    final barLeft = leftPadding;

    return Stack(
      children: [
        // Background tap to dismiss
        GestureDetector(
          onTap: _dismiss,
          child: Container(
            color: Colors.transparent,
            width: screenSize.width,
            height: screenSize.height,
          ),
        ),

        // Reactions bar
        Positioned(
          top: finalBarTop,
          left: barLeft,
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) => Transform.scale(
              scale: _scaleAnimation.value,
              child: Opacity(
                opacity: _fadeAnimation.value,
                child: _buildReactionsPill(barWidth),
              ),
            ),
          ),
        ),

        // Visual connector (grey smiley) - positioned closer to message bubble and moved up
        Positioned(
          top: widget.messagePosition.dy +
              widget.messageSize.height / 2 -
              28, // Move up more for sent messages - don't follow floating offset
          left: widget.isOutgoing
              ? widget.messagePosition.dx -
                  20 // Left side for outgoing messages, moved further left
              : widget.messagePosition.dx -
                  16, // Left side for incoming messages, closer
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) => Opacity(
              opacity: _fadeAnimation.value,
              child: _buildConnector(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReactionsPill(double width) {
    return Material(
      elevation: 15, // High elevation to ensure it's above message bubbles
      shadowColor: Colors.black.withValues(alpha: 0.4),
      child: Container(
        width: width,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: Colors.black.withValues(alpha: 0.7),
              child: Row(
                children: [
                  // Horizontal scrollable emoji list
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount:
                          _commonEmojis.length + 1, // +1 for the smiley at end
                      itemBuilder: (context, index) {
                        if (index == _commonEmojis.length) {
                          // Grey smiley at the end
                          return _buildEmojiButton(
                            '😊',
                            isGreyedOut: true,
                            onTap: _openEmojiPicker,
                          );
                        }

                        final emoji = _commonEmojis[index];
                        return _buildEmojiButton(
                          emoji,
                          onTap: () => _addReaction(emoji),
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
    ).animate().slideY(
          duration: const Duration(milliseconds: 300),
          begin: -0.2,
          end: 0.0,
          curve: Curves.easeOutBack,
        );
  }

  Widget _buildEmojiButton(
    String emoji, {
    required VoidCallback onTap,
    bool isGreyedOut = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isGreyedOut
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Center(
          child: Text(
            emoji,
            style: TextStyle(
              fontSize: 24,
              color: isGreyedOut
                  ? Colors.white.withValues(alpha: 0.5)
                  : Colors.white,
              decoration: TextDecoration.none, // Remove underlines
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnector() {
    return Material(
      elevation: 15, // High elevation to ensure it's above message bubbles
      shadowColor: Colors.black.withValues(alpha: 0.4),
      child: Container(
        width: 32, // Circle size
        height: 32, // Circle size - now a full circle
        decoration: BoxDecoration(
          borderRadius:
              BorderRadius.circular(16), // Half of size for perfect circle
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: Colors.black.withValues(alpha: 0.7),
              child: Center(
                child: Icon(
                  Icons.tag_faces, // Material Design smiley face icon
                  size: 16, // Larger icon for the bigger circle
                  color: const Color(0xFF666666), // Grey color
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
