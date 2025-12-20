import 'package:flutter/material.dart';
import '../../../screens/voice_room_screen.dart';
import '../../../screens/video_room_screen.dart';
import 'chat_info_widgets.dart';
import '../../../services/auth_service_supabase.dart';
import '../../../services/friends_service.dart';
import '../../../notification_service.dart';

/// Actions section with big circular buttons for squad actions
///
/// Features:
/// - Voice chat navigation
/// - Video chat navigation (with beta badge)
/// - Search functionality
/// - Glassmorphic button design
class ChatInfoActionsSection extends StatelessWidget {
  final String squadId;
  final String squadName;
  final Color neonColor;

  const ChatInfoActionsSection({
    super.key,
    required this.squadId,
    required this.squadName,
    required this.neonColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ChatInfoBigActionButton(
                icon: Icons.headset,
                label: 'Voice Chat',
                neonColor: neonColor,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VoiceRoomScreen(
                        roomId: squadId,
                        squadName: squadName,
                      ),
                    ),
                  );
                },
              ),
              ChatInfoBigActionButton(
                icon: Icons.video_call,
                label: 'Video Chat',
                neonColor: neonColor,
                badge: 'Beta',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VideoRoomScreen(
                        roomId: squadId,
                        roomName: squadName,
                      ),
                    ),
                  );
                },
              ),
              ChatInfoBigActionButton(
                icon: Icons.search,
                label: 'Search',
                neonColor: neonColor,
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Search feature coming soon!'),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _LookingForSquadButton(
          squadId: squadId,
          neonColor: neonColor,
        ),
      ],
    );
  }
}

/// Looking for Squad button - alerts all friends across all groups
class _LookingForSquadButton extends StatefulWidget {
  final String squadId;
  final Color neonColor;

  const _LookingForSquadButton({
    required this.squadId,
    required this.neonColor,
  });

  @override
  State<_LookingForSquadButton> createState() => _LookingForSquadButtonState();
}

class _LookingForSquadButtonState extends State<_LookingForSquadButton> {
  bool _isLookingForSquad = false;
  bool _isLoading = false;

  Future<void> _toggleLookingForSquad() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = AuthServiceSupabase().currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      if (!_isLookingForSquad) {
        // Send notifications to all friends
        final friendsService = FriendsService();
        final friends = await friendsService.getFriendsWithDetails(user.id);

        if (friends.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No friends to notify'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          setState(() {
            _isLoading = false;
          });
          return;
        }

        // Extract friend UIDs
        final friendUids = friends
            .map((f) => f['friend']?['uid'] as String?)
            .where((uid) => uid != null)
            .cast<String>()
            .toList();

        // Send push notifications to all friends
        await NotificationService.sendNotificationToUsers(
          title: '🎮 Friend Looking for Squad!',
          body: 'Your friend is looking for a squad to play with!',
          recipientUids: friendUids,
          data: {
            'type': 'lfg_alert',
            'from_uid': user.id,
            'squad_id': widget.squadId,
          },
        );

        setState(() {
          _isLookingForSquad = true;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🎮 ${friendUids.length} friends notified!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Cancel looking for squad
        setState(() {
          _isLookingForSquad = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No longer looking for squad'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send notifications: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonColor = _isLookingForSquad
        ? Colors.orange
        : (widget.neonColor == Colors.white ||
                widget.neonColor.computeLuminance() > 0.8
            ? theme.colorScheme
                .primary // Use theme primary if neonColor is too light
            : widget.neonColor);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _isLoading ? null : _toggleLookingForSquad,
          icon: _isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.onPrimary,
                  ),
                )
              : Icon(
                  _isLookingForSquad
                      ? Icons.notifications_off
                      : Icons.notifications_active,
                  size: 20,
                  color: Colors.black,
                ),
          label: Text(
            _isLookingForSquad
                ? 'Cancel Looking for Squad'
                : 'Looking for Squad',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: buttonColor,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 4,
            shadowColor: buttonColor.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}
