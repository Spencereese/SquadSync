import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/notifiers/lobby_notifier.dart' as ln;

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
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final squadStateAsync = ref.watch(ln.lobbyNotifierProvider);

    return squadStateAsync.when(
      data: (squadState) {
        final timerDuration =
            squadState.peacockTimerStates[widget.player] ?? Duration.zero;
        final interpolated = timerDuration;
        final progress = interpolated.inSeconds / _totalDuration.inSeconds;

        // Update formatted time
        final minutes = interpolated.inMinutes;
        final seconds = interpolated.inSeconds % 60;
        final formatted =
            '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

        // Haptic feedback on expiration
        if (interpolated == Duration.zero && !_hasExpired) {
          _hasExpired = true;
          HapticFeedback.vibrate();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Peacock timer expired!')),
            );
          }
        } else if (interpolated > Duration.zero) {
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
      loading: () => const SizedBox(
        width: 60,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (error, stack) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Timer desync error: $error')),
          );
        }
        return const SizedBox(
          width: 60,
          height: 20,
          child: Icon(Icons.error, size: 16),
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
  static Widget buildPeacockSpot(
      BuildContext context, WidgetRef ref, Function() togglePeacockMembers) {
    final yourName = ref.read(ln.lobbyNotifierProvider.select((asyncValue) =>
        asyncValue.value?.memberDisplayNames.values
            .firstWhere((name) => name.isNotEmpty, orElse: () => 'You') ??
        'You'));
    final gameName = ref.read(ln.lobbyNotifierProvider
        .select((asyncValue) => asyncValue.value?.currentGame?['name'] ?? ''));
    final squadSpots = ref.read(ln.lobbyNotifierProvider.select(
        (asyncValue) => asyncValue.value?.gameLobbySpots[gameName] ?? []));
    final youAreAssigned = squadSpots.contains(yourName);
    // Placeholder for peacockTimers and peacockQueue - need to implement

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
                      if (youAreAssigned) {
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

  static Widget _buildPeacockStatus(BuildContext context, WidgetRef ref) {
    // Placeholder implementation - need to implement peacock status
    return const Text('Open', style: TextStyle(color: Colors.white));
  }

  static Widget buildPeacockMembersList(BuildContext context, WidgetRef ref,
      Function(String, bool) togglePeacockMember) {
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
                  children: [].map((game) {
                    // squadState.availableGames
                    final gameName = game['name'] as String;
                    const isPreferred =
                        false; // squadState.preferredPeacockGames.contains(gameName)
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
            itemBuilder: (context, index) => Container(),
          ),
        ],
      ),
    );
  }
}
