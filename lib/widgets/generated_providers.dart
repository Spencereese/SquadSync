import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../providers.dart';
import '../presentation/notifiers/user_notifier.dart';
import '../presentation/notifiers/squad_notifier.dart';

part 'generated_providers.g.dart';

/// Example of Riverpod code generation for better performance
/// This file demonstrates how to use @riverpod annotations for automatic code generation
///
/// TREE-SHAKING BENEFITS:
/// - Generated providers use .select() internally for optimal rebuilds
/// - Only rebuilds when specific state slices change, not entire state objects
/// - Reduces bundle size by eliminating unused provider code at compile-time
/// - Compile-time safety prevents runtime provider resolution errors
/// - Better IDE support with autocomplete and error detection
/// - Improved performance through static provider resolution

/// Generated provider - more efficient with code generation
@riverpod
class Counter extends _$Counter {
  @override
  int build() => 0;

  void increment() => state++;
}

/// Generated provider with dependencies
@riverpod
String userGreeting(UserGreetingRef ref) {
  final userAsync = ref.watch(userNotifierProvider);
  return userAsync.maybeWhen(
    data: (user) => 'Hello, ${user?.displayName ?? 'User'}!',
    orElse: () => 'Hello, User!',
  );
}

/// Generated provider for async operations
@riverpod
Future<List<String>> userPinnedGames(UserPinnedGamesRef ref) async {
  final userAsync = ref.watch(userNotifierProvider);
  return userAsync.maybeWhen(
    data: (user) =>
        user?.pinnedGames.map((game) => game['name'] as String).toList() ?? [],
    orElse: () => [],
  );
}

/// Generated provider with family (parameterized)
@riverpod
String gameStatus(GameStatusRef ref, String gameName) {
  // ignore: deprecated_member_use_from_same_package
  // This would normally watch some game state
  return 'Playing $gameName';
}

/// Example widget using generated providers
class GeneratedProvidersExample extends ConsumerWidget {
  const GeneratedProvidersExample({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Using generated providers - these are more performant
    final counter = ref.watch(counterProvider);
    final greeting = ref.watch(userGreetingProvider);
    final pinnedGamesAsync = ref.watch(userPinnedGamesProvider);
    final gameStatus = ref.watch(gameStatusProvider('Call of Duty'));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Generated Providers Example'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Counter: $counter'),
            const SizedBox(height: 8),
            Text(greeting),
            const SizedBox(height: 8),
            Text('Game Status: $gameStatus'),
            const SizedBox(height: 16),
            const Text(
              'Benefits of Code Generation:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('• Better tree-shaking (smaller bundle size)'),
            const Text('• Compile-time safety (no runtime provider lookups)'),
            const Text('• Better performance (faster provider resolution)'),
            const Text(
                '• IDE support (better autocomplete and error detection)'),
            const SizedBox(height: 16),
            pinnedGamesAsync.when(
              data: (games) => Text('Pinned Games: ${games.length}'),
              loading: () => const CircularProgressIndicator(),
              error: (error, stack) => Text('Error: $error'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () =>
                      ref.read(counterProvider.notifier).increment(),
                  child: const Text('Increment'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(userPinnedGamesProvider),
                  child: const Text('Refresh Games'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Example of migrating existing providers to generated ones
/// This shows the pattern for converting manual providers to generated providers

// Before (manual provider):
// final userDisplayNameProvider = Provider<String>((ref) {
//   final userManager = ref.watch(userManagerProvider);
//   return userManager.displayName ?? 'Anonymous';
// });

// After (generated provider):
@riverpod
String userDisplayName(UserDisplayNameRef ref) {
  final userAsync = ref.watch(userNotifierProvider);
  return userAsync.maybeWhen(
    data: (user) => user?.displayName ?? 'Anonymous',
    orElse: () => 'Anonymous',
  );
}

/// Example of a generated provider with complex logic
@riverpod
Map<String, dynamic> userStats(UserStatsRef ref) {
  final userAsync = ref.watch(userNotifierProvider);
  final squadAsync = ref.watch(squadNotifierProvider);

  return userAsync.maybeWhen(
    data: (user) => squadAsync.maybeWhen(
      data: (squadState) => {
        'displayName': user?.displayName,
        'pinnedGamesCount': user?.pinnedGames.length ?? 0,
        'activeSquadsCount': squadState.squadMemberUids.length,
        'isInitialized': squadState.isInitialized,
      },
      orElse: () => {
        'displayName': user?.displayName,
        'pinnedGamesCount': user?.pinnedGames.length ?? 0,
        'activeSquadsCount': 0,
        'isInitialized': false,
      },
    ),
    orElse: () => {
      'displayName': 'Anonymous',
      'pinnedGamesCount': 0,
      'activeSquadsCount': 0,
      'isInitialized': false,
    },
  );
}

/// Squad-specific generated providers with tree-shaking benefits
/// Tree-shaking: Only rebuilds when specific state slices change
/// NOTE: Complex provider functions commented out during migration to avoid compilation issues

/*
// Complex provider functions temporarily disabled during migration
// TODO: Re-enable after fixing async state handling
*/

/// Widget demonstrating the user stats provider
class UserStatsWidget extends ConsumerWidget {
  const UserStatsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(userStatsProvider);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('User Statistics',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Name: ${stats['displayName'] ?? 'Unknown'}'),
            Text('Pinned Games: ${stats['pinnedGamesCount']}'),
            Text('Active Squads: ${stats['activeSquadsCount']}'),
            Text(
                'Status: ${stats['isInitialized'] ? 'Ready' : 'Initializing'}'),
          ],
        ),
      ),
    );
  }
}
