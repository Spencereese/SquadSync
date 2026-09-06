import 'dart:async';

import 'package:flutter/material.dart';

import '../services/matchmaking_queue_machine.dart';

SnackBar lfgReconnectSnackBar() {
  return const SnackBar(
    key: Key(kLfgReconnectToastKey),
    content: Text(kLfgListReconnectingCopy),
    duration: Duration(seconds: 2),
    behavior: SnackBarBehavior.floating,
  );
}

/// Live LFG queue status: resume resubscribe, reconnect toast, disconnect
/// cleanup. Never [startLooking] on resume.
class LfgQueueStatusHost extends StatefulWidget {
  const LfgQueueStatusHost({
    super.key,
    required this.tracker,
    this.onRetry,
  });

  /// Widget tests leave a pending [Timer] if this is true. Production
  /// keeps it on so last-known looking drops when the timeout elapses.
  static bool scheduleDisconnectCleanup = true;

  final MatchmakingQueueTracker tracker;
  final VoidCallback? onRetry;

  @override
  State<LfgQueueStatusHost> createState() => _LfgQueueStatusHostState();
}

class _LfgQueueStatusHostState extends State<LfgQueueStatusHost>
    with WidgetsBindingObserver {
  LfgListPhase? _lastPhase;
  Timer? _disconnectTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _disconnectTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_resume());
    }
  }

  Future<void> _resume() async {
    await widget.tracker.resumeQueue();
    if (mounted) setState(() {});
  }

  void _scheduleDisconnectCleanup(DateTime? disconnectedAt) {
    if (!LfgQueueStatusHost.scheduleDisconnectCleanup) return;
    if (disconnectedAt == null) {
      _disconnectTimer?.cancel();
      _disconnectTimer = null;
      return;
    }
    if (_disconnectTimer != null) return;
    _disconnectTimer = Timer(kLfgDisconnectStaleAfter, () {
      if (!mounted) return;
      final since = widget.tracker.realtimeDisconnectedAt;
      widget.tracker.cleanupAfterDisconnect(
        now: (since ?? DateTime.now().toUtc()).add(kLfgDisconnectStaleAfter),
      );
      if (mounted) setState(() {});
    });
  }

  void _maybeReconnectToast({
    required LfgListPhase? previous,
    required LfgListPhase current,
    required bool realtimeReconnect,
  }) {
    if (!shouldShowLfgReconnectToast(
      previous: previous,
      current: current,
      realtimeReconnect: realtimeReconnect,
    )) {
      return;
    }
    if (!lfgReconnectToastGate.claim(now: DateTime.now().toUtc())) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;
      messenger.showSnackBar(lfgReconnectSnackBar());
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.tracker,
      builder: (context, _) {
        final view = resolveLfgListFromTracker(widget.tracker);
        final previous = _lastPhase;
        _lastPhase = view.phase;
        _scheduleDisconnectCleanup(widget.tracker.realtimeDisconnectedAt);
        _maybeReconnectToast(
          previous: previous,
          current: view.phase,
          realtimeReconnect: widget.tracker.isReconnecting,
        );
        return LfgQueueStatusRow(
          view: view,
          onRetry: widget.onRetry ??
              () => unawaited(widget.tracker.resumeQueue()),
        );
      },
    );
  }
}

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
