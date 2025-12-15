import 'package:flutter/material.dart' hide ThemeMode;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_theme.dart';
import '../domain/entities/app_user.dart';
import '../domain/entities/system_state.dart';
import '../presentation/notifiers/user_notifier.dart';
import '../presentation/notifiers/system_notifier.dart';
import '../services/auth_service_supabase.dart';
import '../services/supabase_service.dart';

/// Comprehensive settings screen for SquadSync
/// Includes: Notifications, Theme, Privacy (Blocks & Friends)
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isLoadingBlocks = false;
  bool _isLoadingFriends = false;
  List<Map<String, dynamic>> _blockedUsers = [];
  List<Map<String, dynamic>> _friends = [];

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
    _loadFriends();
  }

  Future<void> _loadBlockedUsers() async {
    setState(() => _isLoadingBlocks = true);
    try {
      final user = AuthServiceSupabase().currentUser;
      if (user == null) return;

      final response = await SupabaseService.client
          .from('user_blocks')
          .select(
              'blocked_uid, users!user_blocks_blocked_uid_fkey(id, display_name, profile_image)')
          .eq('blocker_uid', user.id);

      setState(() {
        _blockedUsers = (response as List).map((block) {
          final blockedUser = block['users'];
          return {
            'uid': blockedUser['id'],
            'display_name': blockedUser['display_name'] ?? 'Unknown User',
            'profile_image': blockedUser['profile_image'],
          };
        }).toList();
        _isLoadingBlocks = false;
      });
    } catch (e) {
      debugPrint('Error loading blocked users: $e');
      setState(() => _isLoadingBlocks = false);
    }
  }

  Future<void> _loadFriends() async {
    setState(() => _isLoadingFriends = true);
    try {
      final user = AuthServiceSupabase().currentUser;
      if (user == null) return;

      final response = await SupabaseService.client.rpc('get_friends', params: {
        'current_user_id': user.id,
      });

      setState(() {
        _friends = (response as List).map((friend) {
          return {
            'uid': friend['id'],
            'display_name': friend['display_name'] ?? 'Unknown User',
            'profile_image': friend['profile_image'],
            'online_status': friend['online_status'],
          };
        }).toList();
        _isLoadingFriends = false;
      });
    } catch (e) {
      debugPrint('Error loading friends: $e');
      setState(() => _isLoadingFriends = false);
    }
  }

  Future<void> _unblockUser(String uid, String displayName) async {
    try {
      final user = AuthServiceSupabase().currentUser;
      if (user == null) return;

      await SupabaseService.client
          .from('user_blocks')
          .delete()
          .eq('blocker_uid', user.id)
          .eq('blocked_uid', uid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unblocked $displayName'),
            backgroundColor: AppTheme.success(Theme.of(context).colorScheme),
          ),
        );
      }

      await _loadBlockedUsers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to unblock user: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _removeFriend(String uid, String displayName) async {
    try {
      final user = AuthServiceSupabase().currentUser;
      if (user == null) return;

      await SupabaseService.client.rpc('remove_friend', params: {
        'user_id_1': user.id,
        'user_id_2': uid,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed $displayName from friends'),
            backgroundColor: AppTheme.warning(Theme.of(context).colorScheme),
          ),
        );
      }

      await _loadFriends();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove friend: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userAsync = ref.watch(userNotifierProvider);
    final systemAsync = ref.watch(systemNotifierProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.orbitron(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: userAsync.when(
        data: (user) => systemAsync.when(
          data: (systemState) =>
              _buildSettingsContent(theme, user, systemState),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildSettingsContent(
      ThemeData theme, AppUser? user, SystemState systemState) {
    if (user == null) {
      return const Center(child: Text('User not found'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Notifications Section
        _buildSectionHeader(theme, '🔔 Notifications'),
        _buildNotificationsSection(theme, user),
        const SizedBox(height: 24),

        // Theme Section
        _buildSectionHeader(theme, '🎨 Appearance'),
        _buildThemeSection(theme, systemState),
        const SizedBox(height: 24),

        // Privacy Section
        _buildSectionHeader(theme, '🔒 Privacy & Friends'),
        _buildPrivacySection(theme, user),
        const SizedBox(height: 24),

        // Blocked Users
        _buildSectionHeader(theme, '🚫 Blocked Users'),
        _buildBlockedUsersSection(theme),
        const SizedBox(height: 24),

        // Friends Management
        _buildSectionHeader(theme, '👥 Friends'),
        _buildFriendsSection(theme),
        const SizedBox(height: 24),

        // About Section
        _buildSectionHeader(theme, 'ℹ️ About'),
        _buildAboutSection(theme),
      ],
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.orbitron(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildNotificationsSection(ThemeData theme, AppUser user) {
    final notifSettings = user.notificationSettings;

    return Container(
      decoration: theme.glassyCard(),
      child: Column(
        children: [
          _buildSettingTile(
            theme,
            'Push Notifications',
            'Receive notifications on your device',
            Icons.notifications,
            notifSettings['pushNotifications'] ?? true,
            (value) => _updateNotificationSetting('pushNotifications', value),
          ),
          _buildDivider(theme),
          _buildSettingTile(
            theme,
            'Sound',
            'Play sound for notifications',
            Icons.volume_up,
            notifSettings['soundEnabled'] ?? true,
            (value) => _updateNotificationSetting('soundEnabled', value),
          ),
          _buildDivider(theme),
          _buildSettingTile(
            theme,
            'Vibration',
            'Vibrate on notifications',
            Icons.vibration,
            notifSettings['vibrationEnabled'] ?? true,
            (value) => _updateNotificationSetting('vibrationEnabled', value),
          ),
          _buildDivider(theme),
          _buildSettingTile(
            theme,
            'Show Previews',
            'Display message content in notifications',
            Icons.preview,
            notifSettings['showPreviews'] ?? true,
            (value) => _updateNotificationSetting('showPreviews', value),
          ),
          _buildDivider(theme),
          _buildSettingTile(
            theme,
            'Lobby Invites',
            'Notifications for lobby invitations',
            Icons.gamepad,
            notifSettings['lobbyInvites'] ?? true,
            (value) => _updateNotificationSetting('lobbyInvites', value),
          ),
          _buildDivider(theme),
          _buildSettingTile(
            theme,
            'Friend Requests',
            'Notifications for friend requests',
            Icons.person_add,
            notifSettings['friendRequests'] ?? true,
            (value) => _updateNotificationSetting('friendRequests', value),
          ),
          _buildDivider(theme),
          _buildSettingTile(
            theme,
            'Game Updates',
            'Notifications about game changes',
            Icons.update,
            notifSettings['gameUpdates'] ?? false,
            (value) => _updateNotificationSetting('gameUpdates', value),
          ),
          _buildDivider(theme),
          _buildSettingTile(
            theme,
            'Achievement Alerts',
            'Notifications for achievements',
            Icons.emoji_events,
            notifSettings['achievementAlerts'] ?? true,
            (value) => _updateNotificationSetting('achievementAlerts', value),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSection(ThemeData theme, SystemState systemState) {
    return Container(
      decoration: theme.glassyCard(),
      child: Column(
        children: [
          // Theme Mode
          ListTile(
            leading: Icon(Icons.brightness_6, color: theme.colorScheme.primary),
            title: Text('Theme Mode', style: GoogleFonts.robotoMono()),
            subtitle: Text(
              _getThemeModeText(systemState.themeMode),
              style: GoogleFonts.robotoMono(fontSize: 12),
            ),
            trailing: DropdownButton<ThemeMode>(
              value: systemState.themeMode,
              dropdownColor: theme.colorScheme.surfaceContainerHighest,
              items: const [
                DropdownMenuItem(
                  value: ThemeMode.system,
                  child: Text('System'),
                ),
                DropdownMenuItem(
                  value: ThemeMode.light,
                  child: Text('Light'),
                ),
                DropdownMenuItem(
                  value: ThemeMode.dark,
                  child: Text('Dark'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  ref.read(systemNotifierProvider.notifier).setThemeMode(value);
                  HapticFeedback.lightImpact();
                }
              },
            ),
          ),
          _buildDivider(theme),
          // Neon Glow Effects
          _buildSettingTile(
            theme,
            'Neon Glow Effects',
            'Enable glowing UI elements',
            Icons.auto_awesome,
            true, // TODO: Add to SystemState
            (value) {
              // TODO: Implement neon glow toggle
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Neon glow settings coming soon!')),
              );
            },
          ),
          _buildDivider(theme),
          // High Contrast Mode
          _buildSettingTile(
            theme,
            'High Contrast Mode',
            'Increase visibility for accessibility',
            Icons.contrast,
            false, // TODO: Add to SystemState
            (value) {
              // TODO: Implement high contrast mode
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('High contrast mode coming soon!')),
              );
            },
          ),
          _buildDivider(theme),
          // Dynamic Game Themes
          _buildSettingTile(
            theme,
            'Dynamic Game Themes',
            'Auto-color themes from game covers',
            Icons.palette,
            true, // TODO: Add to SystemState
            (value) {
              // TODO: Implement dynamic theme toggle
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Theme settings coming soon!')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacySection(ThemeData theme, AppUser user) {
    return Container(
      decoration: theme.glassyCard(),
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.visibility, color: theme.colorScheme.primary),
            title: Text('Profile Visibility', style: GoogleFonts.robotoMono()),
            subtitle: Text(
              'Who can see your profile',
              style: GoogleFonts.robotoMono(fontSize: 12),
            ),
            trailing: Text(
              'Public',
              style: GoogleFonts.robotoMono(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: () {
              // TODO: Implement profile visibility settings
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Profile visibility settings coming soon!')),
              );
            },
          ),
          _buildDivider(theme),
          _buildSettingTile(
            theme,
            'Show Online Status',
            'Let others see when you\'re online',
            Icons.circle,
            user.notificationSettings['showOnlineStatus'] ?? true,
            (value) async {
              await _updateNotificationSetting('showOnlineStatus', value);
              // Update online status immediately if turning off
              if (!value) {
                final authUser = AuthServiceSupabase().currentUser;
                if (authUser != null) {
                  await SupabaseService.client.from('users').update({
                    'online': false,
                  }).eq('id', authUser.id);
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBlockedUsersSection(ThemeData theme) {
    if (_isLoadingBlocks) {
      return Container(
        decoration: theme.glassyCard(),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_blockedUsers.isEmpty) {
      return Container(
        decoration: theme.glassyCard(),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'No blocked users',
              style: GoogleFonts.robotoMono(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: theme.glassyCard(),
      child: Column(
        children: _blockedUsers.asMap().entries.map((entry) {
          final index = entry.key;
          final user = entry.value;
          final isLast = index == _blockedUsers.length - 1;

          return Column(
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundImage: user['profile_image'] != null
                      ? NetworkImage(user['profile_image'])
                      : null,
                  child: user['profile_image'] == null
                      ? Text(user['display_name'][0].toUpperCase())
                      : null,
                ),
                title: Text(
                  user['display_name'],
                  style: GoogleFonts.robotoMono(),
                ),
                trailing: TextButton(
                  onPressed: () =>
                      _unblockUser(user['uid'], user['display_name']),
                  child: Text(
                    'Unblock',
                    style: GoogleFonts.robotoMono(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
              if (!isLast) _buildDivider(theme),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFriendsSection(ThemeData theme) {
    if (_isLoadingFriends) {
      return Container(
        decoration: theme.glassyCard(),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_friends.isEmpty) {
      return Container(
        decoration: theme.glassyCard(),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'No friends yet',
              style: GoogleFonts.robotoMono(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: theme.glassyCard(),
      child: Column(
        children: _friends.asMap().entries.map((entry) {
          final index = entry.key;
          final friend = entry.value;
          final isLast = index == _friends.length - 1;
          final isOnline = friend['online_status'] == true;

          return Column(
            children: [
              ListTile(
                leading: Stack(
                  children: [
                    CircleAvatar(
                      backgroundImage: friend['profile_image'] != null
                          ? NetworkImage(friend['profile_image'])
                          : null,
                      child: friend['profile_image'] == null
                          ? Text(friend['display_name'][0].toUpperCase())
                          : null,
                    ),
                    if (isOnline)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.colorScheme.surface,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                title: Text(
                  friend['display_name'],
                  style: GoogleFonts.robotoMono(),
                ),
                subtitle: Text(
                  isOnline ? 'Online' : 'Offline',
                  style: GoogleFonts.robotoMono(
                    fontSize: 12,
                    color: isOnline
                        ? Colors.green
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                trailing: IconButton(
                  icon:
                      Icon(Icons.person_remove, color: theme.colorScheme.error),
                  onPressed: () => _showRemoveFriendDialog(
                      friend['uid'], friend['display_name']),
                ),
              ),
              if (!isLast) _buildDivider(theme),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAboutSection(ThemeData theme) {
    return Container(
      decoration: theme.glassyCard(),
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.info_outline, color: theme.colorScheme.primary),
            title: Text('Version', style: GoogleFonts.robotoMono()),
            trailing: Text(
              '1.0.0',
              style: GoogleFonts.robotoMono(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          _buildDivider(theme),
          ListTile(
            leading: Icon(Icons.logout, color: theme.colorScheme.error),
            title: Text(
              'Logout',
              style: GoogleFonts.robotoMono(color: theme.colorScheme.error),
            ),
            onTap: () => _showLogoutDialog(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile(
    ThemeData theme,
    String title,
    String subtitle,
    IconData icon,
    bool value,
    Function(bool) onChanged,
  ) {
    return SwitchListTile(
      secondary: Icon(icon, color: theme.colorScheme.primary),
      title: Text(title, style: GoogleFonts.robotoMono()),
      subtitle: Text(subtitle, style: GoogleFonts.robotoMono(fontSize: 12)),
      value: value,
      onChanged: (newValue) {
        HapticFeedback.lightImpact();
        onChanged(newValue);
      },
    );
  }

  Widget _buildDivider(ThemeData theme) {
    return Divider(
      height: 1,
      color: theme.colorScheme.outline.withValues(alpha: 0.2),
    );
  }

  String _getThemeModeText(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'Follow system settings';
      case ThemeMode.light:
        return 'Always light';
      case ThemeMode.dark:
        return 'Always dark';
    }
  }

  Future<void> _updateNotificationSetting(String key, bool value) async {
    try {
      final user = AuthServiceSupabase().currentUser;
      if (user == null) return;

      final currentUser = ref.read(userNotifierProvider).value;
      if (currentUser == null) return;

      final updatedSettings =
          Map<String, bool>.from(currentUser.notificationSettings);
      updatedSettings[key] = value;

      await SupabaseService.client.from('users').update({
        'notification_settings': updatedSettings,
      }).eq('id', user.id);

      // Refresh user state
      ref.invalidate(userNotifierProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Notification setting updated'),
            backgroundColor: AppTheme.success(Theme.of(context).colorScheme),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update setting: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _showRemoveFriendDialog(String uid, String displayName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove Friend', style: GoogleFonts.orbitron()),
        content: Text(
          'Remove $displayName from your friends list?',
          style: GoogleFonts.robotoMono(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.robotoMono()),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _removeFriend(uid, displayName);
            },
            child: Text(
              'Remove',
              style: GoogleFonts.robotoMono(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(ThemeData theme) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Logout', style: GoogleFonts.orbitron()),
        content: Text(
          'Are you sure you want to logout?',
          style: GoogleFonts.robotoMono(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.robotoMono()),
          ),
          TextButton(
            onPressed: () async {
              try {
                await AuthServiceSupabase().signOut();
                if (context.mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Logout failed: $e'),
                      backgroundColor: theme.colorScheme.error,
                    ),
                  );
                }
              }
            },
            child: Text(
              'Logout',
              style: GoogleFonts.robotoMono(color: theme.colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}
