import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_theme.dart';
import '../managers/user_manager.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  // Notification settings
  bool _pushNotifications = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _showPreviews = true;
  bool _quietHoursEnabled = false;
  TimeOfDay _quietStartTime = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _quietEndTime = const TimeOfDay(hour: 8, minute: 0);

  // Game-specific settings
  Set<String> _mutedGames = {};

  // Alert preferences
  bool _urgentAlertsOnly = false;
  bool _lobbyInvites = true;
  bool _friendRequests = true;
  bool _gameUpdates = false;
  bool _achievementAlerts = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pushNotifications = prefs.getBool('pushNotifications') ?? true;
      _soundEnabled = prefs.getBool('soundEnabled') ?? true;
      _vibrationEnabled = prefs.getBool('vibrationEnabled') ?? true;
      _showPreviews = prefs.getBool('showPreviews') ?? true;
      _quietHoursEnabled = prefs.getBool('quietHoursEnabled') ?? false;

      // Load quiet hours times
      final quietStart = prefs.getString('quietStartTime');
      final quietEnd = prefs.getString('quietEndTime');
      if (quietStart != null) {
        final parts = quietStart.split(':');
        _quietStartTime =
            TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
      if (quietEnd != null) {
        final parts = quietEnd.split(':');
        _quietEndTime =
            TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }

      // Alert preferences
      _urgentAlertsOnly = prefs.getBool('urgentAlertsOnly') ?? false;
      _lobbyInvites = prefs.getBool('lobbyInvites') ?? true;
      _friendRequests = prefs.getBool('friendRequests') ?? true;
      _gameUpdates = prefs.getBool('gameUpdates') ?? false;
      _achievementAlerts = prefs.getBool('achievementAlerts') ?? true;
    });

    // Load muted games from UserManager
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userManager = Provider.of<UserManager>(context, listen: false);
      userManager.fetchMutedGames();
      setState(() {
        _mutedGames = userManager.mutedGames.toSet();
      });
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStartTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStartTime ? _quietStartTime : _quietEndTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: AppTheme.cardDarkColor,
              hourMinuteTextColor: Colors.white,
              dialHandColor: AppTheme.accentColor,
              dialBackgroundColor: AppTheme.darkBackgroundColor,
              entryModeIconColor: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _quietStartTime = picked;
          _saveSetting('quietStartTime', '${picked.hour}:${picked.minute}');
        } else {
          _quietEndTime = picked;
          _saveSetting('quietEndTime', '${picked.hour}:${picked.minute}');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackgroundColor,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: AppTheme.cardDarkColor,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accentColor,
          labelColor: AppTheme.accentColor,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'General', icon: Icon(Icons.settings)),
            Tab(text: 'Games', icon: Icon(Icons.videogame_asset)),
            Tab(text: 'Schedule', icon: Icon(Icons.schedule)),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _buildGeneralSettings(),
              _buildGameSettings(),
              _buildScheduleSettings(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralSettings() {
    return Consumer<UserManager>(
      builder: (context, userManager, child) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSectionHeader('Push Notifications'),
            _buildSwitchTile(
              title: 'Push Notifications',
              subtitle: 'Receive notifications on your device',
              value: _pushNotifications,
              onChanged: (value) {
                setState(() => _pushNotifications = value);
                _saveSetting('pushNotifications', value);
              },
              icon: Icons.notifications,
            ),
            _buildSwitchTile(
              title: 'Sound',
              subtitle: 'Play notification sounds',
              value: _soundEnabled,
              onChanged: (value) {
                setState(() => _soundEnabled = value);
                _saveSetting('soundEnabled', value);
              },
              icon: Icons.volume_up,
              enabled: _pushNotifications,
            ),
            _buildSwitchTile(
              title: 'Vibration',
              subtitle: 'Vibrate for notifications',
              value: _vibrationEnabled,
              onChanged: (value) {
                setState(() => _vibrationEnabled = value);
                _saveSetting('vibrationEnabled', value);
              },
              icon: Icons.vibration,
              enabled: _pushNotifications,
            ),
            _buildSwitchTile(
              title: 'Show Previews',
              subtitle: 'Display message content in notifications',
              value: _showPreviews,
              onChanged: (value) {
                setState(() => _showPreviews = value);
                _saveSetting('showPreviews', value);
              },
              icon: Icons.visibility,
              enabled: _pushNotifications,
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('Alert Types'),
            _buildSwitchTile(
              title: 'Urgent Alerts Only',
              subtitle: 'Only show critical notifications',
              value: _urgentAlertsOnly,
              onChanged: (value) {
                setState(() => _urgentAlertsOnly = value);
                _saveSetting('urgentAlertsOnly', value);
              },
              icon: Icons.warning,
            ),
            _buildSwitchTile(
              title: 'Lobby Invites',
              subtitle: 'Notifications for game lobby invites',
              value: _lobbyInvites,
              onChanged: (value) {
                setState(() => _lobbyInvites = value);
                _saveSetting('lobbyInvites', value);
              },
              icon: Icons.group_add,
              enabled: !_urgentAlertsOnly,
            ),
            _buildSwitchTile(
              title: 'Friend Requests',
              subtitle: 'Notifications for new friend requests',
              value: _friendRequests,
              onChanged: (value) {
                setState(() => _friendRequests = value);
                _saveSetting('friendRequests', value);
              },
              icon: Icons.person_add,
              enabled: !_urgentAlertsOnly,
            ),
            _buildSwitchTile(
              title: 'Game Updates',
              subtitle: 'Notifications about game patches and news',
              value: _gameUpdates,
              onChanged: (value) {
                setState(() => _gameUpdates = value);
                _saveSetting('gameUpdates', value);
              },
              icon: Icons.new_releases,
              enabled: !_urgentAlertsOnly,
            ),
            _buildSwitchTile(
              title: 'Achievements',
              subtitle: 'Notifications for unlocked achievements',
              value: _achievementAlerts,
              onChanged: (value) {
                setState(() => _achievementAlerts = value);
                _saveSetting('achievementAlerts', value);
              },
              icon: Icons.emoji_events,
              enabled: !_urgentAlertsOnly,
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('Quick Actions'),
            Card(
              color: AppTheme.cardDarkColor,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quiet Mode',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Temporarily mute all game notifications',
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              setState(() => _mutedGames = userManager
                                  .pinnedGames
                                  .map((g) => g['slug'] ?? '')
                                  .toSet()
                                  .cast<String>());
                              userManager.mutedGames.clear();
                              for (final game in userManager.pinnedGames) {
                                userManager.muteGame(game['slug'] ?? '');
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('All games muted')),
                              );
                            },
                            icon: const Icon(Icons.volume_off),
                            label: const Text('Mute All'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[700],
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              setState(() => _mutedGames.clear());
                              userManager.clearMutedGames();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('All games unmuted')),
                              );
                            },
                            icon: const Icon(Icons.volume_up),
                            label: const Text('Unmute All'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[700],
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGameSettings() {
    return Consumer<UserManager>(
      builder: (context, userManager, child) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSectionHeader('Game-Specific Settings'),
            const Text(
              'Control notifications for individual games',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            if (userManager.pinnedGames.isEmpty)
              Card(
                color: AppTheme.cardDarkColor,
                child: const Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.videogame_asset, size: 48, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No pinned games',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Pin games in your profile to customize notifications',
                        style: TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              ...userManager.pinnedGames.map((game) {
                final gameSlug = game['slug'] ?? '';
                final isMuted = _mutedGames.contains(gameSlug);

                return Card(
                  color: AppTheme.cardDarkColor,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: game['image'] != null
                        ? Image.network(
                            game['image'],
                            width: 40,
                            height: 40,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.videogame_asset,
                              color: Colors.cyanAccent,
                            ),
                          )
                        : const Icon(
                            Icons.videogame_asset,
                            color: Colors.cyanAccent,
                            size: 40,
                          ),
                    title: Text(
                      game['name'] ?? 'Unknown Game',
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      isMuted ? 'Muted' : 'Notifications enabled',
                      style: TextStyle(
                        color: isMuted ? Colors.red[400] : Colors.green[400],
                      ),
                    ),
                    trailing: Switch(
                      value: !isMuted,
                      onChanged: (value) {
                        setState(() {
                          if (value) {
                            _mutedGames.remove(gameSlug);
                            userManager.unmuteGame(gameSlug);
                          } else {
                            _mutedGames.add(gameSlug);
                            userManager.muteGame(gameSlug);
                          }
                        });
                      },
                      activeThumbColor: AppTheme.accentColor,
                    ),
                  ),
                );
              }),
            const SizedBox(height: 24),
            _buildSectionHeader('Advanced Settings'),
            Card(
              color: AppTheme.cardDarkColor,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Notification Priority',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Choose which games get priority notifications',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    // This could be expanded to allow reordering games by priority
                    const Text(
                      'Coming soon: Priority ordering',
                      style: TextStyle(
                          color: Colors.grey, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildScheduleSettings() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Quiet Hours'),
        Card(
          color: AppTheme.cardDarkColor,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Quiet Hours',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Switch(
                      value: _quietHoursEnabled,
                      onChanged: (value) {
                        setState(() => _quietHoursEnabled = value);
                        _saveSetting('quietHoursEnabled', value);
                      },
                      activeThumbColor: AppTheme.accentColor,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Automatically mute notifications during specified hours',
                  style: TextStyle(color: Colors.grey[400]),
                ),
                if (_quietHoursEnabled) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'Quiet Hours Schedule',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Start Time',
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () => _selectTime(context, true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppTheme.darkBackgroundColor,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[600]!),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.access_time,
                                        color: Colors.cyanAccent, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      _quietStartTime.format(context),
                                      style:
                                          const TextStyle(color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'End Time',
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () => _selectTime(context, false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppTheme.darkBackgroundColor,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[600]!),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.access_time,
                                        color: Colors.cyanAccent, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      _quietEndTime.format(context),
                                      style:
                                          const TextStyle(color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[900]!.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[700]!),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Notifications will be silenced from ${_quietStartTime.format(context)} to ${_quietEndTime.format(context)}',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionHeader('Do Not Disturb'),
        Card(
          color: AppTheme.cardDarkColor,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Focus Mode',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Temporarily disable all notifications',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // TODO: Implement focus mode
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Focus mode activated for 1 hour')),
                          );
                        },
                        icon: const Icon(Icons.do_not_disturb),
                        label: const Text('1 Hour'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple[700],
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // TODO: Implement focus mode
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Focus mode activated for 2 hours')),
                          );
                        },
                        icon: const Icon(Icons.do_not_disturb),
                        label: const Text('2 Hours'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple[700],
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
    bool enabled = true,
  }) {
    return Card(
      color: AppTheme.cardDarkColor,
      margin: const EdgeInsets.only(bottom: 8),
      child: SwitchListTile(
        title: Text(
          title,
          style: TextStyle(
            color: enabled ? Colors.white : Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: enabled ? Colors.grey[400] : Colors.grey[600],
            fontSize: 12,
          ),
        ),
        secondary: Icon(
          icon,
          color: enabled ? AppTheme.accentColor : Colors.grey,
        ),
        value: value,
        onChanged: enabled ? onChanged : null,
        activeThumbColor: AppTheme.accentColor,
      ),
    );
  }
}
