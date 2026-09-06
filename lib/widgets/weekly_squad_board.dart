import 'package:flutter/material.dart';
import 'package:squad_sync/services/session_rating_machine.dart';
import 'package:squad_sync/services/weekly_squad_board.dart';

/// Weekly nights / lock-in / comms / vibes from `match_history`. Used on
/// You and Stats. No CoD API.
class WeeklySquadBoardView extends StatelessWidget {
  const WeeklySquadBoardView({
    super.key,
    required this.board,
    this.emptyMessage = kWeeklySquadBoardEmptyCopy,
    this.emptyHint = kWeeklySquadBoardEmptyHint,
    this.errorMessage,
    this.onRetry,
  });

  final WeeklySquadBoard board;
  final String emptyMessage;
  final String emptyHint;
  final String? errorMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (errorMessage != null) {
      return _WeeklyBoardStatus(
        key: const Key('weekly-squad-board-error'),
        icon: Icons.error_outline,
        message: errorMessage!,
        hint: kStatsLoadErrorBody,
        actionLabel: onRetry == null ? null : kStatsLoadErrorRetryLabel,
        actionKey: const Key('weekly-squad-board-retry'),
        onAction: onRetry,
      );
    }
    if (board.isEmpty) {
      return _WeeklyBoardStatus(
        key: const Key('weekly-squad-board-empty'),
        icon: Icons.calendar_today_outlined,
        message: emptyMessage,
        hint: emptyHint,
      );
    }

    return Column(
      key: const Key('weekly-squad-board'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _WeeklyStatTile(
                key: const Key('weekly-squad-nights'),
                label: 'Nights',
                value: '${board.nightsPlayed}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _WeeklyStatTile(
                key: const Key('weekly-squad-lock-in'),
                label: 'Lock-in',
                value: weeklySquadBoardLockInLabel(board.lockInRate),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _WeeklyStatTile(
                key: const Key('weekly-squad-comms'),
                label: 'Comms',
                value: weeklySquadBoardScoreLabel(board.commsAverage),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _WeeklyStatTile(
                key: const Key('weekly-squad-vibes'),
                label: 'Vibes',
                value: weeklySquadBoardScoreLabel(board.vibesAverage),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _WeeklyStatTile(
                key: const Key('weekly-squad-gunny'),
                label: 'Gunny',
                value: weeklySquadBoardScoreLabel(board.gunnyAverage),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _WeeklyStatTile(
                key: const Key('weekly-squad-wingman'),
                label: 'Wingman',
                value: weeklySquadBoardScoreLabel(board.wingmanAverage),
              ),
            ),
          ],
        ),
        if (board.rows.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (var i = 0; i < board.rows.length; i++)
            Padding(
              key: Key('weekly-squad-row-$i'),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                weeklySquadBoardRowLabel(board.rows[i]),
                style: const TextStyle(color: Colors.white70, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ],
    );
  }
}

class _WeeklyStatTile extends StatelessWidget {
  const _WeeklyStatTile({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.cyanAccent,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// You (Profile) weekly board. [board] comes from [statsDashboardProvider].
class YouWeeklySquadBoard extends StatelessWidget {
  const YouWeeklySquadBoard({
    super.key,
    required this.board,
    this.errorMessage,
    this.onRetry,
  });

  final WeeklySquadBoard board;
  final String? errorMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      key: const Key('you-weekly-squad-board'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'THIS WEEK',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: primary,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          WeeklySquadBoardView(
            board: board,
            errorMessage: errorMessage,
            onRetry: onRetry,
          ),
        ],
      ),
    );
  }
}

class _WeeklyBoardStatus extends StatelessWidget {
  const _WeeklyBoardStatus({
    super.key,
    required this.icon,
    required this.message,
    this.hint,
    this.actionLabel,
    this.actionKey,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? hint;
  final String? actionLabel;
  final Key? actionKey;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Icon(icon, color: Colors.white24, size: 28),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          if (hint != null && hint!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              hint!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 8),
            TextButton(
              key: actionKey,
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
