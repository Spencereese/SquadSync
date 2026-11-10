import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squadsync/core/dependencies.dart';
import 'package:squadsync/core/repository_failure.dart';
import 'package:squadsync/features/spot/data/spot_repository.dart';
import 'package:squadsync/features/spot/domain/spot_call.dart';

/// One line for the live spot call, plus In, Out, and Lock.
class SpotStrip extends ConsumerStatefulWidget {
  const SpotStrip({
    required this.squadId,
    required this.meId,
    required this.canLock,
    super.key,
  });

  final String squadId;
  final String meId;
  final bool canLock;

  @override
  ConsumerState<SpotStrip> createState() => _SpotStripState();
}

class _SpotStripState extends ConsumerState<SpotStrip> {
  SpotCall? _call;
  var _missing = false;
  String? _error;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_load()));
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

  Future<void> _load() async {
    try {
      final call = await ref
          .read(spotRepositoryProvider)
          .load(squadId: widget.squadId);
      if (!mounted) return;
      setState(() {
        _call = call;
        _missing = false;
        _error = null;
      });
    } on SpotNotEnabled {
      if (!mounted) return;
      setState(() => _missing = true);
    } on RepositoryFailure catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_missing) {
      return const Text(
        'Spots are not enabled yet.',
        key: Key('spot-disabled'),
      );
    }
    final clock = ref.watch(squadClockProvider).now();
    final call = _call;
    final phase = call?.phaseAt(clock);
    final mayLock =
        call != null && (widget.canLock || call.callerId == widget.meId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          spotStatusLine(call: call, clock: clock),
          key: const Key('spot-status'),
        ),
        if (_error != null) Text(_error!, key: const Key('spot-error')),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (call == null)
              _SpotButton(
                label: 'Call a spot',
                buttonKey: const Key('spot-call'),
                onPressed: _callSpot,
              ),
            if (call != null && phase != SpotPhase.locked)
              _SpotButton(
                label: 'In',
                buttonKey: const Key('spot-in'),
                onPressed: () => _rsvp(SpotAnswer.rsvpIn),
              ),
            if (call != null && phase != SpotPhase.locked)
              _SpotButton(
                label: 'Out',
                buttonKey: const Key('spot-out'),
                onPressed: () => _rsvp(SpotAnswer.rsvpOut),
              ),
            if (mayLock && phase != SpotPhase.locked)
              _SpotButton(
                label: 'Lock',
                buttonKey: const Key('spot-lock'),
                onPressed: _lock,
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _callSpot() async {
    try {
      final call = await ref
          .read(spotRepositoryProvider)
          .callSpot(
            squadId: widget.squadId,
            game: 'Halo',
            startsAt: ref.read(squadClockProvider).now(),
          );
      if (!mounted) return;
      setState(() {
        _call = call;
        _error = null;
      });
    } on RepositoryFailure catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    }
  }

  Future<void> _rsvp(SpotAnswer answer) async {
    final call = _call;
    if (call == null) return;
    try {
      await ref
          .read(spotRepositoryProvider)
          .rsvp(callId: call.id, answer: answer);
      await _load();
    } on RepositoryFailure catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    }
  }

  Future<void> _lock() async {
    final call = _call;
    if (call == null) return;
    try {
      await ref.read(spotRepositoryProvider).lock(callId: call.id);
      await _load();
    } on RepositoryFailure catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    }
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
  final VoidCallback onPressed;

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
