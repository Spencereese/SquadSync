import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';

/// Example widget demonstrating Riverpod migration with .select() for efficiency
/// This shows how to replace Provider.of with Riverpod providers
class UserPinnedGamesCount extends ConsumerWidget {
  const UserPinnedGamesCount({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Using .select() to only rebuild when pinnedGames length changes
    // This is much more efficient than watching the entire user properties
    final pinnedGamesCount = ref.watch(
      userPropertiesProvider.select((userData) {
        final pinnedGames =
            userData.value?['pinnedGames'] as List<dynamic>? ?? [];
        return pinnedGames.length;
      }),
    );

    return Text('Pinned Games: $pinnedGamesCount');
  }
}

/// Another example: Watching current user ID efficiently
class CurrentUserDisplay extends ConsumerWidget {
  const CurrentUserDisplay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);

    return userId.when(
      data: (id) => Text('User ID: ${id ?? 'Not logged in'}'),
      loading: () => const CircularProgressIndicator(),
      error: (error, stack) => Text('Error: $error'),
    );
  }
}

/// Example of how to migrate from Provider.of<T>(context) to Riverpod
/// Old way (Provider):
/// final userManager = Provider.of<UserManager>(context, listen: false);
/// userManager.doSomething();
///
/// New way (Riverpod):
/// final userManager = ref.read(userManagerProvider);
/// userManager.doSomething();
///
/// For watching changes:
/// Old: Consumer<UserManager>(builder: (context, userManager, child) => ...)
/// New: ref.watch(userManagerProvider.select((userManager) => userManager.someProperty))

/// Advanced .select() patterns for granular updates
class SelectiveUserDataWatcher extends ConsumerWidget {
  const SelectiveUserDataWatcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Select specific user properties for targeted rebuilds
    final displayName = ref.watch(
      userPropertiesProvider
          .select((userData) => userData.value?['displayName'] as String?),
    );
    final profileImage = ref.watch(
      userPropertiesProvider
          .select((userData) => userData.value?['profileImage'] as String?),
    );
    final isOnline = ref.watch(
      userPropertiesProvider
          .select((userData) => userData.value?['isOnline'] as bool? ?? false),
    );

    return Column(
      children: [
        // Each Text widget only rebuilds when its specific property changes
        Text('Name: $displayName'),
        Text('Online: ${isOnline ? 'Yes' : 'No'}'),
        if (profileImage != null)
          Image.network(profileImage, width: 50, height: 50),
      ],
    );
  }
}

/// Example of selecting computed values from user data
class UserStatsSelector extends ConsumerWidget {
  const UserStatsSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Select computed statistics from user data
    final totalFriends = ref.watch(
      userPropertiesProvider.select((userData) {
        final friends = userData.value?['friends'] as List<dynamic>? ?? [];
        return friends.length;
      }),
    );
    final completedGames = ref.watch(
      userPropertiesProvider.select((userData) {
        final games = userData.value?['completedGames'] as List<dynamic>? ?? [];
        return games.length;
      }),
    );
    final achievementCount = ref.watch(
      userPropertiesProvider.select((userData) {
        final achievements =
            userData.value?['achievements'] as Map<String, dynamic>? ?? {};
        return achievements.length;
      }),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Friends: $totalFriends'),
            Text('Games Completed: $completedGames'),
            Text('Achievements: $achievementCount'),
          ],
        ),
      ),
    );
  }
}

/// Example of selecting boolean flags for conditional rendering
class UserStatusIndicators extends ConsumerWidget {
  const UserStatusIndicators({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Select boolean status flags individually
    final isPremium = ref.watch(
      userPropertiesProvider
          .select((userData) => userData.value?['isPremium'] as bool? ?? false),
    );
    final hasNotifications = ref.watch(
      userPropertiesProvider.select(
          (userData) => userData.value?['hasNotifications'] as bool? ?? false),
    );
    final isVerified = ref.watch(
      userPropertiesProvider.select(
          (userData) => userData.value?['isVerified'] as bool? ?? false),
    );

    return Row(
      children: [
        if (isPremium) const Icon(Icons.star, color: Color(0xFFFFD700)),
        if (hasNotifications)
          const Icon(Icons.notifications, color: Colors.red),
        if (isVerified) const Icon(Icons.verified, color: Colors.blue),
      ],
    );
  }
}

/// Example of selecting nested data structures
class UserPreferencesSelector extends ConsumerWidget {
  const UserPreferencesSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Select nested preferences object
    final preferences = ref.watch(
      userPropertiesProvider.select((userData) =>
          userData.value?['preferences'] as Map<String, dynamic>? ?? {}),
    );

    // Select specific preference values
    final theme = ref.watch(
      userPropertiesProvider.select((userData) =>
          (userData.value?['preferences'] as Map<String, dynamic>?)?['theme']
              as String? ??
          'dark'),
    );
    final notificationsEnabled = ref.watch(
      userPropertiesProvider.select((userData) =>
          (userData.value?['preferences']
              as Map<String, dynamic>?)?['notifications'] as bool? ??
          true),
    );

    return Column(
      children: [
        Text('Theme: $theme'),
        Text('Notifications: ${notificationsEnabled ? 'Enabled' : 'Disabled'}'),
        Text('Total Preferences: ${preferences.length}'),
      ],
    );
  }
}
