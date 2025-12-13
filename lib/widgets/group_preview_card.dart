import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../domain/entities/chat_group.dart';

/// Card widget for displaying public group previews in the Discover tab
///
/// Features:
/// - ChatGroup Freezed entity support
/// - Member count or game icon display
/// - Orbitron font for titles
/// - Animated reveal with flutter_animate
/// - Glassmorphic design with neon accents
/// - Haptic feedback on join
class GroupPreviewCard extends StatelessWidget {
  final ChatGroup group;
  final VoidCallback onJoin;

  const GroupPreviewCard({
    super.key,
    required this.group,
    required this.onJoin,
  });

  String _formatTimeAgo(DateTime? dateTime) {
    if (dateTime == null) return 'Never';

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  String? _extractGameName() {
    // Try to extract game name from metadata or description
    final metadata = group.metadata;
    if (metadata != null && metadata.containsKey('game_name')) {
      return metadata['game_name'] as String?;
    }
    return null;
  }

  String _getMaskedInviteCode() {
    final inviteCode = group.id; // Using group ID as invite code
    if (inviteCode.isEmpty) return '****';

    // Show last 4 characters
    if (inviteCode.length >= 4) {
      return inviteCode.substring(inviteCode.length - 4);
    }
    return inviteCode;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final gameName = _extractGameName();

    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: Container(
            color: Colors.white.withOpacity(0.1),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),

              // Leading: Member count or game icon
              leading: CircleAvatar(
                backgroundColor: colorScheme.primary.withOpacity(0.2),
                radius: 24,
                child: gameName != null
                    ? Icon(
                        Icons.sports_esports,
                        color: colorScheme.primary,
                        size: 24,
                      )
                    : Text(
                        '${group.memberCount}',
                        style: GoogleFonts.orbitron(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                          fontSize: 16,
                        ),
                      ),
              ),

              // Title: Group name with Orbitron font
              title: Text(
                group.name,
                style: GoogleFonts.orbitron(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 16,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              // Subtitle: Public status, game name, activity, and invite code
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    'Public • ${gameName ?? 'General'}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Active: ${_formatTimeAgo(group.lastActivity)}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Invite: ...${_getMaskedInviteCode()}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),

              // Trailing: Join button with neon glow
              trailing: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withOpacity(0.5),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    onJoin();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Join',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ).animate().slideY(
          duration: const Duration(milliseconds: 300),
          begin: 0.2,
          curve: Curves.easeOut,
        );
  }
}
