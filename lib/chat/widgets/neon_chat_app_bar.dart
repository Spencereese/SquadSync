import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../screens/voice_room_screen.dart';

/// Custom iMessage-style app bar for ChatScreen with NEON VOID glass aesthetics
///
/// Features:
/// - Frosted glass background with blur
/// - Left: Back button in glass bubble
/// - Center: Tappable avatar + lobby name in overlapping layout
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
    final topPadding = MediaQuery.of(context).padding.top;

    return SizedBox(
      height: 120 + topPadding,
      child: Stack(
        children: [
          // Background layer with subtle shadow - NO blur effect
          // IgnorePointer allows content to scroll behind this layer
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.3),
                      Colors.black.withOpacity(0.15),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                ),
              ),
            ),
          ),
          // UI layer on top (not blurred) - positioned absolutely
          Positioned(
            top: topPadding + 8,
            left: 12,
            right: 12,
            child: SizedBox(
              height: 60,
              child: Stack(
                children: [
                  // Center: Avatar + Lobby Name
                  Center(
                    child: _CenterAvatarStack(
                      squadId: squadId,
                      squadName: squadName,
                      avatarUrl: avatarUrl,
                      neonColor: neonColor,
                      onCenterTapped: onCenterTapped,
                    ),
                  ),

                  // Left: Back button
                  Positioned(
                    left: 0,
                    top: 4,
                    child: _GlassCircleButton(
                      icon: Icons.chevron_left,
                      onPressed: onBackPressed,
                      neonColor: neonColor,
                    ),
                  ),

                  // Right: Gamepad + Voice buttons
                  Positioned(
                    right: 0,
                    top: 4,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (onGamepadPressed != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 10),
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
                ],
              ),
            ),
          ),
        ],
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        splashColor: neonColor.withOpacity(0.3),
        highlightColor: neonColor.withOpacity(0.1),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withOpacity(0.7),
            border: Border.all(
              color: neonColor.withOpacity(0.6),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: neonColor.withOpacity(0.4),
                blurRadius: 16,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              icon,
              color: neonColor,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}

/// Center stack with overlapping avatar and lobby name (iMessage style)
class _CenterAvatarStack extends StatelessWidget {
  final String squadId;
  final String squadName;
  final String? avatarUrl;
  final Color neonColor;
  final VoidCallback? onCenterTapped;

  const _CenterAvatarStack({
    required this.squadId,
    required this.squadName,
    this.avatarUrl,
    required this.neonColor,
    this.onCenterTapped,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88, // Total height for avatar + name overlap
      child: Stack(
        alignment: Alignment.topCenter, // Center horizontally, align to top
        clipBehavior: Clip.none,
        children: [
          // Avatar with Hero animation at top
          Positioned(
            top: 0,
            child: Hero(
              tag: 'squad_avatar_$squadId',
              child: GestureDetector(
                onTap: onCenterTapped,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: avatarUrl != null
                        ? Colors.transparent
                        : Colors.black.withOpacity(0.85),
                    border: Border.all(
                      color: neonColor.withOpacity(0.5),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: neonColor.withOpacity(0.3),
                        blurRadius: 12,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: avatarUrl != null
                      ? ClipOval(
                          child: Image.network(
                            avatarUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.groups,
                                color: neonColor,
                                size: 28,
                              );
                            },
                          ),
                        )
                      : Icon(
                          Icons.groups,
                          color: neonColor,
                          size: 28,
                        ),
                ),
              ),
            ),
          ),
          // Lobby name pill overlapping bottom of avatar
          Positioned(
            top: 50, // Start 6px before avatar bottom for overlap
            child: _GlassPill(
              squadName: squadName,
              neonColor: neonColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Glass pill container for lobby name
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
            color: Colors.black.withOpacity(0.65),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: neonColor.withOpacity(0.5),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: neonColor.withOpacity(0.3),
                blurRadius: 8,
                spreadRadius: 0,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 8,
                offset: const Offset(0, 2),
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

              // Center: Avatar + Lobby Name (tappable)
              Expanded(
                child: _CenterAvatarStack(
                  squadId: squadId,
                  squadName: squadName,
                  avatarUrl: avatarUrl,
                  neonColor: neonColor,
                  onCenterTapped: onCenterTapped,
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
