import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/app_theme.dart';
import '../domain/entities/squad.dart';

/// Glassmorphic squad card for discovery screen with Tinder-style swipe support
///
/// Features:
/// - Heavy backdrop blur with game cover background
/// - Dynamic neon glow matching game colors
/// - Peacock timer ring animation
/// - Hover effects with scale and glow
/// - Hero animation support for transitions
class GlassSquadCard extends StatelessWidget {
  final Squad squad;
  final String? gameCoverUrl;
  final Color? gamePrimaryColor;
  final VoidCallback? onTap;
  final bool showPeacockTimer;
  final double? peacockProgress; // 0.0 to 1.0
  final String heroTag;

  const GlassSquadCard({
    super.key,
    required this.squad,
    this.gameCoverUrl,
    this.gamePrimaryColor,
    this.onTap,
    this.showPeacockTimer = false,
    this.peacockProgress,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final neonColor = gamePrimaryColor ?? theme.colorScheme.primary;
    final memberCount = squad.memberUids.length;
    final maxSlots = squad.maxSpots;

    return Hero(
      tag: heroTag,
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: _buildAnimatedCard(
              context, theme, neonColor, memberCount, maxSlots),
        ),
      ),
    );
  }

  Widget _buildAnimatedCard(
    BuildContext context,
    ThemeData theme,
    Color neonColor,
    int memberCount,
    int maxSlots,
  ) {
    return Container(
      width: double.infinity,
      height: 520,
      child: Stack(
        children: [
          // Base card with glass effect and background
          _buildGlassCard(context, theme, neonColor),

          // Peacock timer ring overlay (if active)
          if (showPeacockTimer && peacockProgress != null)
            _buildPeacockTimerRing(neonColor),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, curve: Curves.easeOut)
        .scale(
          begin: const Offset(0.95, 0.95),
          end: const Offset(1.0, 1.0),
          duration: 400.ms,
          curve: Curves.easeOutBack,
        )
        .shimmer(
          duration: 2000.ms,
          color: neonColor.withOpacity(0.1),
        );
  }

  Widget _buildGlassCard(
      BuildContext context, ThemeData theme, Color neonColor) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          // Background: Game cover with dark overlay
          _buildBackground(),

          // Heavy backdrop blur
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.3),
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Glass surface with neon border
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: neonColor.withOpacity(0.6),
                width: 2,
              ),
              boxShadow: neonColor.neonGlow(
                blur: 25,
                spread: 2,
                opacity: 0.4,
              ),
            ),
          ),

          // Content
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: _buildContent(context, theme, neonColor),
            ),
          ),
        ],
      ),
    )
        .animate(
          onPlay: (controller) => controller.repeat(reverse: true),
        )
        .moveY(
          begin: 0,
          end: -8,
          duration: 3000.ms,
          curve: Curves.easeInOut,
        );
  }

  Widget _buildBackground() {
    if (gameCoverUrl != null && gameCoverUrl!.isNotEmpty) {
      return Positioned.fill(
        child: CachedNetworkImage(
          imageUrl: gameCoverUrl!,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: const Color(0xFF14181F),
          ),
          errorWidget: (context, url, error) => Container(
            color: const Color(0xFF14181F),
            child: const Icon(Icons.videogame_asset,
                size: 80, color: Colors.white24),
          ),
        ),
      );
    }

    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF14181F),
              const Color(0xFF0B0E14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ThemeData theme, Color neonColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header: Squad name with glow
        _buildHeader(theme, neonColor),

        const SizedBox(height: 16),

        // Game badge
        _buildGameBadge(theme, neonColor),

        const Spacer(),

        // Member avatars grid
        _buildMemberAvatars(theme, neonColor),

        const SizedBox(height: 16),

        // Footer: Stats and indicators
        _buildFooter(theme, neonColor),
      ],
    );
  }

  Widget _buildHeader(ThemeData theme, Color neonColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: neonColor.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: neonColor.neonGlow(blur: 15, opacity: 0.3),
      ),
      child: Text(
        squad.name,
        style: GoogleFonts.orbitron(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 1.2,
          shadows: neonColor.neonGlow(blur: 20, opacity: 0.8).map((shadow) {
            return Shadow(
              color: shadow.color,
              blurRadius: shadow.blurRadius,
              offset: shadow.offset,
            );
          }).toList(),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    )
        .animate(
          onPlay: (controller) => controller.repeat(reverse: true),
        )
        .shimmer(
          duration: 2500.ms,
          color: neonColor.withOpacity(0.3),
        );
  }

  Widget _buildGameBadge(ThemeData theme, Color neonColor) {
    final gameName = squad.gameName;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: neonColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: neonColor.withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.videogame_asset_rounded,
            size: 18,
            color: neonColor,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              gameName,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberAvatars(ThemeData theme, Color neonColor) {
    final members = squad.memberUids;
    final displayCount = members.length > 5 ? 5 : members.length;
    final remaining = members.length > 5 ? members.length - 5 : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: neonColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SQUAD MEMBERS',
            style: GoogleFonts.orbitron(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: neonColor,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              // Show first 5 members
              ...List.generate(displayCount, (index) {
                return _buildMemberAvatar(
                  members[index],
                  neonColor,
                  index,
                );
              }),

              // Show "+X" if more members
              if (remaining > 0) _buildRemainingCount(remaining, neonColor),

              // Empty slots
              ...List.generate(
                squad.maxSpots - members.length,
                (index) => _buildEmptySlot(neonColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMemberAvatar(String memberId, Color neonColor, int index) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            neonColor.withOpacity(0.6),
            neonColor.withOpacity(0.3),
          ],
        ),
        border: Border.all(
          color: neonColor,
          width: 2,
        ),
        boxShadow: neonColor.neonGlow(blur: 12, opacity: 0.4),
      ),
      child: Center(
        child: Text(
          memberId.isNotEmpty ? memberId[0].toUpperCase() : '?',
          style: GoogleFonts.orbitron(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    ).animate(delay: (index * 100).ms).scale(
          begin: const Offset(0, 0),
          duration: 300.ms,
          curve: Curves.elasticOut,
        );
  }

  Widget _buildRemainingCount(int count, Color neonColor) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withOpacity(0.6),
        border: Border.all(
          color: neonColor.withOpacity(0.6),
          width: 2,
        ),
      ),
      child: Center(
        child: Text(
          '+$count',
          style: GoogleFonts.orbitron(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: neonColor,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptySlot(Color neonColor) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.05),
        border: Border.all(
          color: neonColor.withOpacity(0.2),
          width: 2,
          strokeAlign: BorderSide.strokeAlignInside,
        ),
      ),
      child: Icon(
        Icons.person_add_outlined,
        size: 24,
        color: neonColor.withOpacity(0.4),
      ),
    );
  }

  Widget _buildFooter(ThemeData theme, Color neonColor) {
    final memberCount = squad.memberUids.length;
    final maxSlots = squad.maxSpots;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: neonColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Player count
          _buildStatBadge(
            icon: Icons.people_rounded,
            label: '$memberCount/$maxSlots',
            neonColor: neonColor,
          ),

          const SizedBox(width: 16),

          // Voice indicator
          _buildStatBadge(
            icon: Icons.mic_rounded,
            label: 'Voice',
            neonColor: neonColor,
            isActive: true,
          ),

          const Spacer(),

          // Join arrow
          Icon(
            Icons.arrow_forward_rounded,
            color: neonColor,
            size: 24,
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge({
    required IconData icon,
    required String label,
    required Color neonColor,
    bool isActive = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isActive
            ? neonColor.withOpacity(0.2)
            : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isActive
              ? neonColor.withOpacity(0.6)
              : neonColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isActive ? neonColor : Colors.white70,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isActive ? neonColor : Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeacockTimerRing(Color neonColor) {
    return Positioned.fill(
      child: CustomPaint(
        painter: _PeacockTimerPainter(
          progress: peacockProgress ?? 0.0,
          color: neonColor,
        ),
      ),
    )
        .animate(
          onPlay: (controller) => controller.repeat(),
        )
        .shimmer(
          duration: 1500.ms,
          color: neonColor.withOpacity(0.3),
        );
  }
}

/// Custom painter for peacock timer ring around card
class _PeacockTimerPainter extends CustomPainter {
  final double progress;
  final Color color;

  _PeacockTimerPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width > size.height ? size.height : size.width) / 2;

    // Background ring (dim)
    final bgPaint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 3),
      -90 * (3.14159 / 180), // Start from top
      360 * (3.14159 / 180), // Full circle
      false,
      bgPaint,
    );

    // Progress ring (glowing)
    final progressPaint = Paint()
      ..shader = SweepGradient(
        startAngle: -90 * (3.14159 / 180),
        colors: [
          color,
          color.withOpacity(0.5),
          color,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 3),
      -90 * (3.14159 / 180), // Start from top
      (360 * progress) * (3.14159 / 180), // Progress arc
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_PeacockTimerPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

/// Hover extension for interactive scaling and glow
extension GlassSquadCardHover on Widget {
  Widget withHoverEffect(Color neonColor) {
    return MouseRegion(
      onEnter: (_) {},
      onExit: (_) {},
      child: this,
    )
        .animate(
          adapter: ValueAdapter(0.0),
        )
        .scaleXY(
          begin: 1.0,
          end: 1.05,
          duration: 200.ms,
          curve: Curves.easeOut,
        )
        .then()
        .custom(
          duration: 300.ms,
          builder: (context, value, child) {
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: neonColor.neonGlow(
                  blur: 30 + (value * 20),
                  spread: 2 + (value * 2),
                  opacity: 0.4 + (value * 0.3),
                ),
              ),
              child: child,
            );
          },
        );
  }
}
