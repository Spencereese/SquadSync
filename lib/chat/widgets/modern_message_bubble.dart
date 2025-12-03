import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/app_theme.dart';
import '../models/message_data.dart';

/// Modern 2025-2026 MessageBubble with glassmorphic design
///
/// Features:
/// - Sharp corners (10px border radius)
/// - Glassmorphic fill with backdrop blur
/// - Neon accent line on left side
/// - Avatar clustering (last message only like Telegram/Discord)
/// - Reaction animations (fly in from bottom with bounce)
/// - Swipe right for quick reply
/// - Long press for reaction picker and menu
/// - Voice message waveform with neon progress
/// - Inline video with glass container
/// - Timestamp on hover/tap
class ModernMessageBubble extends ConsumerStatefulWidget {
  final MessageData message;
  final bool isMe;
  final bool isFirstInCluster;
  final bool isLastInCluster;
  final String? senderDisplayName;
  final Color? senderAccentColor;
  final String? senderAvatarUrl;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Function(MessageData)? onReply;
  final Function(String)? onReaction;
  final String? chatGroupId;
  final int index; // For stagger animation

  const ModernMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.isFirstInCluster = false,
    this.isLastInCluster = false,
    this.senderDisplayName,
    this.senderAccentColor,
    this.senderAvatarUrl,
    this.onTap,
    this.onLongPress,
    this.onReply,
    this.onReaction,
    this.chatGroupId,
    this.index = 0,
  });

  @override
  ConsumerState<ModernMessageBubble> createState() =>
      _ModernMessageBubbleState();
}

class _ModernMessageBubbleState extends ConsumerState<ModernMessageBubble>
    with TickerProviderStateMixin {
  // Swipe tracking
  double _swipeOffset = 0;

  // Timestamp visibility
  bool _showTimestamp = false;

  // Long press menu
  OverlayEntry? _reactionPickerOverlay;

  // Animation controllers
  late AnimationController _pressController;
  late AnimationController _swipeController;

  // Reaction animations
  final List<String> _newReactions = [];

  @override
  void initState() {
    super.initState();

    _pressController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _swipeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    _swipeController.dispose();
    _removeReactionPicker();
    super.dispose();
  }

  @override
  void didUpdateWidget(ModernMessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Detect new reactions
    final oldCount = oldWidget.message.reactions.length;
    final newCount = widget.message.reactions.length;

    if (newCount > oldCount) {
      // New reaction added - could track specific emoji if needed
      setState(() {
        // Animation trigger handled in build
      });
    }
  }

  void _handleHorizontalDragStart(DragStartDetails details) {
    // Drag started
  }

  void _handleHorizontalDragUpdate(DragUpdateDetails details) {
    // Only allow right swipe
    if (details.delta.dx > 0) {
      setState(() {
        _swipeOffset = (_swipeOffset + details.delta.dx).clamp(0.0, 80.0);
      });
    }
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    // Trigger reply if swiped far enough
    if (_swipeOffset > 60) {
      widget.onReply?.call(widget.message);
      HapticFeedback.mediumImpact();
    }

    // Animate back to position
    _swipeController.forward(from: 0).then((_) {
      setState(() {
        _swipeOffset = 0;
      });
    });
  }

  void _handleTap() {
    setState(() {
      _showTimestamp = !_showTimestamp;
    });
    widget.onTap?.call();
  }

  void _handleLongPress() {
    HapticFeedback.mediumImpact();
    _showReactionPickerOverlay();
    widget.onLongPress?.call();
  }

  void _showReactionPickerOverlay() {
    final renderBox = context.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _reactionPickerOverlay = OverlayEntry(
      builder: (context) => _ReactionPickerOverlay(
        position: position,
        size: size,
        isMe: widget.isMe,
        onReaction: (emoji) {
          widget.onReaction?.call(emoji);
          _removeReactionPicker();
        },
        onDismiss: _removeReactionPicker,
      ),
    );

    Overlay.of(context).insert(_reactionPickerOverlay!);
  }

  void _removeReactionPicker() {
    _reactionPickerOverlay?.remove();
    _reactionPickerOverlay = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = widget.senderAccentColor ?? theme.colorScheme.primary;

    return GestureDetector(
      onHorizontalDragStart: _handleHorizontalDragStart,
      onHorizontalDragUpdate: _handleHorizontalDragUpdate,
      onHorizontalDragEnd: _handleHorizontalDragEnd,
      onTap: _handleTap,
      onLongPress: _handleLongPress,
      child: Padding(
        padding: EdgeInsets.only(
          left: widget.isMe ? 60 : 8,
          right: widget.isMe ? 8 : 60,
          top: widget.isFirstInCluster ? 8 : 2,
          bottom: widget.isLastInCluster ? 8 : 2,
        ),
        child: Row(
          mainAxisAlignment:
              widget.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Avatar (only on last message in cluster)
            if (!widget.isMe && widget.isLastInCluster)
              _buildAvatar(accentColor)
            else if (!widget.isMe)
              const SizedBox(width: 40),

            const SizedBox(width: 8),

            // Message bubble with swipe offset
            Flexible(
              child: Transform.translate(
                offset: Offset(_swipeOffset, 0),
                child: Column(
                  crossAxisAlignment: widget.isMe
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    // Sender name (if first in cluster and not me)
                    if (!widget.isMe &&
                        widget.isFirstInCluster &&
                        widget.senderDisplayName != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 12, bottom: 4),
                        child: Text(
                          widget.senderDisplayName!,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: accentColor,
                          ),
                        ),
                      ),

                    // Main bubble
                    _buildBubble(theme, accentColor),

                    // Timestamp (shown on tap)
                    if (_showTimestamp)
                      _buildTimestamp(theme)
                          .animate()
                          .fadeIn(duration: 200.ms)
                          .slideY(begin: -0.2, duration: 200.ms),
                  ],
                ),
              ),
            ),

            // Reply indicator (when swiping)
            if (_swipeOffset > 20)
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 8),
                child: Icon(
                  Icons.reply_rounded,
                  size: 24,
                  color:
                      theme.colorScheme.primary.withOpacity(_swipeOffset / 80),
                ),
              ).animate().fadeIn().scale(begin: const Offset(0.5, 0.5)),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(
          duration: 300.ms,
          delay: (widget.index * 50).ms,
        )
        .slideY(
          begin: 0.2,
          duration: 400.ms,
          delay: (widget.index * 50).ms,
          curve: Curves.easeOutCubic,
        );
  }

  Widget _buildAvatar(Color accentColor) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor,
            accentColor.withOpacity(0.6),
          ],
        ),
        border: Border.all(
          color: accentColor.withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: accentColor.neonGlow(blur: 8, opacity: 0.3),
      ),
      child: widget.senderAvatarUrl != null
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: widget.senderAvatarUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => _buildAvatarFallback(),
                errorWidget: (context, url, error) => _buildAvatarFallback(),
              ),
            )
          : _buildAvatarFallback(),
    );
  }

  Widget _buildAvatarFallback() {
    final initial = widget.senderDisplayName?.isNotEmpty == true
        ? widget.senderDisplayName![0].toUpperCase()
        : '?';

    return Center(
      child: Text(
        initial,
        style: GoogleFonts.orbitron(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildBubble(ThemeData theme, Color accentColor) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Main glassmorphic bubble
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
                minWidth: 60,
              ),
              decoration: BoxDecoration(
                color: widget.isMe
                    ? theme.colorScheme.primary.withOpacity(0.12)
                    : Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border(
                  left: BorderSide(
                    color:
                        widget.isMe ? theme.colorScheme.primary : accentColor,
                    width: 3,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _buildMessageContent(theme),
            ),
          ),
        ),

        // Reactions (positioned below bubble)
        if (widget.message.reactions.isNotEmpty)
          Positioned(
            bottom: -16,
            left: widget.isMe ? null : 8,
            right: widget.isMe ? 8 : null,
            child: _buildReactions(theme),
          ),
      ],
    );
  }

  Widget _buildMessageContent(ThemeData theme) {
    switch (widget.message.type) {
      case MessageType.audio:
        return _buildVoiceMessage(theme);
      case MessageType.video:
        return _buildVideoMessage(theme);
      case MessageType.image:
        return _buildImageMessage(theme);
      default:
        return _buildTextMessage(theme);
    }
  }

  Widget _buildTextMessage(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Reply preview (if replying to another message)
        if (widget.message.replyTo != null) _buildReplyPreview(theme),

        // Message text
        Text(
          widget.message.text,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: Colors.white,
            height: 1.4,
          ),
        ),

        // Edited indicator
        if (widget.message.edited)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'edited',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: Colors.white54,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildReplyPreview(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border(
          left: BorderSide(
            color: theme.colorScheme.primary.withOpacity(0.6),
            width: 2,
          ),
        ),
      ),
      child: Text(
        'Replying to message...', // TODO: Fetch actual reply content
        style: GoogleFonts.inter(
          fontSize: 13,
          color: Colors.white70,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildVoiceMessage(ThemeData theme) {
    final duration = 30; // TODO: Get actual duration from audioUrl metadata
    final progress = 0.0; // TODO: Implement playback progress

    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Play button with neon ring
          Stack(
            alignment: Alignment.center,
            children: [
              // Neon progress ring
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 3,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  valueColor:
                      AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                ),
              ),
              // Play icon
              Icon(
                Icons.play_arrow_rounded,
                size: 24,
                color: theme.colorScheme.primary,
              ),
            ],
          ),

          const SizedBox(width: 12),

          // Waveform
          Expanded(
            child: _buildWaveform(theme, progress),
          ),

          const SizedBox(width: 8),

          // Duration
          Text(
            _formatDuration(duration),
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaveform(ThemeData theme, double progress) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(20, (index) {
        final height = 4.0 + (index % 5) * 4.0;
        final isPlayed = (index / 20) <= progress;

        return Container(
          width: 2,
          height: height,
          decoration: BoxDecoration(
            color: isPlayed
                ? theme.colorScheme.primary
                : Colors.white.withOpacity(0.3),
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  Widget _buildVideoMessage(ThemeData theme) {
    final thumbnailUrl =
        widget.message.videoUrl; // Use video URL as placeholder

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 240,
        height: 180,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video thumbnail
            if (thumbnailUrl != null)
              CachedNetworkImage(
                imageUrl: thumbnailUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.black26,
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.black26,
                  child: const Icon(Icons.error_outline, color: Colors.white54),
                ),
              ),

            // Glass overlay with play button
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.primary.withOpacity(0.6),
                        width: 2,
                      ),
                      boxShadow: theme.colorScheme.primary
                          .neonGlow(blur: 20, opacity: 0.4),
                    ),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      size: 36,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageMessage(ThemeData theme) {
    final imageUrl = widget.message.photos.isNotEmpty
        ? widget.message.photos[0]['uri'] as String?
        : null;

    if (imageUrl == null) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 280,
          maxHeight: 320,
        ),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            width: 200,
            height: 200,
            color: Colors.white.withOpacity(0.05),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            width: 200,
            height: 200,
            color: Colors.white.withOpacity(0.05),
            child: const Icon(Icons.error_outline, color: Colors.white54),
          ),
        ),
      ),
    );
  }

  Widget _buildReactions(ThemeData theme) {
    final reactions = widget.message.reactions;

    // Group reactions by emoji
    final Map<String, int> reactionCounts = {};
    for (final reaction in reactions) {
      final emoji = reaction['emoji'] as String? ?? '👍';
      reactionCounts[emoji] = (reactionCounts[emoji] ?? 0) + 1;
    }

    if (reactionCounts.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: reactionCounts.entries.map((entry) {
          final emoji = entry.key;
          final count = entry.value;
          final isNew = _newReactions.contains(emoji);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  emoji,
                  style: const TextStyle(fontSize: 16),
                ),
                if (count > 1) ...[
                  const SizedBox(width: 4),
                  Text(
                    count.toString(),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ],
            ),
          )
              .animate(key: ValueKey('$emoji-$count'))
              .fadeIn(duration: isNew ? 300.ms : 0.ms)
              .slideY(
                begin: isNew ? 1.0 : 0.0,
                duration: isNew ? 400.ms : 0.ms,
                curve: Curves.elasticOut,
              )
              .scale(
                begin: isNew ? const Offset(0, 0) : const Offset(1, 1),
                end: const Offset(1, 1),
                duration: isNew ? 400.ms : 0.ms,
                curve: Curves.elasticOut,
              );
        }).toList(),
      ),
    );
  }

  Widget _buildTimestamp(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 12, right: 12),
      child: Text(
        _formatTimestamp(widget.message.timestamp),
        style: GoogleFonts.inter(
          fontSize: 11,
          color: Colors.white54,
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else {
      return '${timestamp.month}/${timestamp.day} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
}

/// Reaction picker overlay that appears on long press
class _ReactionPickerOverlay extends StatelessWidget {
  final Offset position;
  final Size size;
  final bool isMe;
  final Function(String) onReaction;
  final VoidCallback onDismiss;

  const _ReactionPickerOverlay({
    required this.position,
    required this.size,
    required this.isMe,
    required this.onReaction,
    required this.onDismiss,
  });

  static const _quickReactions = ['👍', '❤️', '😂', '😮', '😢', '🙏', '🔥'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onDismiss,
      behavior: HitTestBehavior.translucent,
      child: Stack(
        children: [
          // Backdrop
          Container(
            color: Colors.black.withOpacity(0.3),
          ),

          // Reaction picker positioned above message
          Positioned(
            left: isMe ? null : position.dx,
            right: isMe
                ? MediaQuery.of(context).size.width - position.dx - size.width
                : null,
            top: position.dy - 80,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.primary.withOpacity(0.4),
                      width: 1.5,
                    ),
                    boxShadow: theme.colorScheme.primary.neonGlow(
                      blur: 20,
                      opacity: 0.3,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: _quickReactions.map((emoji) {
                      return GestureDetector(
                        onTap: () => onReaction(emoji),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 28),
                          ),
                        ).animate().scale(
                              begin: const Offset(0, 0),
                              duration: 200.ms,
                              delay: (_quickReactions.indexOf(emoji) * 30).ms,
                              curve: Curves.elasticOut,
                            ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            )
                .animate()
                .fadeIn(duration: 150.ms)
                .slideY(begin: 0.2, duration: 200.ms, curve: Curves.easeOut),
          ),

          // Menu options below message
          Positioned(
            left: isMe ? null : position.dx,
            right: isMe
                ? MediaQuery.of(context).size.width - position.dx - size.width
                : null,
            top: position.dy + size.height + 8,
            child: _buildMenuOptions(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuOptions(ThemeData theme) {
    final options = [
      {'icon': Icons.reply_rounded, 'label': 'Reply'},
      {'icon': Icons.copy_rounded, 'label': 'Copy'},
      {'icon': Icons.edit_rounded, 'label': 'Edit'},
      {'icon': Icons.delete_outline_rounded, 'label': 'Delete'},
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((option) {
              return InkWell(
                onTap: () {
                  // Handle menu action
                  onDismiss();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        option['icon'] as IconData,
                        size: 20,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        option['label'] as String,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 150.ms, delay: 100.ms).slideY(
        begin: -0.2, duration: 200.ms, delay: 100.ms, curve: Curves.easeOut);
  }
}
