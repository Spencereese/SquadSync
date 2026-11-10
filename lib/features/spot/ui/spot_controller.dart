import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squadsync/core/dependencies.dart';
import 'package:squadsync/core/repository_failure.dart';
import 'package:squadsync/features/spot/data/spot_repository.dart';
import 'package:squadsync/features/spot/domain/spot_call.dart';

class SpotHomeState {
  const SpotHomeState({
    this.call,
    this.missing = false,
    this.error,
    this.rsvpClosed = false,
  });

  final SpotCall? call;
  final bool missing;
  final String? error;
  final bool rsvpClosed;

  SpotHomeState copyWith({
    SpotCall? call,
    bool clearCall = false,
    bool? missing,
    String? error,
    bool clearError = false,
    bool? rsvpClosed,
  }) {
    return SpotHomeState(
      call: clearCall ? null : (call ?? this.call),
      missing: missing ?? this.missing,
      error: clearError ? null : (error ?? this.error),
      rsvpClosed: rsvpClosed ?? this.rsvpClosed,
    );
  }
}

class SpotHomeController extends Notifier<SpotHomeState> {
  StreamSubscription<SpotChange>? _live;
  String? _squadId;
  var _generation = 0;
  var _serverClosed = false;

  @override
  SpotHomeState build() {
    ref.onDispose(() {
      final live = _live;
      _live = null;
      if (live != null) unawaited(live.cancel());
    });
    return const SpotHomeState();
  }

  Future<void> open(String squadId) async {
    _squadId = squadId;
    _listen(squadId);
    await _load();
  }

  Future<void> refresh() async {
    if (_squadId == null) return;
    await _load();
  }

  Future<void> callSpot({required String game, required DateTime startsAt}) {
    final squadId = _squadId;
    if (squadId == null) return Future<void>.value();
    return _guard(() async {
      await ref
          .read(spotRepositoryProvider)
          .callSpot(squadId: squadId, game: game, startsAt: startsAt);
    });
  }

  Future<void> rsvp(SpotAnswer answer) {
    final call = state.call;
    if (call == null) return Future<void>.value();
    return _guard(() async {
      await ref
          .read(spotRepositoryProvider)
          .rsvp(callId: call.id, answer: answer);
    });
  }

  Future<void> lock() {
    final call = state.call;
    if (call == null) return Future<void>.value();
    return _guard(() async {
      await ref.read(spotRepositoryProvider).lock(callId: call.id);
    });
  }

  Future<void> end() {
    final call = state.call;
    if (call == null) return Future<void>.value();
    return _guard(() async {
      await ref.read(spotRepositoryProvider).end(callId: call.id);
    });
  }

  Future<void> cancel() {
    final call = state.call;
    if (call == null) return Future<void>.value();
    return _guard(() async {
      await ref.read(spotRepositoryProvider).cancel(callId: call.id);
    });
  }

  void _listen(String squadId) {
    final previous = _live;
    _live = ref.read(spotRepositoryProvider).watch(squadId: squadId).listen((
      change,
    ) {
      if (!reloadAfterSpotEvent(knownCallId: state.call?.id, change: change)) {
        return;
      }
      unawaited(refresh());
    }, onError: (_, _) {});
    if (previous != null) unawaited(previous.cancel());
  }

  Future<void> _guard(Future<void> Function() body) async {
    try {
      await body();
      _serverClosed = false;
      await _load();
    } on RepositoryFailure catch (error) {
      final blocks = spotRsvpClosedByServer(error.code);
      if (blocks) _serverClosed = true;
      state = state.copyWith(
        error: error.message,
        rsvpClosed: state.rsvpClosed || blocks,
      );
    }
  }

  Future<void> _load() async {
    final squadId = _squadId;
    if (squadId == null) return;
    final generation = ++_generation;
    try {
      final call = await ref
          .read(spotRepositoryProvider)
          .load(squadId: squadId);
      if (generation != _generation) return;
      final clock = ref.read(squadClockProvider).now();
      state = SpotHomeState(call: call, rsvpClosed: _rsvpClosed(call, clock));
    } on SpotNotEnabled {
      if (generation != _generation) return;
      state = const SpotHomeState(missing: true);
    } on RepositoryFailure catch (error) {
      if (generation != _generation) return;
      state = state.copyWith(error: error.message);
    }
  }

  bool _rsvpClosed(SpotCall? call, DateTime clock) {
    if (call == null) {
      _serverClosed = false;
      return false;
    }
    if (call.phaseAt(clock) == SpotPhase.locked || call.inCount >= 8) {
      return true;
    }
    if (_serverClosed && call.phaseAt(clock) != SpotPhase.open) return true;
    _serverClosed = false;
    return false;
  }
}

final spotHomeProvider = NotifierProvider<SpotHomeController, SpotHomeState>(
  SpotHomeController.new,
);
