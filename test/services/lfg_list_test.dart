import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/data/repositories/matchmaking_queue_repository.dart';
import 'package:squad_sync/services/matchmaking_queue_machine.dart';

class _MemoryQueueRepo implements MatchmakingQueueRepository {
  _MemoryQueueRepo({this.onFetch});

  final Map<String, MatchmakingQueueEntry> rows =
      <String, MatchmakingQueueEntry>{};
  final StreamController<MatchmakingQueueChange> controller =
      StreamController<MatchmakingQueueChange>.broadcast();
  Future<Map<String, MatchmakingQueueEntry>> Function()? onFetch;

  @override
  Future<void> upsert(String userId, MatchmakingQueueEntry entry) async {
    rows[userId] = entry;
  }

  @override
  Future<void> remove(String userId) async {
    rows.remove(userId);
  }

  @override
  Future<Map<String, MatchmakingQueueEntry>> fetchActive() {
    if (onFetch != null) return onFetch!();
    return Future.value(Map<String, MatchmakingQueueEntry>.from(rows));
  }

  @override
  Stream<MatchmakingQueueChange> watch() => controller.stream;

  @override
  Future<void> dispose() async {
    await controller.close();
  }
}

void main() {
  group('resolveLfgListPhase', () {
    test('hydrating with no rows is reconnecting, not a settled empty', () {
      expect(
        resolveLfgListPhase(
          isHydrating: true,
          isHydrated: false,
          lookingCount: 0,
        ),
        LfgListPhase.loading,
      );
    });

    test('hydrated empty list is empty copy', () {
      expect(
        resolveLfgListPhase(
          isHydrating: false,
          isHydrated: true,
          lookingCount: 0,
        ),
        LfgListPhase.empty,
      );
    });

    test('never-hydrated idle is empty, not a dead reconnecting spinner', () {
      expect(
        resolveLfgListPhase(
          isHydrating: false,
          isHydrated: false,
          lookingCount: 0,
        ),
        LfgListPhase.empty,
      );
    });

    test('error with no rows is error', () {
      expect(
        resolveLfgListPhase(
          isHydrating: false,
          isHydrated: false,
          error: 'offline',
          lookingCount: 0,
        ),
        LfgListPhase.error,
      );
      expect(
        resolveLfgListPhase(
          isHydrating: false,
          isHydrated: false,
          isOffline: true,
          lookingCount: 0,
        ),
        LfgListPhase.error,
      );
    });

    test('error or stale with looking rows is stale, not empty', () {
      expect(
        resolveLfgListPhase(
          isHydrating: false,
          isHydrated: true,
          error: 'timeout',
          lookingCount: 2,
        ),
        LfgListPhase.stale,
      );
      expect(
        resolveLfgListPhase(
          isHydrating: false,
          isHydrated: true,
          isStale: true,
          lookingCount: 1,
        ),
        LfgListPhase.stale,
      );
    });

    test('stale empty stays empty', () {
      expect(
        resolveLfgListPhase(
          isHydrating: false,
          isHydrated: true,
          isStale: true,
          lookingCount: 0,
        ),
        LfgListPhase.empty,
      );
    });

    test('Realtime disconnect of empty queue stays empty, not error', () {
      expect(
        resolveLfgListPhase(
          isHydrating: false,
          isHydrated: true,
          isRealtimeDisconnected: true,
          lookingCount: 0,
        ),
        LfgListPhase.empty,
      );
    });

    test('Realtime disconnect with looking rows is stale, not empty', () {
      expect(
        resolveLfgListPhase(
          isHydrating: false,
          isHydrated: true,
          isRealtimeDisconnected: true,
          lookingCount: 1,
        ),
        LfgListPhase.stale,
      );
    });

    test('hydrating after disconnect of empty queue is reconnecting', () {
      expect(
        resolveLfgListPhase(
          isHydrating: true,
          isHydrated: true,
          isRealtimeDisconnected: true,
          lookingCount: 0,
        ),
        LfgListPhase.loading,
      );
    });

    test('looking rows are data', () {
      expect(
        resolveLfgListPhase(
          isHydrating: false,
          isHydrated: true,
          lookingCount: 3,
        ),
        LfgListPhase.data,
      );
    });
  });

  group('lfg list copy', () {
    test('empty / error / stale / reconnecting copy is arm length', () {
      expect(lfgListMessage(LfgListPhase.empty), kLfgListEmptyCopy);
      expect(lfgListHint(LfgListPhase.empty), kLfgListEmptyHint);
      expect(lfgListMessage(LfgListPhase.error), kLfgListErrorCopy);
      expect(lfgListHint(LfgListPhase.error), kLfgListErrorHint);
      expect(lfgListMessage(LfgListPhase.stale), kLfgListStaleCopy);
      expect(lfgListHint(LfgListPhase.stale), kLfgListStaleHint);
      expect(
        lfgListMessage(LfgListPhase.loading),
        kLfgListReconnectingCopy,
      );
      expect(lfgListHint(LfgListPhase.loading), isNull);
      expect(lfgListMessage(LfgListPhase.data, lookingCount: 1), '1 looking');
      expect(lfgListMessage(LfgListPhase.data, lookingCount: 3), '3 looking');
    });
  });

  group('resolveLfgList', () {
    test('maps looking snapshot and drops idle / matched', () {
      final view = resolveLfgList(
        snapshot: {
          'u-look': const MatchmakingQueueEntry(
            phase: MatchmakingQueuePhase.looking,
          ),
          'u-idle': MatchmakingQueueEntry.idle,
          'u-match': const MatchmakingQueueEntry(
            phase: MatchmakingQueuePhase.matched,
            lobbyId: 'lobby-1',
          ),
        },
        isHydrating: false,
        isHydrated: true,
      );
      expect(view.phase, LfgListPhase.data);
      expect(view.lookingUserIds, ['u-look']);
    });

    test('hydrate error with a cached looking row is stale', () {
      final view = resolveLfgList(
        snapshot: {
          'u-look': const MatchmakingQueueEntry(
            phase: MatchmakingQueuePhase.looking,
          ),
        },
        isHydrating: false,
        isHydrated: true,
        error: 'timeout',
      );
      expect(view.phase, LfgListPhase.stale);
      expect(view.lookingUserIds, ['u-look']);
    });

    test('matched-only snapshot after last dequeue is empty, not data', () {
      final view = resolveLfgList(
        snapshot: {
          'u-match': const MatchmakingQueueEntry(
            phase: MatchmakingQueuePhase.matched,
            lobbyId: 'lobby-9',
          ),
        },
        isHydrating: false,
        isHydrated: true,
      );
      expect(view.phase, LfgListPhase.empty);
      expect(view.lookingUserIds, isEmpty);
      expect(lfgListMessage(view.phase), kLfgListEmptyCopy);
    });

    test('empty snapshot after stale cleanup is empty, not stale', () {
      final view = resolveLfgList(
        snapshot: const {},
        isHydrating: false,
        isHydrated: true,
        isStale: true,
      );
      expect(view.phase, LfgListPhase.empty);
      expect(lfgListHint(view.phase), kLfgListEmptyHint);
    });
  });

  group('MatchmakingQueueTracker hydrate', () {
    test('fetch failure surfaces hydrateError and is not hydrated', () async {
      final repo = _MemoryQueueRepo(
        onFetch: () async => throw Exception('offline'),
      );
      addTearDown(repo.dispose);
      final tracker = MatchmakingQueueTracker(repository: repo);

      await tracker.hydrateFromRepository();

      expect(tracker.isHydrated, isFalse);
      expect(tracker.isHydrating, isFalse);
      expect(tracker.hydrateError.toString(), contains('offline'));
      expect(
        resolveLfgListFromTracker(tracker).phase,
        LfgListPhase.error,
      );
    });

    test('force re-hydrate recovers after a failed fetch', () async {
      var fail = true;
      final repo = _MemoryQueueRepo(
        onFetch: () async {
          if (fail) throw Exception('offline');
          return {
            'u-look': const MatchmakingQueueEntry(
              phase: MatchmakingQueuePhase.looking,
            ),
          };
        },
      );
      addTearDown(repo.dispose);
      final tracker = MatchmakingQueueTracker(repository: repo);

      await tracker.hydrateFromRepository();
      expect(tracker.hydrateError, isNotNull);

      fail = false;
      await tracker.hydrateFromRepository(force: true);
      expect(tracker.isHydrated, isTrue);
      expect(tracker.hydrateError, isNull);
      expect(tracker.lookingUserIds, ['u-look']);
      expect(
        resolveLfgListFromTracker(tracker).phase,
        LfgListPhase.data,
      );
    });
  });
}
