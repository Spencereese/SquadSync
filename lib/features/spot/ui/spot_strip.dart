import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squadsync/core/dependencies.dart';
import 'package:squadsync/features/spot/domain/spot_call.dart';
import 'package:squadsync/features/spot/ui/spot_controller.dart';
import 'package:squadsync/features/squad/domain/member.dart';

/// One line for the live spot call, plus In, Out, Lock, Cancel, and End.
/// The message list is not in this strip. Nothing here has a fixed height.
class SpotStrip extends ConsumerStatefulWidget {
  const SpotStrip({
    required this.squadId,
    required this.meId,
    required this.canLock,
    required this.members,
    super.key,
  });

  final String squadId;
  final String meId;
  final bool canLock;
  final List<Member> members;

  @override
  ConsumerState<SpotStrip> createState() => _SpotStripState();
}

class _SpotStripState extends ConsumerState<SpotStrip> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(spotHomeProvider.notifier).open(widget.squadId));
    });
    final tick = ref.read(availabilityTickProvider);
    if (tick > Duration.zero) {
      _tick = Timer.periodic(tick, (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final home = ref.watch(spotHomeProvider);
    if (home.missing) {
      return const Text(
        'Spots are not enabled yet.',
        key: Key('spot-disabled'),
      );
    }
    final clock = ref.watch(squadClockProvider).now();
    final call = home.call;
    final phase = call?.phaseAt(clock);
    final locked = phase == SpotPhase.locked;
    final mayLock =
        call != null && (widget.canLock || call.callerId == widget.meId);
    final mayCancel = call != null && !locked && call.callerId == widget.meId;
    final rsvpEnabled = call != null && !locked && !home.rsvpClosed;
    final names = call == null
        ? const <String>[]
        : spotInNames(
            call: call,
            namesById: {
              for (final member in widget.members)
                member.id: member.displayName,
            },
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          spotStatusLine(call: call, clock: clock),
          key: const Key('spot-status'),
        ),
        if (home.error != null) Text(home.error!, key: const Key('spot-error')),
        if (locked)
          Semantics(
            label: names.isEmpty ? 'Nobody is in' : 'In: ${names.join(', ')}',
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < names.length; i++)
                  Text(names[i], key: Key('spot-in-name-$i')),
              ],
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (call == null)
              _SpotButton(
                label: 'Call a spot',
                buttonKey: const Key('spot-call'),
                onPressed: () {
                  unawaited(
                    ref
                        .read(spotHomeProvider.notifier)
                        .callSpot(
                          game: 'Halo',
                          startsAt: ref.read(squadClockProvider).now(),
                        ),
                  );
                },
              ),
            if (call != null && !locked)
              _SpotButton(
                label: 'In',
                buttonKey: const Key('spot-in'),
                onPressed: rsvpEnabled
                    ? () => unawaited(
                        ref
                            .read(spotHomeProvider.notifier)
                            .rsvp(SpotAnswer.rsvpIn),
                      )
                    : null,
              ),
            if (call != null && !locked)
              _SpotButton(
                label: 'Out',
                buttonKey: const Key('spot-out'),
                onPressed: rsvpEnabled
                    ? () => unawaited(
                        ref
                            .read(spotHomeProvider.notifier)
                            .rsvp(SpotAnswer.rsvpOut),
                      )
                    : null,
              ),
            if (mayLock && !locked)
              _SpotButton(
                label: 'Lock',
                buttonKey: const Key('spot-lock'),
                onPressed: () {
                  unawaited(ref.read(spotHomeProvider.notifier).lock());
                },
              ),
            if (mayCancel)
              _SpotButton(
                label: 'Cancel',
                buttonKey: const Key('spot-cancel'),
                onPressed: () => unawaited(_confirmCancel()),
              ),
            if (locked && mayLock)
              _SpotButton(
                label: 'End',
                buttonKey: const Key('spot-end'),
                onPressed: () => unawaited(_confirmEnd()),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _confirmCancel() async {
    final confirmed = await _confirm(
      title: 'Cancel this spot?',
      body: 'The join window closes and you can call another.',
      action: 'Cancel spot',
      actionKey: const Key('spot-cancel-confirm'),
    );
    if (!confirmed || !mounted) return;
    await ref.read(spotHomeProvider.notifier).cancel();
  }

  Future<void> _confirmEnd() async {
    final confirmed = await _confirm(
      title: 'End this spot?',
      body: 'Everyone leaves this call. You can start another.',
      action: 'End spot',
      actionKey: const Key('spot-end-confirm'),
    );
    if (!confirmed || !mounted) return;
    await ref.read(spotHomeProvider.notifier).end();
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String action,
    required Key actionKey,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep it'),
            ),
            TextButton(
              key: actionKey,
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(action),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }
}

class _SpotButton extends StatelessWidget {
  const _SpotButton({
    required this.label,
    required this.buttonKey,
    required this.onPressed,
  });

  final String label;
  final Key buttonKey;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      key: buttonKey,
      style: FilledButton.styleFrom(minimumSize: const Size(44, 44)),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}
