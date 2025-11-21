import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../services/timer_service.dart';

class PeacockTimerDisplay extends ConsumerStatefulWidget {
  final String player;

  const PeacockTimerDisplay({
    super.key,
    required this.player,
  });

  @override
  ConsumerState<PeacockTimerDisplay> createState() =>
      _PeacockTimerDisplayState();
}

class _PeacockTimerDisplayState extends ConsumerState<PeacockTimerDisplay> {
  static const Duration _totalDuration = Duration(seconds: 3600); // 1 hour
  bool _hasExpired = false;

  @override
  Widget build(BuildContext context) {
    final key = 'peacock_${widget.player}';
    final timerService = ref.watch(timerServiceProvider);

    return StreamBuilder<Duration>(
      stream: timerService.observeTimer(key),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            width: 60,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }

        final remaining = snapshot.data ?? Duration.zero;
        final progress = remaining.inSeconds / _totalDuration.inSeconds;

        // Update formatted time
        final minutes = remaining.inMinutes;
        final seconds = remaining.inSeconds % 60;
        final formatted =
            '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

        // Haptic feedback on expiration
        if (remaining == Duration.zero && !_hasExpired) {
          _hasExpired = true;
          HapticFeedback.vibrate();
        } else if (remaining > Duration.zero) {
          _hasExpired = false;
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formatted,
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 60,
              height: 4,
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  progress > 0.5
                      ? Colors.tealAccent
                      : progress > 0.25
                          ? Colors.orangeAccent
                          : Colors.redAccent,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

class PeacockWidgets {
  static Widget buildPeacockSpot(BuildContext context, WidgetRef ref,
      Function() togglePeacockMembers) {
    final yourName = ref.read(squadStateNotifierProvider.select((state) => state.displayName));
    final gameName = ref.read(squadStateNotifierProvider.select((state) => state.currentGame?['name'] ?? ''));
    final squadSpots = ref.read(squadStateNotifierProvider.select((state) => state.gameSquadSpots[gameName] ?? []));
    final youAreAssigned = squadSpots.contains(yourName);
    // Placeholder for peacockTimers and peacockQueue - need to implement
    final youArePeacock = false; // squadState.peacockTimers.containsKey(yourName) || squadState.peacockQueue.contains(yourName);

    return GestureDetector(
      onLongPress: togglePeacockMembers,
      child: Semantics(
        label: 'Peacock Spot',
        child: Card(
          elevation: 4,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildPeacockInfo(context, ref),
                GestureDetector(
                  onLongPress: togglePeacockMembers,
                  child: ElevatedButton(
                    onPressed: () {
                      if (yourName.isEmpty) return;
                      if (youArePeacock) {
                        togglePeacockMembers();
                      } else if (youAreAssigned) {
                        final currentSpotIndex = squadSpots.indexOf(yourName);
                        if (currentSpotIndex != -1) {
                          // squadState.removeSpot(currentSpotIndex); // Placeholder, need to implement
                        }
                        // Immediately lock in as peacock instead of starting timer
                        // squadState.addToPeacock(yourName); // Placeholder, need to implement
                      } else {
                        // Immediately lock in as peacock instead of starting timer
                        // squadState.addToPeacock(yourName); // Placeholder, need to implement
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 6,
                    ),
                    child: const Tooltip(
                      message:
                          'Tap to claim/toggle members, hold to toggle members',
                      child: Text('Claim'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildPeacockInfo(BuildContext context, WidgetRef ref) {
    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Peacock: ',
              style: TextStyle(
                color: Colors.cyanAccent,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              )),
          _buildPeacockStatus(context, ref),
        ],
      ),
    );
  }

  static Widget _buildPeacockStatus(
      BuildContext context, WidgetRef ref) {
    // Placeholder implementation - need to implement peacock status
    return const Text('Open', style: TextStyle(color: Colors.white));
  }

  static Widget _buildPeacockTimerRow(BuildContext context,
      MapEntry<String, Map<String, dynamic>?> entry, WidgetRef ref) {
    final timer = entry.value;
    if (timer == null) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(entry.key, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(width: 8),
        _buildStatusChip('Strutting'),
        const SizedBox(width: 8),
        PeacockTimerDisplay(player: entry.key),
      ],
    );
  }

  static Widget _buildPeacockQueueRow(BuildContext context, String player) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(player, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(width: 8),
        _buildStatusChip('Waiting'),
      ],
    );
  }

  static Widget _buildStatusChip(String status) {
    return Chip(
      label: Text(status, style: const TextStyle(fontSize: 12)),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      backgroundColor: _getStatusColor(status).withValues(alpha: 0.2),
      labelStyle: TextStyle(color: _getStatusColor(status)),
    );
  }

  static Color _getStatusColor(String status) {
    switch (status) {
      case 'Strutting':
        return Colors.blueAccent;
      case 'Walking':
        return Colors.greenAccent;
      case 'in game':
        return Colors.greenAccent;
      case 'Ready':
        return Colors.yellowAccent;
      case 'Claimed Spot':
        return Colors.orangeAccent;
      case 'Waiting':
        return Colors.grey[400]!;
      default:
        return Colors.grey[600]!;
    }
  }

  static Widget buildPeacockMembersList(BuildContext context,
      WidgetRef ref, Function(String, bool) togglePeacockMember) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        children: [
          // Preferred Games Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border:
                  Border(bottom: BorderSide(color: Colors.grey, width: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Preferred Peacock Games',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.cyanAccent,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [].map((game) { // squadState.availableGames
                    final gameName = game['name'] as String;
                    final isPreferred = false; // squadState.preferredPeacockGames.contains(gameName)
                    return FilterChip(
                      label: Text(gameName),
                      selected: isPreferred,
                      onSelected: (selected) {
                        // if (selected) {
                        //   squadState.addPreferredPeacockGame(gameName);
                        // } else {
                        //   squadState.removePreferredPeacockGame(gameName);
                        // }
                      },
                      backgroundColor: Colors.grey[800],
                      selectedColor: Colors.cyanAccent.withValues(alpha: 0.3),
                      checkmarkColor: Colors.cyanAccent,
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          // Members List
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 0, // squadState.getFilteredMembers.length
            itemBuilder: (context, index) {
              final member = 'Unknown'; // squadState.getFilteredMembers[index]
              final isInPeacock = false; // squadState.peacockTimers.containsKey(member) || squadState.peacockQueue.contains(member)
              return ListTile(
                title: Text(member),
                trailing: Icon(
                  isInPeacock ? Icons.remove_circle : Icons.add_circle,
                  color: isInPeacock ? Colors.red : Colors.green,
                  semanticLabel:
                      isInPeacock ? 'Remove from Peacock' : 'Add to Peacock',
                ),
                onTap: () => togglePeacockMember(member, isInPeacock),
              );
            },
          ),
        ],
      ),
    );
  }
}
