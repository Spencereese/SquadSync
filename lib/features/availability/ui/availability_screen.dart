import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squadsync/core/dependencies.dart';
import 'package:squadsync/features/availability/domain/availability_board.dart';
import 'package:squadsync/features/availability/domain/check_in.dart';
import 'package:squadsync/features/availability/ui/availability_controller.dart';
import 'package:squadsync/features/squad/domain/squad.dart';

/// Who is free, from self check-ins only. Being on this screen is not a status.
class AvailabilityScreen extends ConsumerStatefulWidget {
  const AvailabilityScreen({
    required this.squad,
    required this.meId,
    this.demo = false,
    super.key,
  });

  final Squad squad;
  final String meId;
  final bool demo;

  @override
  ConsumerState<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends ConsumerState<AvailabilityScreen>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final tick = ref.read(availabilityTickProvider);
      if (tick > Duration.zero) {
        _timer = Timer.periodic(tick, (_) {
          if (!mounted) return;
          ref.read(availabilityControllerProvider.notifier).reevaluate();
        });
      }
      unawaited(
        ref
            .read(availabilityControllerProvider.notifier)
            .open(squad: widget.squad, meId: widget.meId),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    ref.read(availabilityControllerProvider.notifier).reevaluate();
    unawaited(ref.read(availabilityControllerProvider.notifier).refresh());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(availabilityControllerProvider);
    final offset = ref.watch(localOffsetProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.demo ? "Who's free (demo)" : "Who's free"),
        actions: [
          IconButton(
            key: const Key('availability-refresh'),
            tooltip: 'Refresh check-ins',
            onPressed: state.loading || state.saving
                ? null
                : () {
                    unawaited(
                      ref
                          .read(availabilityControllerProvider.notifier)
                          .refresh(),
                    );
                  },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _body(state, offset),
    );
  }

  Widget _body(AvailabilityState state, Duration offset) {
    if (state.notEnabled) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Availability is not enabled on this project yet.',
            key: Key('availability-disabled'),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (state.loading || state.board == null && state.error == null) {
      return const Center(
        child: CircularProgressIndicator(key: Key('availability-loading')),
      );
    }
    final board = state.board;
    if (board == null) {
      return _Failure(
        message: state.error ?? 'Could not load check-ins.',
        onRetry: () {
          unawaited(ref.read(availabilityControllerProvider.notifier).retry());
        },
      );
    }
    final me = board.person(widget.meId);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (widget.demo) const _DemoBanner(),
        if (state.stale) const _StaleBanner(),
        Text(
          'Being in the app is not the same as being available.',
          key: const Key('availability-not-presence'),
        ),
        const SizedBox(height: 12),
        Semantics(
          liveRegion: true,
          child: Text(
            '${board.availableNowCount} available now',
            key: const Key('available-now-count'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        Text(
          '${board.laterCount} available later',
          key: const Key('available-later-count'),
        ),
        const SizedBox(height: 16),
        Text('Your check-in', key: const Key('my-availability')),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(
              key: const Key('check-in-now'),
              onPressed: state.saving
                  ? null
                  : () => _save(const CheckInDraft.now()),
              child: const Text('Available now'),
            ),
            FilledButton.tonal(
              key: const Key('check-in-later'),
              onPressed: state.saving ? null : _pickLater,
              child: const Text('Available later'),
            ),
            FilledButton.tonal(
              key: const Key('check-in-unavailable'),
              onPressed: state.saving
                  ? null
                  : () => _save(const CheckInDraft.unavailable()),
              child: const Text('Unavailable'),
            ),
            if (me?.checkIn != null)
              OutlinedButton(
                key: const Key('check-in-clear'),
                onPressed: state.saving
                    ? null
                    : () {
                        unawaited(
                          ref
                              .read(availabilityControllerProvider.notifier)
                              .clear(),
                        );
                      },
                child: const Text('Clear check-in'),
              ),
          ],
        ),
        if (state.error != null) ...[
          const SizedBox(height: 12),
          Text(
            state.error!,
            key: const Key('availability-error'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          TextButton(
            key: const Key('availability-retry'),
            onPressed: state.saving
                ? null
                : () {
                    unawaited(
                      ref.read(availabilityControllerProvider.notifier).retry(),
                    );
                  },
            child: const Text('Retry'),
          ),
        ],
        const SizedBox(height: 16),
        for (final person in board.people) ...[
          Text(
            person.displayName,
            key: Key('availability-${person.userId}'),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(availabilitySentence(person, localOffset: offset)),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  void _save(CheckInDraft draft) {
    unawaited(ref.read(availabilityControllerProvider.notifier).save(draft));
  }

  Future<void> _pickLater() async {
    final until = await showDialog<DateTime>(
      context: context,
      builder: (context) => const LaterTimeDialog(),
    );
    if (until == null || !mounted) return;
    _save(CheckInDraft.later(until));
  }
}

class _DemoBanner extends StatelessWidget {
  const _DemoBanner();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Material(
        color: Color(0xFFFFF3CD),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            'Demo. Not connected. Check-ins stay on this phone.',
            key: Key('availability-demo'),
          ),
        ),
      ),
    );
  }
}

class _StaleBanner extends StatelessWidget {
  const _StaleBanner();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Text(
        'Showing the last check-ins. The refresh failed, so this list may be old. '
        'A saved time can still expire.',
        key: Key('availability-stale'),
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              key: const Key('availability-error'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('availability-retry'),
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Picks a real local time. Confirming the shown time is the check-in.
class LaterTimeDialog extends ConsumerStatefulWidget {
  const LaterTimeDialog({super.key});

  @override
  ConsumerState<LaterTimeDialog> createState() => _LaterTimeDialogState();
}

class _LaterTimeDialogState extends ConsumerState<LaterTimeDialog> {
  late DateTime _day;
  late int _hour12;
  late int _minute;
  late bool _pm;
  String? _error;

  @override
  void initState() {
    super.initState();
    final offset = ref.read(localOffsetProvider);
    final suggested = suggestLaterUtc(
      ref.read(squadClockProvider).now(),
      offset,
    );
    final wall = suggested.add(offset);
    _day = DateTime.utc(wall.year, wall.month, wall.day);
    final hour24 = wall.hour;
    _pm = hour24 >= 12;
    _hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    _minute = wall.minute;
  }

  @override
  Widget build(BuildContext context) {
    final offset = ref.watch(localOffsetProvider);
    final clock = ref.watch(squadClockProvider).now();
    final days = _days(clock, offset);
    final preview = localSelectionToUtc(
      localDay: _day,
      hour12: _hour12,
      minute: _minute,
      pm: _pm,
      localOffset: offset,
    );
    return AlertDialog(
      key: const Key('later-dialog'),
      title: const Text('Available later'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Choose when you expect to be free. '
              'This does not mark you available now when that time comes.',
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<DateTime>(
              key: const Key('later-day'),
              initialValue: _day,
              decoration: const InputDecoration(labelText: 'Day'),
              items: [
                for (final day in days)
                  DropdownMenuItem(
                    value: day,
                    child: Text(formatLocalDay(day, Duration.zero)),
                  ),
              ],
              onChanged: (day) {
                if (day == null) return;
                setState(() => _day = day);
              },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              key: const Key('later-hour'),
              initialValue: _hour12,
              decoration: const InputDecoration(labelText: 'Hour'),
              items: [
                for (var hour = 1; hour <= 12; hour++)
                  DropdownMenuItem(
                    value: hour,
                    child: Text('$hour', key: Key('later-hour-$hour')),
                  ),
              ],
              onChanged: (hour) {
                if (hour == null) return;
                setState(() => _hour12 = hour);
              },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              key: const Key('later-minute'),
              initialValue: _minute - (_minute % 5),
              decoration: const InputDecoration(labelText: 'Minute'),
              items: [
                for (var minute = 0; minute < 60; minute += 5)
                  DropdownMenuItem(
                    value: minute,
                    child: Text(
                      minute.toString().padLeft(2, '0'),
                      key: Key('later-minute-$minute'),
                    ),
                  ),
              ],
              onChanged: (minute) {
                if (minute == null) return;
                setState(() => _minute = minute);
              },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<bool>(
              key: const Key('later-period'),
              initialValue: _pm,
              decoration: const InputDecoration(labelText: 'AM or PM'),
              items: const [
                DropdownMenuItem(value: false, child: Text('AM')),
                DropdownMenuItem(value: true, child: Text('PM')),
              ],
              onChanged: (pm) {
                if (pm == null) return;
                setState(() => _pm = pm);
              },
            ),
            const SizedBox(height: 12),
            Text(
              formatLocalDateTime(preview, offset),
              key: const Key('later-preview'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                key: const Key('later-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('later-save'),
          onPressed: () {
            final problem = rejectLater(
              ref.read(squadClockProvider).now(),
              preview,
            );
            if (problem != null) {
              setState(() => _error = problem);
              return;
            }
            Navigator.pop(context, preview);
          },
          child: const Text('Use this time'),
        ),
      ],
    );
  }

  List<DateTime> _days(DateTime clock, Duration offset) {
    final wall = clock.toUtc().add(offset);
    final start = DateTime.utc(wall.year, wall.month, wall.day);
    return [for (var day = 0; day <= 7; day++) start.add(Duration(days: day))];
  }
}
