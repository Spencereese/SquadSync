import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service_supabase.dart';

/// Bottom sheet menu for group chat context actions
class GroupChatContextMenu extends StatelessWidget {
  final String groupId;
  final String groupName;
  final String createdBy;
  final bool isMuted;
  final bool isPinned;
  final VoidCallback onMarkUnread;
  final VoidCallback onTogglePinned;
  final VoidCallback onToggleMute;
  final VoidCallback onIgnore;
  final VoidCallback onLeave;
  final VoidCallback? onDelete; // Only available if user created the group

  const GroupChatContextMenu({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.createdBy,
    required this.isMuted,
    required this.isPinned,
    required this.onMarkUnread,
    required this.onTogglePinned,
    required this.onToggleMute,
    required this.onIgnore,
    required this.onLeave,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final currentUser = AuthServiceSupabase().currentUser;
    final isCreator = currentUser?.id == createdBy;
    final theme = Theme.of(context);
    final neonColor = theme.colorScheme.primary;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(
              top: BorderSide(
                color: neonColor.withOpacity(0.3),
                width: 2,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Group name header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  groupName,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              Divider(
                color: neonColor.withOpacity(0.2),
                height: 1,
                indent: 16,
                endIndent: 16,
              ),

              const SizedBox(height: 8),

              // Menu options
              _buildMenuItem(
                context,
                icon: Icons.mark_chat_unread,
                label: 'Mark as Unread',
                color: theme.colorScheme.onSurface,
                neonColor: neonColor,
                onTap: () {
                  Navigator.pop(context);
                  onMarkUnread();
                },
              ),

              _buildMenuItem(
                context,
                icon: isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                label: isPinned ? 'Unpin' : 'Pin',
                color: theme.colorScheme.onSurface,
                neonColor: neonColor,
                onTap: () {
                  Navigator.pop(context);
                  onTogglePinned();
                },
              ),

              _buildMenuItem(
                context,
                icon: isMuted ? Icons.volume_up : Icons.volume_off,
                label: isMuted ? 'Unmute' : 'Mute',
                color: theme.colorScheme.onSurface,
                neonColor: neonColor,
                onTap: () {
                  Navigator.pop(context);
                  onToggleMute();
                },
              ),

              _buildMenuItem(
                context,
                icon: Icons.visibility_off,
                label: 'Ignore',
                color: theme.colorScheme.onSurface,
                neonColor: neonColor,
                onTap: () {
                  Navigator.pop(context);
                  _showConfirmDialog(
                    context,
                    'Ignore Chat',
                    'Are you sure you want to ignore "$groupName"? You won\'t receive notifications.',
                    onIgnore,
                  );
                },
              ),

              Divider(
                color: neonColor.withOpacity(0.1),
                height: 1,
                indent: 16,
                endIndent: 16,
              ),

              _buildMenuItem(
                context,
                icon: Icons.exit_to_app,
                label: 'Leave Chat',
                color: Colors.red[400]!,
                neonColor: Colors.red[400]!,
                onTap: () {
                  Navigator.pop(context);
                  _showConfirmDialog(
                    context,
                    'Leave Chat',
                    'Are you sure you want to leave "$groupName"?',
                    onLeave,
                  );
                },
              ),

              if (isCreator && onDelete != null) ...[
                Divider(
                  color: neonColor.withOpacity(0.1),
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.delete_forever,
                  label: 'Delete Chat',
                  color: Colors.red[700]!,
                  neonColor: Colors.red[700]!,
                  onTap: () {
                    Navigator.pop(context);
                    _showConfirmDialog(
                      context,
                      'Delete Chat',
                      'Are you sure you want to permanently delete "$groupName"? This cannot be undone.',
                      onDelete!,
                      isDestructive: true,
                    );
                  },
                ),
              ],

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required Color neonColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.15),
                  border: Border.all(
                    color: color.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showConfirmDialog(
    BuildContext context,
    String title,
    String message,
    VoidCallback onConfirm, {
    bool isDestructive = false,
  }) {
    final theme = Theme.of(context);
    final neonColor = theme.colorScheme.primary;

    showDialog(
      context: context,
      builder: (dialogContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: theme.colorScheme.surface.withOpacity(0.95),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isDestructive
                  ? Colors.red.withOpacity(0.5)
                  : neonColor.withOpacity(0.3),
              width: 2,
            ),
          ),
          title: Text(
            title,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              color:
                  isDestructive ? Colors.red[400] : theme.colorScheme.onSurface,
            ),
          ),
          content: Text(
            message,
            style: GoogleFonts.inter(
              color: theme.colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                onConfirm();
              },
              style: TextButton.styleFrom(
                backgroundColor: isDestructive
                    ? Colors.red.withOpacity(0.2)
                    : neonColor.withOpacity(0.2),
              ),
              child: Text(
                isDestructive ? 'Delete' : 'Confirm',
                style: GoogleFonts.inter(
                  color: isDestructive ? Colors.red[400] : neonColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
