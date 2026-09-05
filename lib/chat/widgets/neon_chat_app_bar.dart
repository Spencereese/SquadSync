import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/voice_room_join.dart';

/// Compact Load / Pending chip for the ChatScreen header.
enum ChatHeaderStatus { idle, loading, pending }

/// Custom iMessage-style app bar for ChatScreen with NEON VOID glass aesthetics
///
/// Features:
/// - Frosted glass background with blur
/// - Left: Back button in glass bubble
/// - Center: Tappable avatar + lobby name in overlapping layout
/// - Right: optional Load/Pending chip + Gamepad + Voice chat in glass bubbles
/// - Hero animation support for avatar transitions
class NeonChatAppBar extends StatelessWidget {
  static const double contentHeight = 120;

  final String squadId;
  final String squadName;
  final String? avatarUrl;
  final VoidCallback onBackPressed;
  final VoidCallback? onCenterTapped;
  final VoidCallback? onGamepadPressed;
  final bool showGamepadBadge;
  final Color? backgroundColor;
  final bool hideBackButton;
  final bool hideVoiceButton;
  final ChatHeaderStatus headerStatus;

  const NeonChatAppBar({
    super.key,
    required this.squadId,
    required this.squadName,
    this.avatarUrl,
    required this.onBackPressed,
    this.onCenterTapped,
    this.onGamepadPressed,
    this.showGamepadBadge = false,
    this.backgroundColor,
    this.hideBackButton = false,
    this.hideVoiceButton = false,
    this.headerStatus = ChatHeaderStatus.idle,
  });

  static double heightFor(BuildContext context) =>
      contentHeight + MediaQuery.paddingOf(context).top;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const neonColor = Colors.white;
    final topPadding = MediaQuery.of(context).padding.top;

    return SizedBox(
      height: contentHeight + topPadding,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // UI layer - positioned absolutely
          Positioned(
            top: topPadding + 8,
            left: 12,
            right: 12,
            child: SizedBox(
              height: 60,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Center: Avatar + Lobby Name
                  Center(
                    child: _CenterAvatarStack(
                      squadId: squadId,
                      squadName: squadName,
                      avatarUrl: avatarUrl,
                      neonColor: neonColor,
                      onCenterTapped: onCenterTapped,
                      backgroundColor: backgroundColor,
                    ),
                  ),

                  // Left: Back button
                  if (!hideBackButton)
                    Positioned(
                      left: 0,
                      top: 4,
                      child: _GlassCircleButton(
                        icon: Icons.chevron_left,
                        onPressed: onBackPressed,
                        neonColor: neonColor,
                        backgroundColor: backgroundColor,
                      ),
                    ),

                  // Right: Load/Pending chip + Gamepad + Voice
                  Positioned(
                    right: 0,
                    top: 4,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (headerStatus != ChatHeaderStatus.idle) ...[
                          ChatHeaderStatusChip(
                            status: headerStatus,
                            backgroundColor: backgroundColor,
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (onGamepadPressed != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                _GlassCircleButton(
                                  icon: Icons.gamepad,
                                  onPressed: onGamepadPressed!,
                                  neonColor: neonColor,
                                  backgroundColor: backgroundColor,
                                ),
                                if (showGamepadBadge)
                                  Positioned(
                                    right: -2,
                                    top: -2,
                                    child: Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.error,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.black,
                                          width: 1.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: theme.colorScheme.error,
                                            blurRadius: 8,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        if (!hideVoiceButton)
                          _GlassCircleButton(
                            icon: Icons.headset,
                            onPressed: () {
                              openVoiceRoom(
                                context: context,
                                roomId: squadId,
                                squadName: squadName,
                              );
                            },
                            neonColor: neonColor,
                            backgroundColor: backgroundColor,
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

/// Single-line Load / Pending chip. Does not wrap or stack over header buttons.
class ChatHeaderStatusChip extends StatelessWidget {
  final ChatHeaderStatus status;
  final Color? backgroundColor;

  const ChatHeaderStatusChip({
    super.key,
    required this.status,
    this.backgroundColor,
  });

  bool get _isLight {
    return (backgroundColor?.computeLuminance() ?? 0.0) > 0.5;
  }

  @override
  Widget build(BuildContext context) {
    if (status == ChatHeaderStatus.idle) {
      return const SizedBox.shrink();
    }
    final loading = status == ChatHeaderStatus.loading;
    final label = loading ? 'Load' : 'Pending';
    final fg = _isLight ? Colors.black87 : Colors.white;
    return Semantics(
      label: loading ? 'Loading' : 'Pending',
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 88,
          minHeight: 28,
          maxHeight: 32,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _isLight
                    ? Colors.black.withOpacity(0.4)
                    : Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isLight
                      ? Colors.black.withOpacity(0.5)
                      : Colors.white.withOpacity(0.2),
                  width: _isLight ? 1.0 : 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (loading) ...[
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.6,
                        color: fg,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: fg,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
  final Color? backgroundColor;

  const _GlassCircleButton({
    required this.icon,
    required this.onPressed,
    required this.neonColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            splashColor: Colors.white.withOpacity(0.1),
            highlightColor: Colors.white.withOpacity(0.05),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _getGlassColor(),
                border: Border.all(
                  color: _getBorderColor(),
                  width: _isLightBackground() ? 1.0 : 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _isLightBackground()
                        ? Colors.black.withOpacity(0.3)
                        : Colors.black.withOpacity(0.15),
                    blurRadius: _isLightBackground() ? 12 : 6,
                    offset: Offset(0, _isLightBackground() ? 6 : 3),
                    spreadRadius: _isLightBackground() ? 2 : 0,
                  ),
                  if (_isLightBackground())
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                ],
              ),
              child: Center(
                child: Icon(
                  icon,
                  color: _isLightBackground() ? Colors.black87 : Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _isLightBackground() {
    final bgLuminance = backgroundColor?.computeLuminance() ?? 0.0;
    return bgLuminance > 0.5;
  }

  Color _getGlassColor() {
    return _isLightBackground()
        ? Colors.black.withOpacity(0.4)
        : Colors.white.withOpacity(0.15);
  }

  Color _getBorderColor() {
    return _isLightBackground()
        ? Colors.black.withOpacity(0.5)
        : Colors.white.withOpacity(0.2);
  }
}

/// Center stack with overlapping avatar and lobby name (iMessage style)
class _CenterAvatarStack extends StatelessWidget {
  final String squadId;
  final String squadName;
  final String? avatarUrl;
  final Color neonColor;
  final VoidCallback? onCenterTapped;
  final Color? backgroundColor;

  const _CenterAvatarStack({
    required this.squadId,
    required this.squadName,
    this.avatarUrl,
    required this.neonColor,
    this.onCenterTapped,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onCenterTapped,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height:
            94, // Total height for avatar + name overlap (increased for larger avatar)
        child: Stack(
          alignment: Alignment.topCenter, // Center horizontally, align to top
          clipBehavior: Clip.none,
          children: [
            // Lobby name pill - render first so avatar layers on top
            Positioned(
              top:
                  62, // Start 6px before avatar bottom for overlap (adjusted for larger avatar)
              child: _GlassPill(
                squadName: squadName,
                neonColor: neonColor,
                backgroundColor: backgroundColor,
              ),
            ),
            // Avatar with Hero animation at top - render second to layer above name
            Positioned(
              top: 0,
              child: Hero(
                tag: 'squad_avatar_$squadId',
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: avatarUrl != null
                        ? Colors.transparent
                        : Colors.black.withOpacity(0.85),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.1),
                        blurRadius: 12,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: avatarUrl != null && avatarUrl!.isNotEmpty
                      ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: avatarUrl!,
                            fit: BoxFit.cover,
                            memCacheWidth: 200, // Optimize memory usage
                            memCacheHeight: 200,
                            fadeInDuration: const Duration(milliseconds: 100),
                            placeholder: (context, url) => Icon(
                              Icons.groups,
                              color: neonColor.withOpacity(0.5),
                              size: 34,
                            ),
                            errorWidget: (context, url, error) => Icon(
                              Icons.groups,
                              color: neonColor,
                              size: 34,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.groups,
                          color: neonColor,
                          size: 34,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Glass pill container for lobby name
class _GlassPill extends StatelessWidget {
  final String squadName;
  final Color neonColor;
  final Color? backgroundColor;

  const _GlassPill({
    required this.squadName,
    required this.neonColor,
    this.backgroundColor,
  });

  bool _isLightBackground() {
    final bgLuminance = backgroundColor?.computeLuminance() ?? 0.0;
    return bgLuminance > 0.5;
  }

  Color _getGlassColor() {
    return _isLightBackground()
        ? Colors.black.withOpacity(0.4)
        : Colors.white.withOpacity(0.15);
  }

  Color _getBorderColor() {
    return _isLightBackground()
        ? Colors.black.withOpacity(0.5)
        : Colors.white.withOpacity(0.2);
  }

  Color _getTextColor() {
    return _isLightBackground() ? Colors.black87 : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _getGlassColor(),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _getBorderColor(),
              width: _isLightBackground() ? 1.0 : 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _isLightBackground()
                    ? Colors.black.withOpacity(0.3)
                    : Colors.black.withOpacity(0.15),
                blurRadius: _isLightBackground() ? 12 : 6,
                offset: Offset(0, _isLightBackground() ? 6 : 3),
                spreadRadius: _isLightBackground() ? 2 : 0,
              ),
              if (_isLightBackground())
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
            ],
          ),
          child: Text(
            squadName,
            style: GoogleFonts.orbitron(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _getTextColor(),
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
    const neonColor = Colors.white;

    return SizedBox(
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
                  openVoiceRoom(
                    context: context,
                    roomId: squadId,
                    squadName: squadName,
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
