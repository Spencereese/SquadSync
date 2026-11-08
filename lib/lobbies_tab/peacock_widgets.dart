import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/notifiers/lobby_notifier.dart' as ln;
import '../services/lobby_seat_status.dart';
import '../services/peacock_assignment_machine.dart';
import '../services/preferred_peacock_games.dart';
import 'widgets/lobby_seat_affordance.dart';

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

        final queueAssigned = peacockPhaseIsAssigned(
          PeacockAssignmentTracker.instance.stateFor(widget.player),
        );

        // Haptic feedback on expiration. Server still assigns via
        // process_expired_timers; this is display only.
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
            LockTimerReadout(
              remaining: interpolated,
              queueAssigned: queueAssigned,
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
          const PreferredPeacockGamesSection(),
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

/// Existing Preferred Peacock Games chips. Persist + filter only.
class PreferredPeacockGamesSection extends ConsumerWidget {
  const PreferredPeacockGamesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final squadState = ref.watch(ln.lobbyNotifierProvider).valueOrNull;
    final games = preferredPeacockGameChoices(squadState);
    final preferred = resolvedPreferredPeacockGames(squadState);
    final store = PreferredPeacockGamesStore.instance;
    final offers = PeacockAssignmentTracker.instance.snapshot.values
        .where((state) => state.phase != PeacockAssignmentPhase.idle)
        .map((state) => state.gameName);
    final filter = mapPreferredPeacockFilter(
      preferredPeacockGames: preferred,
      offerGameNames: offers,
      error: store.lastError,
    );
    return PreferredPeacockGamesChips(
      games: games,
      preferred: preferred,
      filter: filter,
      onRetry: () {
        ref
            .read(ln.lobbyNotifierProvider.notifier)
            .retryPreferredPeacockGames();
      },
      onToggle: (gameName) {
        ref
            .read(ln.lobbyNotifierProvider.notifier)
            .togglePreferredPeacockGame(gameName);
      },
    );
  }
}

class PreferredPeacockGamesChips extends StatelessWidget {
  const PreferredPeacockGamesChips({
    super.key,
    required this.games,
    required this.preferred,
    required this.onToggle,
    this.filter,
    this.error,
    this.offerGameNames = const [],
    this.onRetry,
  });

  static const titleLabel = kPreferredPeacockGamesTitle;
  static const emptyLabel = kPreferredPeacockFilterNoCatalogCopy;

  final List<String> games;
  final Set<String> preferred;
  final ValueChanged<String> onToggle;
  final PreferredPeacockFilterResult? filter;
  final Object? error;
  final Iterable<String?> offerGameNames;
  final VoidCallback? onRetry;

  PreferredPeacockFilterResult get _filter =>
      filter ??
      mapPreferredPeacockFilter(
        preferredPeacockGames: preferred,
        offerGameNames: offerGameNames,
        error: error,
      );

  @override
  Widget build(BuildContext context) {
    final mapped = _filter;
    final theme = Theme.of(context);
    final failed = mapped.isFailed;
    final statusColor = failed ? theme.colorScheme.error : Colors.white70;
    return Container(
      key: const Key('preferred-peacock-games'),
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            titleLabel,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.cyanAccent,
            ),
          ),
          const SizedBox(height: 8),
          if (failed) ...[
            _PreferredPeacockFilterStatus(
              result: mapped,
              color: statusColor,
              onRetry: onRetry,
            ),
            if (games.isNotEmpty) const SizedBox(height: 8),
          ] else if (games.isEmpty)
            const Text(
              emptyLabel,
              key: Key('preferred-peacock-games-empty'),
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          if (games.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              children: [
                for (final gameName in games)
                  FilterChip(
                    key: Key('preferred-peacock-game-$gameName'),
                    label: Text(gameName),
                    selected: preferred.contains(gameName),
                    onSelected: (_) => onToggle(gameName),
                    backgroundColor: Colors.grey[800],
                    selectedColor: Colors.cyanAccent.withValues(alpha: 0.3),
                    checkmarkColor: Colors.cyanAccent,
                  ),
              ],
            ),
            if (!failed && mapped.isEmpty) ...[
              const SizedBox(height: 8),
              _PreferredPeacockFilterStatus(
                result: mapped,
                color: statusColor,
                onRetry: onRetry,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _PreferredPeacockFilterStatus extends StatelessWidget {
  const _PreferredPeacockFilterStatus({
    required this.result,
    required this.color,
    this.onRetry,
  });

  final PreferredPeacockFilterResult result;
  final Color color;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final hint = preferredPeacockFilterHint(result);
    final detail =
        result.isFailed ? preferredPeacockFilterErrorDetail(result.error) : '';
    final showRetry = result.isFailed && onRetry != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          preferredPeacockFilterMessage(result),
          key: preferredPeacockFilterKey(result),
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (hint != null && hint.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            hint,
            key: preferredPeacockFilterHintKey(result),
            style: TextStyle(
              color: color.withValues(alpha: 0.85),
              fontSize: 12,
            ),
          ),
        ],
        if (detail.isNotEmpty &&
            detail != preferredPeacockFilterMessage(result)) ...[
          const SizedBox(height: 2),
          Text(
            detail,
            key: preferredPeacockFilterDetailKey(),
            style: TextStyle(
              color: color.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
        ],
        if (showRetry)
          TextButton(
            key: preferredPeacockFilterRetryKey(),
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: color,
              minimumSize: const Size(88, 44),
              padding: EdgeInsets.zero,
              alignment: Alignment.centerLeft,
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: const Text(kPreferredPeacockFilterRetryLabel),
          ),
      ],
    );
  }
}
