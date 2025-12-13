import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/notifiers/lobby_notifier.dart' as ln;
import '../../presentation/notifiers/user_notifier.dart';
import '../../services/supabase_service.dart';

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
    final squadAsync = ref.watch(ln.lobbyNotifierProvider);

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
        : 'https://storage.googleapis.com/lobbiesync-media/$url';
  }
}

class _UserMenuSheet extends ConsumerWidget {
  final String userName;

  const _UserMenuSheet({required this.userName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final squadAsync = ref.watch(ln.lobbyNotifierProvider);
    final userAsync = ref.watch(userNotifierProvider);

    return squadAsync.maybeWhen(
      data: (squadState) {
        final uid = squadState.memberDisplayNames.entries
            .firstWhere((e) => e.value == userName,
                orElse: () => const MapEntry('', ''))
            .key;

        if (uid.isEmpty) {
          return _buildErrorState(context);
        }

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Profile Header
                _buildProfileHeader(context, ref, uid, squadState),

                const Divider(height: 1),

                // Quick Actions
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                              .read(ln.lobbyNotifierProvider.notifier)
                              .addBan(uid, squadState.displayName);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content:
                                    Text('$userName has been voted for ban')),
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
                              .blockUser(uid);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('$userName has been blocked')),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
      orElse: () => _buildErrorState(context),
    );
  }

  Widget _buildProfileHeader(
    BuildContext context,
    WidgetRef ref,
    String uid,
    dynamic squadState,
  ) {
    final theme = Theme.of(context);
    final profileImage = squadState.memberProfileImages?[userName];
    final status = squadState.globalStatuses?[uid] ?? 'Offline';

    return FutureBuilder<Map<String, dynamic>?>(
      future: _fetchUserProfile(uid),
      builder: (context, snapshot) {
        final userProfile = snapshot.data;
        final bio = userProfile?['bio'] as String?;
        final pinnedGames = userProfile?['pinned_games'] as List<dynamic>?;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary.withOpacity(0.1),
                theme.cardColor,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            children: [
              // Avatar with glow
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: profileImage != null &&
                          profileImage.isNotEmpty
                      ? CachedNetworkImageProvider(_fixMediaUrl(profileImage))
                      : null,
                  child: profileImage == null || profileImage.isEmpty
                      ? Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 12),

              // User Name
              Text(
                userName,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Status Badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: status.toLowerCase().contains('online')
                      ? Colors.green.withOpacity(0.2)
                      : Colors.grey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: status.toLowerCase().contains('online')
                        ? Colors.green
                        : Colors.grey,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: status.toLowerCase().contains('online')
                            ? Colors.green
                            : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      status,
                      style: TextStyle(
                        color: status.toLowerCase().contains('online')
                            ? Colors.green
                            : Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              // Bio
              if (bio != null && bio.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  bio,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              // Pinned Games
              if (pinnedGames != null && pinnedGames.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Favorite Games',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: pinnedGames.take(3).map((game) {
                    final gameName = game is Map
                        ? (game['name'] ?? 'Unknown')
                        : game.toString();
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.colorScheme.primary.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        gameName,
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>?> _fetchUserProfile(String uid) async {
    try {
      final response = await SupabaseService.client
          .from('users')
          .select('bio, pinned_games')
          .eq('uid', uid)
          .maybeSingle();
      return response;
    } catch (e) {
      return null;
    }
  }

  Widget _buildErrorState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Unable to load user profile',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
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

  String _fixMediaUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    return url.startsWith('http')
        ? url
        : 'https://storage.googleapis.com/lobbiesync-media/$url';
  }
}
