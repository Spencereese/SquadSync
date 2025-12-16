import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/notifiers/lobby_notifier.dart' as ln;
import '../../presentation/notifiers/user_notifier.dart';
import '../../services/voice_service.dart';
import '../../services/auth_service_supabase.dart';
import '../../domain/entities/message.dart' show ChatType;
import '../chat_screen.dart';

/// Message avatar component - displays user profile image or initials
class MessageAvatar extends ConsumerWidget {
  final String senderName;
  final String senderUid;
  final bool isFromCurrentUser;
  final VoidCallback? onTap;

  const MessageAvatar({
    super.key,
    required this.senderName,
    required this.senderUid,
    required this.isFromCurrentUser,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final squadAsync = ref.watch(ln.lobbyNotifierProvider);

    return squadAsync.maybeWhen(
      data: (squadState) {
        // Use senderUid to look up profile image (memberProfileImages is keyed by UID)
        final profileImage = squadState.memberProfileImages?[senderUid];

        return GestureDetector(
          onTap:
              onTap ?? () => _showUserMenu(context, ref, senderName, senderUid),
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

  void _showUserMenu(
      BuildContext context, WidgetRef ref, String userName, String userUid) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _UserMenuSheet(
        userName: userName,
        userUid: userUid,
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
  final String userUid;

  const _UserMenuSheet({required this.userName, required this.userUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final squadAsync = ref.watch(ln.lobbyNotifierProvider);

    return squadAsync.maybeWhen(
      data: (squadState) {
        final uid = userUid;

        if (uid.isEmpty) {
          return _buildErrorState(context);
        }

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

              // User name header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  userName,
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
                icon: Icons.videocam,
                label: 'Video Call',
                color: Colors.green,
                onTap: () async {
                  Navigator.pop(context);
                  await _startVideoCall(context, ref, uid, userName);
                },
              ),
              _buildMenuItem(
                context,
                icon: Icons.call,
                label: 'Audio Call',
                color: Colors.blue,
                onTap: () async {
                  Navigator.pop(context);
                  await _startAudioCall(context, ref, uid, userName);
                },
              ),
              _buildMenuItem(
                context,
                icon: Icons.message,
                label: 'Message',
                color: Colors.cyanAccent,
                onTap: () async {
                  Navigator.pop(context);
                  await _openDirectMessage(context, ref, uid, userName);
                },
              ),
              _buildMenuItem(
                context,
                icon: Icons.sports_martial_arts,
                label: 'Ban',
                color: Colors.orange,
                onTap: () {
                  Navigator.pop(context);
                  ref
                      .read(ln.lobbyNotifierProvider.notifier)
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
                color: Colors.red,
                onTap: () async {
                  Navigator.pop(context);
                  await ref.read(userNotifierProvider.notifier).blockUser(uid);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$userName has been blocked')),
                    );
                  }
                },
              ),

              const SizedBox(height: 20),
            ],
          ),
        );
      },
      orElse: () => _buildErrorState(context),
    );
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
      required Color color,
      required VoidCallback onTap}) {
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

  /// Start a video call with the user
  Future<void> _startVideoCall(BuildContext context, WidgetRef ref,
      String targetUid, String targetName) async {
    try {
      final voiceService = ref.read(voiceServiceProvider);
      final currentUser = AuthServiceSupabase().currentUser;

      if (currentUser == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('You must be logged in to make calls')),
          );
        }
        return;
      }

      // Generate unique channel name for 1-on-1 call
      final users = [currentUser.id, targetUid]..sort();
      final channelName = 'video_${users[0]}_${users[1]}';

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Starting video call with $targetName...')),
        );
      }

      // Initialize and join voice channel
      final initResult = await voiceService.initializeEngine(context: context);
      if (!initResult.isSuccess) {
        throw Exception(
            initResult.errorMessage ?? 'Failed to initialize voice service');
      }

      final joinResult = await voiceService.joinChannel(channelName);
      if (!joinResult.isSuccess) {
        throw Exception(joinResult.errorMessage ?? 'Failed to join call');
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Video call with $targetName started'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start video call: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Start an audio call with the user
  Future<void> _startAudioCall(BuildContext context, WidgetRef ref,
      String targetUid, String targetName) async {
    try {
      final voiceService = ref.read(voiceServiceProvider);
      final currentUser = AuthServiceSupabase().currentUser;

      if (currentUser == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('You must be logged in to make calls')),
          );
        }
        return;
      }

      // Generate unique channel name for 1-on-1 call
      final users = [currentUser.id, targetUid]..sort();
      final channelName = 'audio_${users[0]}_${users[1]}';

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Starting audio call with $targetName...')),
        );
      }

      // Initialize and join voice channel
      final initResult = await voiceService.initializeEngine(context: context);
      if (!initResult.isSuccess) {
        throw Exception(
            initResult.errorMessage ?? 'Failed to initialize voice service');
      }

      final joinResult = await voiceService.joinChannel(channelName);
      if (!joinResult.isSuccess) {
        throw Exception(joinResult.errorMessage ?? 'Failed to join call');
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Audio call with $targetName started'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start audio call: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Open direct message with the user
  Future<void> _openDirectMessage(BuildContext context, WidgetRef ref,
      String targetUid, String targetName) async {
    try {
      final currentUser = AuthServiceSupabase().currentUser;

      if (currentUser == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('You must be logged in to send messages')),
          );
        }
        return;
      }

      // Show loading indicator
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opening conversation...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      // Start DM thread (creates chat group if needed)
      final dmId = await ref
          .read(userNotifierProvider.notifier)
          .startDMThread(targetUid);

      if (dmId == null) {
        throw Exception('Failed to create DM thread');
      }

      // Navigate to chat screen
      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatGroupId: dmId,
              chatGroupName: targetName,
              chatType: ChatType.dm,
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open message: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
