import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squad_sync/presentation/notifiers/lobby_notifier.dart' as ln;

/// Badge showing win/loss record for a lobby
///
/// Displays stats like "10-5" (wins-losses) or "Win Rate: 66.7%"
/// Updates in real-time as matches are recorded
class MatchHistoryBadge extends ConsumerWidget {
  final String lobbyId;
  final bool showWinRate;

  const MatchHistoryBadge({
    super.key,
    required this.lobbyId,
    this.showWinRate = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<Map<String, dynamic>>(
      future:
          ref.read(ln.lobbyNotifierProvider.notifier).getLobbyStats(lobbyId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final stats = snapshot.data!;
        final wins = stats['wins'] ?? 0;
        final losses = stats['losses'] ?? 0;
        final totalMatches = stats['total_matches'] ?? 0;

        // Don't show badge if no matches yet
        if (totalMatches == 0) {
          return const SizedBox.shrink();
        }

        final theme = Theme.of(context);
        final winRate = totalMatches > 0 ? (wins / totalMatches * 100) : 0.0;

        // Determine badge color based on win rate
        Color badgeColor;
        if (winRate >= 60) {
          badgeColor = Colors.green.withValues(alpha: 0.2);
        } else if (winRate >= 40) {
          badgeColor = Colors.orange.withValues(alpha: 0.2);
        } else {
          badgeColor = Colors.red.withValues(alpha: 0.2);
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: badgeColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.bar_chart,
                size: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 4),
              Text(
                showWinRate
                    ? '${winRate.toStringAsFixed(0)}% WR'
                    : '$wins-$losses',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
