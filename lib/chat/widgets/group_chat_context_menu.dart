import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
              color: Colors.grey[700],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Group name header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              groupName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const Divider(color: Colors.grey, height: 1),

          // Menu options
          _buildMenuItem(
            context,
            icon: Icons.mark_chat_unread,
            label: 'Mark as Unread',
            color: Colors.white,
            onTap: () {
              Navigator.pop(context);
              onMarkUnread();
            },
          ),

          _buildMenuItem(
            context,
            icon: isPinned ? Icons.push_pin : Icons.push_pin_outlined,
            label: isPinned ? 'Unpin' : 'Pin',
            color: Colors.white,
            onTap: () {
              Navigator.pop(context);
              onTogglePinned();
            },
          ),

          _buildMenuItem(
            context,
            icon: isMuted ? Icons.volume_up : Icons.volume_off,
            label: isMuted ? 'Unmute' : 'Mute',
            color: Colors.white,
            onTap: () {
              Navigator.pop(context);
              onToggleMute();
            },
          ),

          _buildMenuItem(
            context,
            icon: Icons.visibility_off,
            label: 'Ignore',
            color: Colors.white,
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

          _buildMenuItem(
            context,
            icon: Icons.exit_to_app,
            label: 'Leave Chat',
            color: Colors.red,
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
            const Divider(color: Colors.grey, height: 1),
            _buildMenuItem(
              context,
              icon: Icons.delete_forever,
              label: 'Delete Chat',
              color: Colors.red[700]!,
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
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
      ),
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
    );
  }

  void _showConfirmDialog(
    BuildContext context,
    String title,
    String message,
    VoidCallback onConfirm, {
    bool isDestructive = false,
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          title,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              onConfirm();
            },
            child: Text(
              isDestructive ? 'Delete' : 'Confirm',
              style: TextStyle(
                color: isDestructive ? Colors.red : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
