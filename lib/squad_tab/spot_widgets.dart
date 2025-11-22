import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/squad_notifier.dart';

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
  Duration _lastDuration = Duration.zero;
  DateTime _lastUpdateTime = DateTime.now();
  bool _hasExpired = false;

  @override
  void initState() {
    super.initState();
    // Listen to stream updates for interpolation
    ref.listen(spotTimerStreamProvider('', 0), (previous, next) {
      // We can't use the parameters here because the provider is family
      // Instead, we'll update in build
    });
  }

  Duration _getInterpolatedDuration() {
    final elapsed = DateTime.now().difference(_lastUpdateTime);
    final interpolated = _lastDuration - elapsed;
    return interpolated.isNegative ? Duration.zero : interpolated;
  }

  @override
  Widget build(BuildContext context) {
    final squadAsync = ref.watch(squadNotifierProvider);

    if (!squadAsync.hasValue) {
      return const SizedBox(
        width: 60,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    final squadState = squadAsync.value!;
    final gameName = squadState.currentGame?['name'] ?? '';

    // Get total duration from gameSpotTimers
    final gameSpotTimers = squadState.gameSpotTimers[gameName] ?? [];
    final timerData = gameSpotTimers.length > widget.index ? gameSpotTimers[widget.index] : null;
    final totalDuration = timerData != null ? Duration(seconds: timerData['duration'] as int? ?? 0) : Duration.zero;

    final timerStateAsync = ref.watch(spotTimerStateProvider(gameName, widget.index));

    // Watch the stream for interpolation updates
    final streamAsync = ref.watch(spotTimerStreamProvider(gameName, widget.index));
    if (streamAsync.hasValue) {
      _lastDuration = streamAsync.value!;
      _lastUpdateTime = DateTime.now();
    }

    return timerStateAsync.when(
      data: (timerData) {
        final interpolated = _getInterpolatedDuration();
        final progress = totalDuration.inSeconds > 0
            ? interpolated.inSeconds / totalDuration.inSeconds
            : 0.0;

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
              const SnackBar(content: Text('Spot timer expired!')),
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
