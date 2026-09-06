import 'package:flutter/material.dart';

import '../services/matchmaking_queue_machine.dart';

/// Compact empty / error / stale / reconnecting copy under Looking for Squad.
/// Never paints a spinner — reconnecting is copy, not a hung indicator.
class LfgQueueStatusRow extends StatelessWidget {
  const LfgQueueStatusRow({
    super.key,
    required this.view,
    this.onRetry,
    this.message,
    this.hint,
  });

  final LfgListView view;
  final VoidCallback? onRetry;
  final String? message;
  final String? hint;

  bool get _showRetry =>
      onRetry != null &&
      (view.phase == LfgListPhase.error || view.phase == LfgListPhase.stale);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final phase = view.phase;
    final text = message ??
        lfgListMessage(phase, lookingCount: view.lookingCount);
    final resolvedHint = hint ?? lfgListHint(phase);
    final color = switch (phase) {
      LfgListPhase.error => theme.colorScheme.error,
      LfgListPhase.stale => Colors.amberAccent,
      LfgListPhase.loading => Colors.lightBlueAccent,
      LfgListPhase.empty => theme.colorScheme.onSurface.withValues(alpha: 0.72),
      LfgListPhase.data => theme.colorScheme.onSurface.withValues(alpha: 0.7),
    };

    return Padding(
      key: lfgListKey(phase),
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          if (resolvedHint != null && resolvedHint.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              resolvedHint,
              key: phase == LfgListPhase.error
                  ? const Key('lfg-queue-error-hint')
                  : phase == LfgListPhase.empty
                      ? const Key('lfg-queue-empty-hint')
                      : const Key('lfg-queue-stale-hint'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.3,
                color: color.withValues(alpha: 0.85),
              ),
            ),
          ],
          if (_showRetry)
            TextButton(
              key: const Key('lfg-queue-retry'),
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: color,
                minimumSize: const Size(88, 44),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }
}
