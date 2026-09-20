import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/notifiers/lobby_notifier.dart' as ln;
import '../services/lobby_seat_status.dart';
import '../services/peacock_assignment_machine.dart';
import '../services/timer_service.dart';
import 'widgets/lobby_seat_affordance.dart';

class SpotTimerDisplay extends ConsumerStatefulWidget {
  final int index;

  const SpotTimerDisplay({
    super.key,
    required this.index,
  });

  @override
  ConsumerState<SpotTimerDisplay> createState() => _SpotTimerDisplayState();
}

class _SpotTimerDisplayState extends ConsumerState<SpotTimerDisplay> {
  bool _hasExpired = false;

  @override
  Widget build(BuildContext context) {
    final squadAsync = ref.watch(ln.lobbyNotifierProvider);

    if (!squadAsync.hasValue) {
      return const SizedBox(
        width: 60,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    final squadState = squadAsync.value!;
    final gameName = squadState.currentGame?['name'] ?? '';

    final timerService = ref.watch(timerServiceProvider.notifier);
    final spots = squadState.gameLobbySpots[gameName] ?? [];
    final uid = spots.length > widget.index && spots[widget.index] != null
        ? spots[widget.index]!
        : '';
    final timerKey = 'spot_${gameName}_$uid';
    final stream = uid.isNotEmpty
        ? timerService.observeTimer(timerKey)
        : Stream.value(Duration.zero);

    return StreamBuilder<Duration>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const SizedBox(
            width: 60,
            height: 20,
            child: Icon(Icons.error, size: 16),
          );
        }

        final duration = snapshot.data ?? Duration.zero;
        final progress = const Duration(minutes: 5).inSeconds > 0
            ? duration.inSeconds / const Duration(minutes: 5).inSeconds
            : 0.0;
        final queueAssigned = uid.isNotEmpty &&
            peacockPhaseIsAssigned(
              PeacockAssignmentTracker.instance.stateFor(
                uid.replaceAll('_calling', ''),
              ),
            );

        // Haptic feedback on expiration. Server still assigns via
        // process_expired_timers; this is display only.
        if (duration == Duration.zero && !_hasExpired) {
          _hasExpired = true;
          HapticFeedback.vibrate();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Spot timer expired!')),
            );
          }
        } else if (duration > Duration.zero) {
          _hasExpired = false;
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LockTimerReadout(
              remaining: duration,
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
