import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/auth_service_supabase.dart';
import 'package:intl/intl.dart';
import '../../chat/models/message_data.dart';
import '../../domain/entities/message.dart';
import '../../presentation/notifiers/chat_notifier.dart';
import '../../chat/widgets/clip_player_screen.dart';

/// Large clip feed item for infinite scroll feed (similar to ClipMessageBubble but bigger)
class ClipFeedItem extends ConsumerStatefulWidget {
  final MessageData messageData;
  final String chatGroupId;
  final ChatType chatType;
  final Color? gameColor;
  final List<MessageData>? allClips;
  final VoidCallback? onView; // Callback when clip is viewed

  const ClipFeedItem({
    super.key,
    required this.messageData,
    required this.chatGroupId,
    required this.chatType,
    this.gameColor,
    this.allClips,
    this.onView,
  });

  @override
  ConsumerState<ClipFeedItem> createState() => _ClipFeedItemState();
}

class _ClipFeedItemState extends ConsumerState<ClipFeedItem> {
  bool _isHovered = false;
  bool _hasIncrementedView = false;

  @override
  void initState() {
    super.initState();
    // Mark as viewed when widget appears
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasIncrementedView && mounted) {
        _hasIncrementedView = true;
        widget.onView?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final clipData = widget.messageData.clipData;
    if (clipData == null) {
      return const SizedBox.shrink();
    }

    final neonColor = widget.gameColor ?? const Color(0xFF00FFFF);
    final isUploading = widget.messageData.status == MessageStatus.sending;
    final currentUser = AuthServiceSupabase().currentUser;
    final hasHyped = clipData.hypeReactions.contains(currentUser?.id);

    return GestureDetector(
      onTap: isUploading ? null : _handleTap,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: neonColor.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                // Background thumbnail
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: CachedNetworkImage(
                    imageUrl: clipData.thumbnailUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[900],
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(neonColor),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[900],
                      child: Icon(Icons.error, color: Colors.red, size: 48),
                    ),
                  ),
                ),

                // Glassmorphic overlay
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 0.5, sigmaY: 0.5),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.2),
                            Colors.black.withOpacity(0.7),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Pulsing play button
                if (!isUploading)
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withOpacity(0.5),
                          border: Border.all(color: neonColor, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: neonColor.withOpacity(0.5),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.play_arrow,
                          color: neonColor,
                          size: 48,
                        ),
                      )
                          .animate(onPlay: (controller) => controller.repeat())
                          .scale(
                            begin: const Offset(1.0, 1.0),
                            end: const Offset(1.1, 1.1),
                            duration: const Duration(milliseconds: 1000),
                          )
                          .then()
                          .scale(
                            begin: const Offset(1.1, 1.1),
                            end: const Offset(1.0, 1.0),
                            duration: const Duration(milliseconds: 1000),
                          ),
                    ),
                  ),

                // Duration badge
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: neonColor.withOpacity(0.5), width: 1),
                    ),
                    child: Text(
                      _formatDuration(clipData.durationSec),
                      style: TextStyle(
                        color: neonColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Orbitron',
                      ),
                    ),
                  ),
                ),

                // Author info at bottom
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.9),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Author name
                        Text(
                          widget.messageData.sender.isNotEmpty
                              ? widget.messageData.sender
                              : 'Unknown',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Timestamp
                        Text(
                          _formatTimestamp(widget.messageData.timestamp),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Stats row
                        Row(
                          children: [
                            // Hype button
                            _buildStatButton(
                              icon: Icons.local_fire_department,
                              count: clipData.hypeReactions.length,
                              color: hasHyped ? Colors.orange : Colors.white70,
                              onTap: _toggleHype,
                            ),
                            const SizedBox(width: 16),

                            // View count
                            _buildStatDisplay(
                              icon: Icons.visibility,
                              count: clipData.views,
                              color: Colors.cyanAccent,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Upload progress
                if (isUploading)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.7),
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(neonColor),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatButton({
    required IconData icon,
    required int count,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color == Colors.orange
              ? Colors.orange.withOpacity(0.2)
              : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 4),
            Text(
              count.toString(),
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatDisplay({
    required IconData icon,
    required int count,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 4),
        Text(
          count.toString(),
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(timestamp);
    }
  }

  Future<void> _toggleHype() async {
    HapticFeedback.lightImpact();

    try {
      await ref.read(chatNotifierProvider.notifier).toggleClipHype(
            widget.chatGroupId,
            widget.messageData.id,
            widget.chatType,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to hype clip: $e')),
        );
      }
    }
  }

  void _handleTap() {
    HapticFeedback.mediumImpact();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClipPlayerScreen(
          clipData: widget.messageData.clipData!,
          messageData: widget.messageData,
          chatGroupId: widget.chatGroupId,
          chatType: widget.chatType,
          gameColor: widget.gameColor,
          squadClips: widget.allClips,
        ),
        fullscreenDialog: true,
      ),
    );
  }
}
