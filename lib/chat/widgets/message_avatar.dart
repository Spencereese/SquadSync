import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../squad_state.dart';

/// Message avatar component - displays user profile image or initials
class MessageAvatar extends StatelessWidget {
  final String senderName;
  final bool isFromCurrentUser;
  final VoidCallback? onTap;

  const MessageAvatar({
    super.key,
    required this.senderName,
    required this.isFromCurrentUser,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<SquadState>(
      builder: (context, squadState, child) {
        final profileImage = squadState.memberProfileImages[senderName];

        return GestureDetector(
          onTap: onTap ?? () => _showUserMenu(context, squadState, senderName),
          child: CircleAvatar(
            radius: 16,
            backgroundImage: profileImage != null && profileImage.isNotEmpty
                ? CachedNetworkImageProvider(_fixMediaUrl(profileImage))
                : null,
            child: profileImage == null || profileImage.isEmpty
                ? Text(
                    senderName.isNotEmpty ? senderName[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  )
                : null,
          ),
        );
      },
    );
  }

  void _showUserMenu(
      BuildContext context, SquadState squadState, String userName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _UserMenuSheet(
        userName: userName,
        squadState: squadState,
      ),
    );
  }

  String _fixMediaUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    return url.startsWith('http')
        ? url
        : 'https://storage.googleapis.com/squadsync-media/$url';
  }
}

class _UserMenuSheet extends StatelessWidget {
  final String userName;
  final SquadState squadState;

  const _UserMenuSheet({required this.userName, required this.squadState});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // User's name
          Text(
            userName,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          // Options
          _buildMenuItem(
            context,
            icon: Icons.videocam,
            label: 'Video Call',
            onTap: () {
              // TODO: Implement video call
              Navigator.pop(context);
            },
          ),
          _buildMenuItem(
            context,
            icon: Icons.call,
            label: 'Audio Call',
            onTap: () {
              // TODO: Implement audio call
              Navigator.pop(context);
            },
          ),
          _buildMenuItem(
            context,
            icon: Icons.message,
            label: 'Message',
            onTap: () {
              // TODO: Open 1-on-1 message
              Navigator.pop(context);
            },
          ),
          _buildMenuItem(
            context,
            icon: Icons.block,
            label: 'Ban',
            onTap: () {
              Navigator.pop(context);
              squadState.addBan(userName, squadState.displayName ?? 'Unknown');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$userName has been voted for ban')),
              );
            },
          ),
          _buildMenuItem(
            context,
            icon: Icons.person_off,
            label: 'Block User',
            onTap: () async {
              Navigator.pop(context);
              await squadState.blockUser(userName);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$userName has been blocked')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context,
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).primaryColor),
      title: Text(label),
      onTap: onTap,
    );
  }
}
