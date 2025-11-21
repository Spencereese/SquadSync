import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers.dart';

// Example widget showing how to migrate from Provider to Riverpod StateNotifier
class RiverpodMigrationExample extends ConsumerWidget {
  const RiverpodMigrationExample({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // OLD WAY with Provider:
    // final squadState = Provider.of<SquadState>(context);
    // final squadSpots = squadState.squadSpots;
    // final displayName = squadState.displayName;

    // NEW WAY with Riverpod StateNotifier:
    final squadState = ref.watch(squadStateNotifierProvider);
    final squadNotifier = ref.read(squadStateNotifierProvider.notifier);
    final squadSpots = squadNotifier.squadSpots;
    final displayName = squadState.displayName;

    // For efficient updates, use .select() to only rebuild when specific properties change
    final isInitialized = ref.watch(
        squadStateNotifierProvider.select((state) => state.isInitialized));
    final selectedSquadId = ref.watch(
        squadStateNotifierProvider.select((state) => state.selectedSquadId));

    return Scaffold(
      appBar: AppBar(
        title: Text('Squad: ${selectedSquadId ?? 'None'}'),
      ),
      body: Column(
        children: [
          // Status indicator
          Container(
            padding: const EdgeInsets.all(16),
            color: isInitialized ? Colors.green : Colors.red,
            child: Text(
              isInitialized ? 'Initialized' : 'Initializing...',
              style: const TextStyle(color: Colors.white),
            ),
          ),

          // Display name
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Welcome, $displayName!'),
          ),

          // Squad spots (computed property)
          Expanded(
            child: ListView.builder(
              itemCount: squadSpots.length,
              itemBuilder: (context, index) {
                final spot = squadSpots[index];
                return ListTile(
                  title: Text('Spot ${index + 1}: ${spot ?? 'Empty'}'),
                );
              },
            ),
          ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    // OLD WAY: squadState.createSquad('New Squad');
                    // NEW WAY: Use ref.read() for actions
                    ref
                        .read(squadStateNotifierProvider.notifier)
                        .createSquad('New Squad');
                  },
                  child: const Text('Create Squad'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Actions that modify state
                    ref.read(squadStateNotifierProvider.notifier).leaveSquad();
                  },
                  child: const Text('Leave Squad'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Example of using .select() for performance optimization
class OptimizedSquadDisplay extends ConsumerWidget {
  const OptimizedSquadDisplay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // For computed properties, we need to watch the underlying state and compute
    final gameName = ref.watch(
      squadStateNotifierProvider
          .select((state) => state.currentGame?['name'] ?? ''),
    );
    final gameSquadSpots = ref.watch(
      squadStateNotifierProvider
          .select((state) => state.gameSquadSpots[gameName] ?? []),
    );
    final memberDisplayNames = ref.watch(
      squadStateNotifierProvider.select((state) => state.memberDisplayNames),
    );

    // Compute squadSpots from the watched state
    final squadSpots = gameSquadSpots
        .map((uid) => uid != null ? memberDisplayNames[uid] : null)
        .toList();

    // Only rebuilds when displayName changes
    final displayName = ref.watch(
      squadStateNotifierProvider.select((state) => state.displayName),
    );

    return Column(
      children: [
        Text('Player: $displayName'),
        Text('Squad Spots: ${squadSpots.length}'),
        // This widget rebuilds when the relevant state changes
      ],
    );
  }
}

// Advanced .select() examples for granular updates
class GranularStateSelectors extends ConsumerWidget {
  const GranularStateSelectors({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Select specific boolean flags for conditional rendering
    final isInitialized = ref.watch(
      squadStateNotifierProvider.select((state) => state.isInitialized),
    );
    final hasNewSquadSpot = ref.watch(
      squadStateNotifierProvider.select((state) => state.hasNewSquadSpot),
    );
    final hasUnreadMessages = ref.watch(
      squadStateNotifierProvider.select((state) => state.hasUnreadMessages),
    );

    // Select collections for list rendering
    final availableGames = ref.watch(
      squadStateNotifierProvider.select((state) => state.availableGames),
    );
    final peacockQueue = ref.watch(
      squadStateNotifierProvider.select((state) => state.peacockQueue),
    );

    // Select nested map properties
    final currentGameName = ref.watch(
      squadStateNotifierProvider.select((state) => state.currentGame?['name']),
    );
    final selectedSquadId = ref.watch(
      squadStateNotifierProvider.select((state) => state.selectedSquadId),
    );

    // Select computed properties (lengths, counts)
    final squadMemberCount = ref.watch(
      squadStateNotifierProvider
          .select((state) => state.squadMemberUids.length),
    );
    final gameHistoryCount = ref.watch(
      squadStateNotifierProvider.select((state) => state.gameHistory.length),
    );

    return Column(
      children: [
        // Status indicators - only rebuild when these specific flags change
        if (!isInitialized) const CircularProgressIndicator(),
        if (hasNewSquadSpot) const Text('New squad spot available!'),
        if (hasUnreadMessages) const Text('You have unread messages'),

        // Lists - only rebuild when these collections change
        Text('Available Games: ${availableGames.length}'),
        Text('Peacock Queue: ${peacockQueue.length}'),

        // Current state - only rebuild when these values change
        Text('Current Game: $currentGameName'),
        Text('Selected Squad: $selectedSquadId'),

        // Counts - only rebuild when collection sizes change
        Text('Squad Members: $squadMemberCount'),
        Text('Game History: $gameHistoryCount'),
      ],
    );
  }
}

// Example of selecting multiple related properties efficiently
class MultiPropertySelector extends ConsumerWidget {
  const MultiPropertySelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Select multiple related properties in one watch
    final squadData = ref.watch(
      squadStateNotifierProvider.select((state) => (
            squadId: state.selectedSquadId,
            memberCount: state.squadMemberUids.length,
            isCreator: state.selectedSquadId != null &&
                FirebaseAuth.instance.currentUser?.uid ==
                    state.currentSquadData?['creatorUid'],
          )),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Squad: ${squadData.squadId ?? 'None'}'),
            Text('Members: ${squadData.memberCount}'),
            Text(squadData.isCreator ? 'You are the creator' : 'Member'),
          ],
        ),
      ),
    );
  }
}

// Example of selecting nested collections with filtering
class FilteredCollectionSelector extends ConsumerWidget {
  const FilteredCollectionSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Select and filter game lobbies in one operation
    final activeLobbies = ref.watch(
      squadStateNotifierProvider.select((state) {
        return state.gameLobbies.entries
            .where((entry) => entry.value.isNotEmpty)
            .map((entry) => MapEntry(entry.key, entry.value.length))
            .toList();
      }),
    );

    return Column(
      children: activeLobbies
          .map((lobby) => Text('${lobby.key}: ${lobby.value} active lobbies'))
          .toList(),
    );
  }
}

// Example of selecting boolean flags for conditional UI
class StatusIndicatorSelector extends ConsumerWidget {
  const StatusIndicatorSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Select boolean flags individually for precise rebuild control
    final isInitialized = ref.watch(
      squadStateNotifierProvider.select((state) => state.isInitialized),
    );
    final hasNewSquadSpot = ref.watch(
      squadStateNotifierProvider.select((state) => state.hasNewSquadSpot),
    );
    final hasUnreadMessages = ref.watch(
      squadStateNotifierProvider.select((state) => state.hasUnreadMessages),
    );
    final hasNewAvailability = ref.watch(
      squadStateNotifierProvider.select((state) => state.hasNewAvailability),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Each indicator only rebuilds when its specific flag changes
        StatusDot(
          active: isInitialized,
          label: 'Initialized',
          color: Colors.green,
        ),
        StatusDot(
          active: hasNewSquadSpot,
          label: 'New Spot',
          color: Colors.blue,
        ),
        StatusDot(
          active: hasUnreadMessages,
          label: 'Messages',
          color: Colors.orange,
        ),
        StatusDot(
          active: hasNewAvailability,
          label: 'Availability',
          color: Colors.purple,
        ),
      ],
    );
  }
}

class StatusDot extends StatelessWidget {
  const StatusDot({
    super.key,
    required this.active,
    required this.label,
    required this.color,
  });

  final bool active;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? color : Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: active ? color : Colors.grey,
          ),
        ),
      ],
    );
  }
}

// Example of selecting computed properties (counts, derived values)
class ComputedPropertySelector extends ConsumerWidget {
  const ComputedPropertySelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Select computed properties that derive from state
    final totalGames = ref.watch(
      squadStateNotifierProvider.select((state) => state.availableGames.length),
    );
    final activeSquads = ref.watch(
      squadStateNotifierProvider.select((state) => state.userSquadIds.length),
    );
    final pendingTimers = ref.watch(
      squadStateNotifierProvider.select((state) =>
          state.peacockTimers.values.where((timer) => timer != null).length),
    );

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Statistics', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Available Games: $totalGames'),
            Text('Active Squads: $activeSquads'),
            Text('Pending Timers: $pendingTimers'),
          ],
        ),
      ),
    );
  }
}

// Example of listening to state changes with Consumer
class SquadStatusConsumer extends ConsumerWidget {
  const SquadStatusConsumer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // For computed properties like isCreator, watch the underlying state
    final selectedSquadId = ref.watch(
      squadStateNotifierProvider.select((state) => state.selectedSquadId),
    );
    final currentSquadData = ref.watch(
      squadStateNotifierProvider.select((state) => state.currentSquadData),
    );

    final isCreator = selectedSquadId != null &&
        FirebaseAuth.instance.currentUser?.uid ==
            currentSquadData?['creatorUid'];

    return Text(isCreator ? 'You are the squad creator' : 'Member');
  }
}
