import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Bottom sheet menu for lobby context actions
class LobbyContextMenu extends StatelessWidget {
  final String chatGroupId;
  final String chatGroupName;
  final int activeLobbyCount;
  final VoidCallback onCreateLobby;
  final VoidCallback? onViewActiveLobbies;

  const LobbyContextMenu({
    super.key,
    required this.chatGroupId,
    required this.chatGroupName,
    required this.activeLobbyCount,
    required this.onCreateLobby,
    this.onViewActiveLobbies,
  });

  @override
  Widget build(BuildContext context) {
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

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              'Lobby Options',
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
            icon: Icons.add_circle_outline,
            label: 'Create Lobby',
            subtitle: 'Start a new gaming session',
            color: Colors.cyanAccent,
            onTap: () {
              Navigator.pop(context);
              onCreateLobby();
            },
          ),

          if (activeLobbyCount > 0 && onViewActiveLobbies != null)
            _buildMenuItem(
              context,
              icon: Icons.people_outline,
              label: 'View Active Lobbies',
              subtitle:
                  '$activeLobbyCount ${activeLobbyCount == 1 ? 'lobby' : 'lobbies'} active',
              color: Colors.greenAccent,
              onTap: () {
                Navigator.pop(context);
                onViewActiveLobbies?.call();
              },
            ),

          _buildMenuItem(
            context,
            icon: Icons.info_outline,
            label: 'Lobby Info',
            subtitle: 'View lobby rules & constitution',
            color: Colors.blueAccent,
            onTap: () {
              Navigator.pop(context);
              _showLobbyInfo(context);
            },
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    String? subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 13,
              ),
            )
          : null,
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
    );
  }

  void _showLobbyInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Lobby System',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(
              'Constitution',
              'Rules auto-apply to new lobbies',
              Icons.gavel,
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              'Spot Timers',
              'Claim spots before time expires',
              Icons.timer,
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              'Visibility',
              'Private, friends-only, or public',
              Icons.visibility,
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              'Tags',
              'Add tags to help others find your lobby',
              Icons.label,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Got it',
              style: TextStyle(color: Colors.cyanAccent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String title, String description, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: Colors.cyanAccent,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
