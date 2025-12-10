import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_theme.dart';
import '../../screens/voice_room_screen.dart';

/// Custom iMessage-style app bar for ChatScreen with NEON VOID glass aesthetics
///
/// Features:
/// - Frosted glass background with blur
/// - Left: Back button in glass bubble
/// - Center: Tappable avatar + squad name in overlapping layout
/// - Right: Gamepad button (lobby creation) + Voice chat button in glass bubbles
/// - Hero animation support for avatar transitions
class NeonChatAppBar extends StatelessWidget {
  final String squadId;
  final String squadName;
  final String? avatarUrl;
  final VoidCallback onBackPressed;
  final VoidCallback? onCenterTapped;
  final VoidCallback? onGamepadPressed;

  const NeonChatAppBar({
    super.key,
    required this.squadId,
    required this.squadName,
    this.avatarUrl,
    required this.onBackPressed,
    this.onCenterTapped,
    this.onGamepadPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final neonColor = theme.colorScheme.primary;

    return SliverAppBar(
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      automaticallyImplyLeading: false,
      expandedHeight: 100,
      collapsedHeight: 100,
      flexibleSpace: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // Left: Back button in glass bubble
              _GlassCircleButton(
                icon: Icons.chevron_left,
                onPressed: onBackPressed,
                neonColor: neonColor,
              ),

              // Center: Avatar + Squad Name (tappable)
              Expanded(
                child: GestureDetector(
                  onTap: onCenterTapped,
                  behavior: HitTestBehavior.opaque,
                  child: _CenterAvatarStack(
                    squadId: squadId,
                    squadName: squadName,
                    avatarUrl: avatarUrl,
                    neonColor: neonColor,
                  ),
                ),
              ),

              // Right: Gamepad button (lobby creation) + Voice chat button
              if (onGamepadPressed != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _GlassCircleButton(
                    icon: Icons.gamepad,
                    onPressed: onGamepadPressed!,
                    neonColor: neonColor,
                  ),
                ),
              _GlassCircleButton(
                icon: Icons.headset,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VoiceRoomScreen(
                        roomId: squadId,
                        squadName: squadName,
                      ),
                    ),
                  );
                },
                neonColor: neonColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Glass circular button with neon glow
class _GlassCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color neonColor;

  const _GlassCircleButton({
    required this.icon,
    required this.onPressed,
    required this.neonColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.08),
        border: Border.all(
          color: neonColor.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: neonColor.neonGlow(
          blur: 12,
          opacity: 0.3,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Center(
            child: Icon(
              icon,
              color: neonColor,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

/// Center stack with overlapping avatar and squad name (iMessage style)
class _CenterAvatarStack extends StatelessWidget {
  final String squadId;
  final String squadName;
  final String? avatarUrl;
  final Color neonColor;

  const _CenterAvatarStack({
    required this.squadId,
    required this.squadName,
    this.avatarUrl,
    required this.neonColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // Squad name pill - positioned to touch bottom of avatar
        Positioned(
          top: 56, // Position at bottom of 56px avatar circle
          child: _GlassPill(
            squadName: squadName,
            neonColor: neonColor,
          ),
        ),

        // Avatar with Hero animation - solid with no glow border
        Positioned(
          top: 0,
          child: Hero(
            tag: 'squad_avatar_$squadId',
            child: CircleAvatar(
              radius: 28,
              backgroundImage:
                  avatarUrl != null ? NetworkImage(avatarUrl!) : null,
              backgroundColor: Colors.white.withOpacity(0.1),
              child: avatarUrl == null
                  ? Icon(
                      Icons.groups,
                      color: neonColor,
                      size: 24,
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}

/// Glass pill container for squad name
class _GlassPill extends StatelessWidget {
  final String squadName;
  final Color neonColor;

  const _GlassPill({
    required this.squadName,
    required this.neonColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: neonColor.withOpacity(0.3),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: neonColor.withOpacity(0.15),
                blurRadius: 8,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Text(
            squadName,
            style: GoogleFonts.orbitron(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: neonColor,
              letterSpacing: 0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

/// PreferredSize variant for use with regular Scaffold (non-sliver)
class NeonChatAppBarPreferred extends StatelessWidget
    implements PreferredSizeWidget {
  final String squadId;
  final String squadName;
  final String? avatarUrl;
  final VoidCallback onBackPressed;
  final VoidCallback? onCenterTapped;

  const NeonChatAppBarPreferred({
    super.key,
    required this.squadId,
    required this.squadName,
    this.avatarUrl,
    required this.onBackPressed,
    this.onCenterTapped,
  });

  @override
  Size get preferredSize => const Size.fromHeight(100);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final neonColor = theme.colorScheme.primary;

    return Container(
      height: preferredSize.height + MediaQuery.of(context).padding.top,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // Left: Back button in glass bubble
              _GlassCircleButton(
                icon: Icons.chevron_left,
                onPressed: onBackPressed,
                neonColor: neonColor,
              ),

              // Center: Avatar + Squad Name (tappable)
              Expanded(
                child: GestureDetector(
                  onTap: onCenterTapped,
                  behavior: HitTestBehavior.opaque,
                  child: _CenterAvatarStack(
                    squadId: squadId,
                    squadName: squadName,
                    avatarUrl: avatarUrl,
                    neonColor: neonColor,
                  ),
                ),
              ),

              // Right: Voice chat button in glass bubble
              _GlassCircleButton(
                icon: Icons.headset,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VoiceRoomScreen(
                        roomId: squadId,
                        squadName: squadName,
                      ),
                    ),
                  );
                },
                neonColor: neonColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
