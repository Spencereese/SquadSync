import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/auth_service_supabase.dart';
import '../models/message_data.dart';
import '../../domain/entities/message.dart';
import '../../presentation/notifiers/chat_notifier.dart';
import 'clip_player_screen.dart';

/// NEON VOID themed clip message bubble with glassmorphism and pulsing play icon
class ClipMessageBubble extends ConsumerStatefulWidget {
  final MessageData messageData;
  final bool isMe;
  final String chatGroupId;
  final ChatType chatType;
  final Color? gameColor; // Optional game-specific neon color
  final List<MessageData>? squadClips; // For auto-play next

  const ClipMessageBubble({
    super.key,
    required this.messageData,
    required this.isMe,
    required this.chatGroupId,
    required this.chatType,
    this.gameColor,
    this.squadClips,
  });

  @override
  ConsumerState<ClipMessageBubble> createState() => _ClipMessageBubbleState();
}

class _ClipMessageBubbleState extends ConsumerState<ClipMessageBubble> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final clipData = widget.messageData.clipData;
    if (clipData == null) {
      return const SizedBox.shrink();
    }

    // Use game color or default cyan neon
    final neonColor = widget.gameColor ?? const Color(0xFF00FFFF);
    final isUploading = widget.messageData.status == MessageStatus.sending;

    return GestureDetector(
      onTap: isUploading ? null : _handleTap,
      onTapDown: (_) => setState(() => _isHovered = true),
      onTapUp: (_) => setState(() => _isHovered = false),
      onTapCancel: () => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: 280,
          height: 400,
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Stack(
            children: [
              // Main glassmorphic card with neon border
              _buildGlassmorphicCard(neonColor, clipData, isUploading),

              // Top gradient overlay for readability
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 120,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.6),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom gradient overlay for badges
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 80,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Content overlay
              if (isUploading)
                _buildUploadingOverlay()
              else
                _buildContentOverlay(neonColor, clipData),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassmorphicCard(
      Color neonColor, ClipMessageData clipData, bool isUploading) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: neonColor.withOpacity(0.5),
          width: 2,
        ),
        boxShadow: [
          // Neon glow effect
          BoxShadow(
            color: neonColor.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
          // Depth shadow
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail image
            if (!isUploading && clipData.thumbnailUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: clipData.thumbnailUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[900],
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF00FFFF),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[900],
                  child: const Icon(
                    Icons.videocam_off,
                    color: Colors.white38,
                    size: 64,
                  ),
                ),
              ),

            // Dark overlay for contrast
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.1),
                  ],
                ),
              ),
            ),

            // Glassmorphic blur effect
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 0.5, sigmaY: 0.5),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.05),
                      Colors.white.withOpacity(0.02),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentOverlay(Color neonColor, ClipMessageData clipData) {
    return Positioned.fill(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Sender name at top (if not me)
            if (!widget.isMe)
              Align(
                alignment: Alignment.topLeft,
                child: Text(
                  widget.messageData.sender,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    shadows: [
                      Shadow(
                        color: Colors.black,
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),

            // Center play button with pulse animation
            Expanded(
              child: Center(
                child: _buildPulsingPlayButton(neonColor),
              ),
            ),

            // Bottom badges row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Duration badge
                _buildDurationBadge(clipData.durationSec),

                // Hype button
                _buildHypeButton(neonColor, clipData),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPulsingPlayButton(Color neonColor) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: neonColor.withOpacity(0.2),
        border: Border.all(
          color: neonColor,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: neonColor.withOpacity(0.5),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Icon(
        Icons.play_arrow_rounded,
        size: 48,
        color: neonColor,
      ),
    )
        .animate(onPlay: (controller) => controller.repeat())
        .scale(
          begin: const Offset(1.0, 1.0),
          end: const Offset(1.1, 1.1),
          duration: 1200.ms,
          curve: Curves.easeInOut,
        )
        .then()
        .scale(
          begin: const Offset(1.1, 1.1),
          end: const Offset(1.0, 1.0),
          duration: 1200.ms,
          curve: Curves.easeInOut,
        );
  }

  Widget _buildDurationBadge(int durationSec) {
    final minutes = durationSec ~/ 60;
    final seconds = durationSec % 60;
    final timeStr = '${minutes}:${seconds.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.access_time,
            color: Colors.white70,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            timeStr,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHypeButton(Color neonColor, ClipMessageData clipData) {
    final hypeCount = clipData.hypeReactions.length;
    final currentUser = AuthServiceSupabase().currentUser;
    final isHyped =
        currentUser != null && clipData.hypeReactions.contains(currentUser.id);

    return GestureDetector(
      onTap: _handleHypeTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isHyped
              ? neonColor.withOpacity(0.3)
              : Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isHyped ? neonColor : Colors.white.withOpacity(0.2),
            width: isHyped ? 2 : 1,
          ),
          boxShadow: isHyped
              ? [
                  BoxShadow(
                    color: neonColor.withOpacity(0.4),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '🔥',
              style: TextStyle(
                fontSize: isHyped ? 20 : 18,
              ),
            ),
            if (hypeCount > 0) ...[
              const SizedBox(width: 6),
              Text(
                hypeCount.toString(),
                style: TextStyle(
                  color: isHyped ? neonColor : Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    ).animate(target: isHyped ? 1 : 0).scale(
          begin: const Offset(1.0, 1.0),
          end: const Offset(1.2, 1.2),
          duration: 200.ms,
          curve: Curves.elasticOut,
        );
  }

  Widget _buildUploadingOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: Colors.black.withOpacity(0.8),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Color(0xFF00FFFF),
              strokeWidth: 3,
            ),
            SizedBox(height: 16),
            Text(
              'Uploading...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleTap() async {
    final clipData = widget.messageData.clipData;
    if (clipData == null) return;

    // Increment view count
    await ref.read(chatNotifierProvider.notifier).incrementClipViews(
          widget.chatGroupId,
          widget.messageData.id,
          widget.chatType,
        );

    // Navigate to full-screen player
    if (mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ClipPlayerScreen(
            clipData: clipData,
            messageData: widget.messageData,
            chatGroupId: widget.chatGroupId,
            chatType: widget.chatType,
            gameColor: widget.gameColor,
            squadClips: widget.squadClips,
          ),
          fullscreenDialog: true,
        ),
      );
    }
  }

  void _handleHypeTap() async {
    await ref.read(chatNotifierProvider.notifier).toggleClipHype(
          widget.chatGroupId,
          widget.messageData.id,
          widget.chatType,
        );
  }
}
