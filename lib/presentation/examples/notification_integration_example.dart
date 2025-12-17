import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../notifiers/notification_notifier.dart';
import '../widgets/notification_badge.dart';
import '../../data/services/live_activity_manager.dart';

/// Example integration of notification system into SquadSync main navigation
/// Shows how to use badges, clear notifications, and handle momentum
class NotificationIntegrationExample extends ConsumerWidget {
  const NotificationIntegrationExample({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SquadSync'),
        actions: [
          // Notifications icon with badge
          NotificationBadge(
            badgeType: 'invites',
            child: IconButton(
              icon: const Icon(Icons.notifications),
              onPressed: () => _openNotifications(context, ref),
            ),
          ),
        ],
      ),
      body: const Center(child: Text('Your content here')),
      bottomNavigationBar: _buildBottomNav(context, ref),
    );
  }

  /// Bottom navigation with badges on each tab
  Widget _buildBottomNav(BuildContext context, WidgetRef ref) {
    return BottomNavigationBar(
      items: [
        // Lobby tab with momentum badge
        BottomNavigationBarItem(
          icon: MomentumBadge(
            child: NotificationBadge(
              badgeType: 'lobby',
              child: const Icon(Icons.groups),
            ),
          ),
          label: 'Lobbies',
        ),

        // Chat tab with unread badge
        BottomNavigationBarItem(
          icon: NotificationBadge(
            badgeType: 'chat',
            child: const Icon(Icons.chat),
          ),
          label: 'Chat',
        ),

        // Profile tab
        const BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
      onTap: (index) => _handleNavTap(index, ref),
    );
  }

  void _handleNavTap(int index, WidgetRef ref) {
    // Clear badge when entering corresponding screen
    final notifier = ref.read(notificationNotifierProvider.notifier);

    switch (index) {
      case 0: // Lobby tab
        notifier.clearBadge('lobby');
        break;
      case 1: // Chat tab
        notifier.clearBadge('chat');
        break;
    }
  }

  void _openNotifications(BuildContext context, WidgetRef ref) {
    // Clear invites badge when opening notifications
    ref.read(notificationNotifierProvider.notifier).clearBadge('invites');

    // Navigate to notifications screen
    // Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationsScreen()));
  }
}

/// Example: Manually send direct invite from lobby screen
class LobbyInviteExample extends ConsumerWidget {
  final String lobbyId;
  final String gameName;
  final String? gameImageUrl;

  const LobbyInviteExample({
    super.key,
    required this.lobbyId,
    required this.gameName,
    this.gameImageUrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.person_add),
      label: const Text('Invite Friend'),
      onPressed: () => _inviteFriend(context, ref),
    );
  }

  Future<void> _inviteFriend(BuildContext context, WidgetRef ref) async {
    // Show friend picker dialog
    final friendId = await _showFriendPicker(context);

    if (friendId == null) return;

    // Send direct invite notification
    final notifier = ref.read(notificationNotifierProvider.notifier);

    await notifier.sendDirectInvite(
      recipientId: friendId,
      inviterName: 'You', // Replace with actual current user name
      lobbyId: lobbyId,
      gameName: gameName,
      gameImageUrl: gameImageUrl,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invite sent!')),
      );
    }
  }

  Future<String?> _showFriendPicker(BuildContext context) async {
    // TODO: Implement friend picker dialog
    return null;
  }
}

/// Example: iOS Live Activities integration for favorite groups
class LiveActivityExample extends ConsumerStatefulWidget {
  final String lobbyId;
  final String gameName;
  final List<String> participantNames;

  const LiveActivityExample({
    super.key,
    required this.lobbyId,
    required this.gameName,
    required this.participantNames,
  });

  @override
  ConsumerState<LiveActivityExample> createState() =>
      _LiveActivityExampleState();
}

class _LiveActivityExampleState extends ConsumerState<LiveActivityExample> {
  String? _activityId;

  @override
  void initState() {
    super.initState();
    _startLiveActivity();
  }

  @override
  void dispose() {
    _endLiveActivity();
    super.dispose();
  }

  Future<void> _startLiveActivity() async {
    final liveActivityManager = LiveActivityManager();

    final isSupported = await liveActivityManager.isSupported();
    if (!isSupported) return;

    _activityId = await liveActivityManager.startLobbyActivity(
      lobbyId: widget.lobbyId,
      gameName: widget.gameName,
      currentPlayers: widget.participantNames.length,
      maxPlayers: 4,
      participantNames: widget.participantNames,
    );
  }

  Future<void> _endLiveActivity() async {
    if (_activityId == null) return;

    final liveActivityManager = LiveActivityManager();
    await liveActivityManager.endActivity(_activityId!);
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink(); // No UI needed
  }
}

/// Example: Settings screen for notification preferences
class NotificationSettingsExample extends ConsumerWidget {
  const NotificationSettingsExample({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification Settings')),
      body: ListView(
        children: [
          _buildToggle(
            'Momentum Notifications',
            'Get notified when lobbies fill up',
            Icons.trending_up,
          ),
          _buildToggle(
            'Direct Invites',
            'Receive invites from friends',
            Icons.mail,
          ),
          _buildToggle(
            'Spot Available',
            'Alert when spots open in favorite games',
            Icons.event_available,
          ),
          _buildToggle(
            'Timer Expiring',
            'Remind when your spot claim is expiring',
            Icons.timer,
          ),
          const Divider(),
          _buildCooldownSlider(),
        ],
      ),
    );
  }

  Widget _buildToggle(String title, String subtitle, IconData icon) {
    return SwitchListTile(
      secondary: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      value: true, // TODO: Bind to actual preference
      onChanged: (value) {
        // TODO: Update user preference in Supabase
      },
    );
  }

  Widget _buildCooldownSlider() {
    return ListTile(
      leading: const Icon(Icons.schedule),
      title: const Text('Cooldown Duration'),
      subtitle: const Text('45 minutes'),
      trailing: SizedBox(
        width: 200,
        child: Slider(
          value: 45,
          min: 30,
          max: 60,
          divisions: 6,
          label: '45 min',
          onChanged: (value) {
            // TODO: Update cooldown preference
          },
        ),
      ),
    );
  }
}
