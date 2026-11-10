import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squadsync/core/dependencies.dart';
import 'package:squadsync/core/repository_failure.dart';
import 'package:squadsync/features/availability/data/availability_repository.dart';
import 'package:squadsync/features/availability/domain/availability_board.dart';
import 'package:squadsync/features/availability/domain/check_in.dart';
import 'package:squadsync/features/squad/domain/squad.dart';

/// A save or clear that failed and can be sent again.
class PendingCheckIn {
  const PendingCheckIn.save(this.draft) : clear = false;

  const PendingCheckIn.clear() : draft = null, clear = true;

  final CheckInDraft? draft;
  final bool clear;
}

class AvailabilityState {
  const AvailabilityState({
    this.squad,
    this.meId,
    this.rows = const [],
    this.evaluatedAt,
    this.loading = false,
    this.saving = false,
    this.error,
    this.notEnabled = false,
    this.stale = false,
    this.pending,
  });

  final Squad? squad;
  final String? meId;
  final List<StoredCheckIn> rows;
  final DateTime? evaluatedAt;
  final bool loading;
  final bool saving;
  final String? error;
  final bool notEnabled;
  final bool stale;
  final PendingCheckIn? pending;

  /// Null while loading, after a first-load failure, or when the table
  /// is not enabled. A zero count is only shown from a real board.
  AvailabilityBoard? get board {
    final squad = this.squad;
    final at = evaluatedAt;
    if (notEnabled || squad == null || at == null) return null;
    return AvailabilityBoard.compose(
      members: squad.members,
      rows: rows,
      squadId: squad.id,
      clock: at,
    );
  }

  AvailabilityState copyWith({
    Squad? squad,
    String? meId,
    List<StoredCheckIn>? rows,
    DateTime? evaluatedAt,
    bool? loading,
    bool? saving,
    String? error,
    bool clearError = false,
    bool? notEnabled,
    bool? stale,
    PendingCheckIn? pending,
    bool clearPending = false,
  }) {
    return AvailabilityState(
      squad: squad ?? this.squad,
      meId: meId ?? this.meId,
      rows: rows ?? this.rows,
      evaluatedAt: evaluatedAt ?? this.evaluatedAt,
      loading: loading ?? this.loading,
      saving: saving ?? this.saving,
      error: clearError ? null : (error ?? this.error),
      notEnabled: notEnabled ?? this.notEnabled,
      stale: stale ?? this.stale,
      pending: clearPending ? null : (pending ?? this.pending),
    );
  }
}

final availabilityControllerProvider =
    NotifierProvider<AvailabilityController, AvailabilityState>(
      AvailabilityController.new,
    );

class AvailabilityController extends Notifier<AvailabilityState> {
  var _generation = 0;
  StreamSubscription<void>? _live;

  @override
  AvailabilityState build() {
    ref.onDispose(() {
      final live = _live;
      _live = null;
      if (live != null) unawaited(live.cancel());
    });
    return const AvailabilityState();
  }

  Future<void> open({required Squad squad, required String meId}) async {
    final samePerson =
        state.meId == meId &&
        state.squad?.id == squad.id &&
        state.evaluatedAt != null &&
        !state.notEnabled;
    final generation = ++_generation;
    state = AvailabilityState(
      squad: squad,
      meId: meId,
      rows: samePerson ? state.rows : const [],
      evaluatedAt: samePerson ? state.evaluatedAt : null,
      loading: !samePerson,
    );
    _listen(squad.id);
    await _fetch(generation, refreshing: samePerson);
  }

  void _listen(String squadId) {
    final previous = _live;
    _live = ref
        .read(availabilityRepositoryProvider)
        .watch(squadId: squadId)
        .listen((_) => unawaited(refresh()), onError: (_, _) {});
    if (previous != null) unawaited(previous.cancel());
  }

  Future<void> refresh() async {
    final squad = state.squad;
    final meId = state.meId;
    if (squad == null || meId == null) return;
    await open(squad: squad, meId: meId);
  }

  void reevaluate() {
    if (state.notEnabled || state.evaluatedAt == null) return;
    final now = ref.read(squadClockProvider).now().toUtc();
    if (!now.isAfter(state.evaluatedAt!)) return;
    state = state.copyWith(evaluatedAt: now);
  }

  Future<void> save(CheckInDraft draft) async {
    final squad = state.squad;
    if (squad == null || state.notEnabled || state.saving) return;
    if (draft.kind == CheckInKind.availableLater) {
      final until = draft.until;
      final problem = until == null
          ? 'Pick a time at least a minute from now. Nothing was saved.'
          : rejectLater(ref.read(squadClockProvider).now(), until);
      if (problem != null) {
        state = state.copyWith(error: problem, saving: false);
        return;
      }
    }
    final generation = _generation;
    state = state.copyWith(
      saving: true,
      clearError: true,
      pending: PendingCheckIn.save(draft),
    );
    await _write(generation, () async {
      final saved = await ref
          .read(availabilityRepositoryProvider)
          .save(squadId: squad.id, draft: draft);
      final meId = state.meId;
      final next = [
        for (final row in state.rows)
          if (row.userId != meId) row,
        saved,
      ];
      state = state.copyWith(
        rows: next,
        evaluatedAt: ref.read(squadClockProvider).now().toUtc(),
        saving: false,
        clearError: true,
        clearPending: true,
        stale: false,
        loading: false,
      );
    });
  }

  Future<void> clear() async {
    final squad = state.squad;
    final meId = state.meId;
    if (squad == null || meId == null || state.notEnabled || state.saving) {
      return;
    }
    final generation = _generation;
    state = state.copyWith(
      saving: true,
      clearError: true,
      pending: const PendingCheckIn.clear(),
    );
    await _write(generation, () async {
      await ref.read(availabilityRepositoryProvider).clear(squadId: squad.id);
      state = state.copyWith(
        rows: [
          for (final row in state.rows)
            if (row.userId != meId) row,
        ],
        evaluatedAt: ref.read(squadClockProvider).now().toUtc(),
        saving: false,
        clearError: true,
        clearPending: true,
        stale: false,
        loading: false,
      );
    });
  }

  Future<void> retry() async {
    final pending = state.pending;
    if (pending == null) {
      await refresh();
      return;
    }
    if (pending.clear) {
      await clear();
      return;
    }
    final draft = pending.draft;
    if (draft == null) return;
    await save(draft);
  }

  Future<void> _fetch(int generation, {required bool refreshing}) async {
    final squad = state.squad;
    final meId = state.meId;
    if (squad == null || meId == null) return;
    try {
      final rows = await ref
          .read(availabilityRepositoryProvider)
          .load(squadId: squad.id);
      if (generation != _generation || !ref.mounted) return;
      state = AvailabilityState(
        squad: squad,
        meId: meId,
        rows: rows,
        evaluatedAt: ref.read(squadClockProvider).now().toUtc(),
      );
    } on AvailabilityNotEnabled {
      if (generation != _generation || !ref.mounted) return;
      state = AvailabilityState(squad: squad, meId: meId, notEnabled: true);
    } on RepositoryFailure catch (error) {
      if (generation != _generation || !ref.mounted) return;
      if (refreshing && state.evaluatedAt != null) {
        state = state.copyWith(
          loading: false,
          saving: false,
          stale: true,
          error: error.message,
        );
        return;
      }
      state = AvailabilityState(squad: squad, meId: meId, error: error.message);
    }
  }

  Future<void> _write(int generation, Future<void> Function() action) async {
    try {
      await action();
    } on AvailabilityNotEnabled {
      if (generation != _generation || !ref.mounted) return;
      state = AvailabilityState(
        squad: state.squad,
        meId: state.meId,
        notEnabled: true,
      );
    } on RepositoryFailure catch (error) {
      if (generation != _generation || !ref.mounted) return;
      state = state.copyWith(saving: false, error: error.message);
    }
  }
}
