import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/notifiers/squad_notifier.dart';
import '../../presentation/notifiers/user_notifier.dart';

/// Message avatar component - displays user profile image or initials
class MessageAvatar extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final squadAsync = ref.watch(squadNotifierProvider);

    return squadAsync.maybeWhen(
      data: (squadState) {
        final profileImage = squadState.memberProfileImages?[senderName];

        return GestureDetector(
          onTap: onTap ?? () => _showUserMenu(context, ref, senderName),
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
      orElse: () => CircleAvatar(
        radius: 16,
        child: Text(
          senderName.isNotEmpty ? senderName[0].toUpperCase() : '?',
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ),
    );
  }

  void _showUserMenu(BuildContext context, WidgetRef ref, String userName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _UserMenuSheet(
        userName: userName,
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

class _UserMenuSheet extends ConsumerWidget {
  final String userName;

  const _UserMenuSheet({required this.userName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final squadAsync = ref.watch(squadNotifierProvider);

    return squadAsync.maybeWhen(
      data: (squadState) {
        final uid = squadState.memberDisplayNames.entries
            .firstWhere((e) => e.value == userName,
                orElse: () => const MapEntry('', ''))
            .key;

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
                icon: Icons.gavel,
                label: 'Ban',
                onTap: () {
                  Navigator.pop(context);
                  ref
                      .read(squadNotifierProvider.notifier)
                      .addBan(uid, squadState.displayName);
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
                  await ref
                      .read(userNotifierProvider.notifier)
                      .blockUser(userName);
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
      },
      orElse: () => const SizedBox.shrink(),
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
