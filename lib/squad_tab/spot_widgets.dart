import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../squad_state.dart';
import '../services/timer_service.dart';

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
  Duration? _totalDuration;
  bool _hasExpired = false;

  @override
  void didUpdateWidget(SpotTimerDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateTotalDuration();
  }

  void _updateTotalDuration() {
    final squadState = ref.watch(squadStateNotifierProvider);
    final gameName = squadState.currentGame?['name'] ?? '';
    final gameSpotTimers = squadState.gameSpotTimers[gameName] ?? [];
    final timer = gameSpotTimers.length > widget.index
        ? gameSpotTimers[widget.index]
        : null;
    if (timer != null) {
      _totalDuration = Duration(seconds: timer['duration'] as int? ?? 0);
    } else {
      _totalDuration = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final squadState = ref.watch(squadStateNotifierProvider);
    final gameName = squadState.currentGame?['name'] ?? '';
    final key = 'spot_${gameName}_${widget.index}';
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
        final progress = _totalDuration != null && _totalDuration!.inSeconds > 0
            ? remaining.inSeconds / _totalDuration!.inSeconds
            : 0.0;

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
