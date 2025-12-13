import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'chat_info_widgets.dart';

/// Custom glassmorphic app bar for chat info screen
///
/// Features:
/// - Glassmorphic background with backdrop blur
/// - Hero animated squad avatar
/// - Lobby name with Orbitron font
/// - Back and edit buttons
class ChatInfoAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String squadId;
  final String squadName;
  final String? avatarUrl;
  final Color neonColor;
  final VoidCallback onEditPressed;

  const ChatInfoAppBar({
    super.key,
    required this.squadId,
    required this.squadName,
    this.avatarUrl,
    required this.neonColor,
    required this.onEditPressed,
  });

  @override
  Size get preferredSize => const Size.fromHeight(160);

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            border: Border(
              bottom: BorderSide(
                color: neonColor.withOpacity(0.2),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            child: Row(
              children: [
                // Left: Back button
                ChatInfoGlassCircleButton(
                  icon: Icons.chevron_left,
                  onPressed: () => Navigator.pop(context),
                  neonColor: neonColor,
                ),

                // Center: Avatar + Lobby Name
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Hero avatar
                      Hero(
                        tag: 'squad_avatar_$squadId',
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: neonColor.withOpacity(0.5),
                              width: 2.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: neonColor.withOpacity(0.5),
                                blurRadius: 20,
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 38,
                            backgroundImage: avatarUrl != null
                                ? NetworkImage(avatarUrl!)
                                : null,
                            backgroundColor: Colors.white.withOpacity(0.1),
                            child: avatarUrl == null
                                ? Icon(
                                    Icons.groups,
                                    color: neonColor,
                                    size: 40,
                                  )
                                : null,
                          ),
                        ),
                      )
                          .animate()
                          .scale(duration: 500.ms, curve: Curves.easeOut),
                      const SizedBox(height: 8),
                      // Lobby name
                      Text(
                        squadName,
                        style: GoogleFonts.orbitron(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: neonColor,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
                    ],
                  ),
                ),

                // Right: Edit button
                ChatInfoGlassCircleButton(
                  icon: Icons.edit,
                  onPressed: onEditPressed,
                  neonColor: neonColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
