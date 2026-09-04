import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/data/repositories/matchmaking_queue_repository.dart';
import 'package:squad_sync/services/matchmaking_queue_machine.dart';
import 'package:squad_sync/services/peacock_assignment_machine.dart';

class _MemoryQueueRepo implements MatchmakingQueueRepository {
  final Map<String, MatchmakingQueueEntry> rows =
      <String, MatchmakingQueueEntry>{};
  final StreamController<MatchmakingQueueChange> controller =
      StreamController<MatchmakingQueueChange>.broadcast();

  @override
  Future<void> upsert(String userId, MatchmakingQueueEntry entry) async {
    if (entry.phase == MatchmakingQueuePhase.idle) {
      await remove(userId);
      return;
    }
    final stamped = entry.queuedAt == null
        ? entry.copyWith(queuedAt: DateTime.now().toUtc())
        : entry;
    rows[userId] = stamped;
    controller.add(MatchmakingQueueChange(userId: userId, entry: stamped));
  }

  @override
  Future<void> remove(String userId) async {
    rows.remove(userId);
    controller.add(MatchmakingQueueChange(userId: userId));
  }

  @override
  Future<Map<String, MatchmakingQueueEntry>> fetchActive() async {
    final ordered = rows.entries.toList()
      ..sort((a, b) {
        final at = a.value.queuedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bt = b.value.queuedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return at.compareTo(bt);
      });
    return Map<String, MatchmakingQueueEntry>.fromEntries(ordered);
  }

  @override
  Stream<MatchmakingQueueChange> watch() => controller.stream;

  @override
  Future<void> dispose() async {
    await controller.close();
  }
}

void main() {
  late MatchmakingQueueTracker tracker;
  late PeacockAssignmentTracker peacock;

  setUp(() {
    peacock = PeacockAssignmentTracker();
    tracker = MatchmakingQueueTracker(peacock: peacock);
    MatchmakingQueueTracker.resetInstance();
    PeacockAssignmentTracker.resetInstance();
  });

  tearDown(() {
    MatchmakingQueueTracker.resetInstance();
    PeacockAssignmentTracker.resetInstance();
  });

  group('MatchmakingQueueTracker', () {
    test('startLooking then cancelLooking is idle', () {
      tracker.startLooking('u1', squadId: 'squad-1');
      expect(tracker.stateFor('u1').phase, MatchmakingQueuePhase.looking);
      tracker.cancelLooking('u1');
      expect(tracker.stateFor('u1').phase, MatchmakingQueuePhase.idle);
      expect(tracker.snapshot.containsKey('u1'), isFalse);
    });

    test('tracks users independently', () {
      tracker.startLooking('u1');
      tracker.startLooking('u2');
      tracker.matchFound('u1', lobbyId: 'lobby-9', notificationId: 'n1');
      expect(tracker.stateFor('u1').phase, MatchmakingQueuePhase.matched);
      expect(tracker.stateFor('u2').phase, MatchmakingQueuePhase.looking);
    });

    test('startLookingAfter reduces only after remote success', () async {
      var wrote = false;
      final next = await tracker.startLookingAfter(
        () async {
          wrote = true;
        },
        userId: 'u1',
        squadId: 'squad-1',
      );
      expect(wrote, isTrue);
      expect(next.phase, MatchmakingQueuePhase.looking);
      expect(tracker.stateFor('u1').squadId, 'squad-1');
    });

    test('startLookingAfter does not look when remote write fails', () async {
      await expectLater(
        tracker.startLookingAfter(
          () async {
            throw Exception('notify down');
          },
          userId: 'u1',
        ),
        throwsA(isA<Exception>()),
      );
      expect(tracker.stateFor('u1').phase, MatchmakingQueuePhase.idle);
      expect(tracker.snapshot.containsKey('u1'), isFalse);
    });

    test('cancelLookingAfter stays looking when remote write fails', () async {
      tracker.startLooking('u1');
      await expectLater(
        tracker.cancelLookingAfter(
          () async {
            throw Exception('cancel down');
          },
          userId: 'u1',
        ),
        throwsA(isA<Exception>()),
      );
      expect(tracker.stateFor('u1').phase, MatchmakingQueuePhase.looking);
    });

    test('processQueue with lobby matches FIFO looking user', () {
      tracker.startLooking('u1');
      tracker.startLooking('u2');
      final matched = tracker.processQueue(
        lobbyId: 'lobby-9',
        gameName: 'Warzone',
      );
      expect(matched, ['u1']);
      expect(tracker.stateFor('u1').phase, MatchmakingQueuePhase.matched);
      expect(tracker.stateFor('u1').lobbyId, 'lobby-9');
      expect(tracker.stateFor('u1').gameName, 'Warzone');
      expect(tracker.stateFor('u2').phase, MatchmakingQueuePhase.looking);
      expect(tracker.nextLookingUserId(), 'u2');
    });

    test('processQueue without lobby pairs two looking users', () {
      tracker.startLooking('u1');
      tracker.startLooking('u2');
      tracker.startLooking('u3');
      final matched = tracker.processQueue();
      expect(matched, ['u1', 'u2']);
      expect(tracker.stateFor('u1').matchedUserId, 'u2');
      expect(tracker.stateFor('u2').matchedUserId, 'u1');
      expect(tracker.stateFor('u1').hasJoinTarget, isFalse);
      expect(tracker.stateFor('u3').phase, MatchmakingQueuePhase.looking);
    });

    test('processQueue with no looking users is empty', () {
      expect(tracker.processQueue(lobbyId: 'lobby-9'), isEmpty);
      expect(tracker.processQueue(), isEmpty);
    });

    test('joinMatched with lobby hands off to peacock assignSpot', () {
      tracker.startLooking('u1');
      tracker.matchFound(
        'u1',
        lobbyId: 'lobby-9',
        gameName: 'Warzone',
        notificationId: 'n1',
      );
      final handoff = tracker.joinMatched('u1');
      expect(handoff.state.phase, MatchmakingQueuePhase.joined);
      expect(handoff.handedOffToPeacock, isTrue);
      expect(handoff.peacockState?.phase, PeacockAssignmentPhase.assigned);
      expect(handoff.peacockState?.lobbyId, 'lobby-9');
      expect(handoff.peacockState?.gameName, 'Warzone');
      expect(handoff.peacockState?.notificationId, 'n1');
      expect(peacock.stateFor('u1').phase, PeacockAssignmentPhase.assigned);
      expect(peacock.stateFor('u1').showedLocal, isFalse);
      expect(peacock.stateFor('u1').sentFcmToSelf, isFalse);
      expect(peacock.stateFor('u1').wouldDoubleNotifySelf, isFalse);
    });

    test('joinMatched without lobby does not peacock-assign', () {
      tracker.startLooking('u1');
      tracker.startLooking('u2');
      tracker.processQueue();
      final handoff = tracker.joinMatched('u1');
      expect(handoff.state.phase, MatchmakingQueuePhase.joined);
      expect(handoff.handedOffToPeacock, isFalse);
      expect(peacock.stateFor('u1').phase, PeacockAssignmentPhase.idle);
    });

    test('joinMatched from looking is a no-op and does not peacock-assign', () {
      tracker.startLooking('u1');
      final handoff = tracker.joinMatched('u1');
      expect(handoff.state.phase, MatchmakingQueuePhase.looking);
      expect(handoff.handedOffToPeacock, isFalse);
      expect(peacock.stateFor('u1').phase, PeacockAssignmentPhase.idle);
    });

    test('joinMatched does not call peacock notifySelf (no parallel XOR)', () {
      tracker.startLooking('u1');
      tracker.matchFound('u1', lobbyId: 'lobby-9', notificationId: 'n1');
      tracker.joinMatched('u1');
      expect(peacock.stateFor('u1').phase, PeacockAssignmentPhase.assigned);
      expect(peacock.stateFor('u1').showedLocal, isFalse);
      expect(peacock.stateFor('u1').sentFcmToSelf, isFalse);
    });

    test('joinMatched with handoffToPeacock false is phase-only', () {
      tracker.startLooking('u1');
      tracker.matchFound(
        'u1',
        lobbyId: 'lobby-9',
        gameName: 'Warzone',
        notificationId: 'n1',
      );
      final handoff = tracker.joinMatched('u1', handoffToPeacock: false);
      expect(handoff.state.phase, MatchmakingQueuePhase.joined);
      expect(handoff.handedOffToPeacock, isFalse);
      expect(handoff.peacockState, isNull);
      expect(peacock.stateFor('u1').phase, PeacockAssignmentPhase.idle);
    });

    test('joinMatched skips assignSpot when peacock already assigned', () {
      tracker.startLooking('u1');
      tracker.matchFound(
        'u1',
        lobbyId: 'lobby-9',
        gameName: 'Warzone',
        notificationId: 'n1',
      );
      peacock.assignSpot(
        'u1',
        lobbyId: 'lobby-9',
        gameName: 'Warzone',
        notificationId: 'n1',
      );
      final handoff = tracker.joinMatched('u1');
      expect(handoff.state.phase, MatchmakingQueuePhase.joined);
      expect(handoff.handedOffToPeacock, isTrue);
      expect(handoff.peacockState?.phase, PeacockAssignmentPhase.assigned);
      expect(handoff.peacockState?.lobbyId, 'lobby-9');
      expect(peacock.stateFor('u1').phase, PeacockAssignmentPhase.assigned);
      expect(peacock.stateFor('u1').notificationId, 'n1');
      expect(peacock.stateFor('u1').showedLocal, isFalse);
      expect(peacock.stateFor('u1').sentFcmToSelf, isFalse);
    });

    test('nextLookingUserId is FIFO among looking users', () {
      tracker.startLooking('u1');
      tracker.startLooking('u2');
      tracker.matchFound('u1', lobbyId: 'lobby-9');
      expect(tracker.nextLookingUserId(), 'u2');
      tracker.expire('u1');
      expect(tracker.nextLookingUserId(), 'u2');
      tracker.cancelLooking('u2');
      expect(tracker.nextLookingUserId(), isNull);
    });

    test('expire returns idle and drops the user', () {
      tracker.startLooking('u1');
      tracker.matchFound('u1', lobbyId: 'lobby-9');
      tracker.joinMatched('u1');
      tracker.expire('u1');
      expect(tracker.stateFor('u1').phase, MatchmakingQueuePhase.idle);
      expect(tracker.snapshot.containsKey('u1'), isFalse);
    });

    test('production singleton is shared across reset until resetInstance', () {
      MatchmakingQueueTracker.instance.startLooking('u1');
      expect(
        MatchmakingQueueTracker.instance.stateFor('u1').phase,
        MatchmakingQueuePhase.looking,
      );
      MatchmakingQueueTracker.resetInstance();
      expect(
        MatchmakingQueueTracker.instance.stateFor('u1').phase,
        MatchmakingQueuePhase.idle,
      );
    });
  });

  group('persist + hydrate (app kill)', () {
    late _MemoryQueueRepo repo;

    setUp(() {
      repo = _MemoryQueueRepo();
      tracker = MatchmakingQueueTracker(peacock: peacock, repository: repo);
    });

    tearDown(() async {
      await repo.dispose();
    });

    test('startLookingAfter writes looking; new tracker hydrates it', () async {
      await tracker.startLookingAfter(
        () async {},
        userId: 'u1',
        squadId: 'squad-1',
        gameName: 'Warzone',
      );
      expect(repo.rows['u1']?.phase, MatchmakingQueuePhase.looking);
      expect(repo.rows['u1']?.squadId, 'squad-1');

      final revived = MatchmakingQueueTracker(
        peacock: peacock,
        repository: repo,
      );
      expect(revived.stateFor('u1').phase, MatchmakingQueuePhase.idle);
      await revived.hydrateFromRepository();
      expect(revived.stateFor('u1').phase, MatchmakingQueuePhase.looking);
      expect(revived.stateFor('u1').squadId, 'squad-1');
      expect(revived.stateFor('u1').gameName, 'Warzone');
      expect(peacock.stateFor('u1').phase, PeacockAssignmentPhase.idle);
    });

    test('cancelLookingAfter removes the persisted row', () async {
      await tracker.startLookingAfter(() async {}, userId: 'u1');
      await tracker.cancelLookingAfter(() async {}, userId: 'u1');
      expect(repo.rows.containsKey('u1'), isFalse);

      final revived = MatchmakingQueueTracker(repository: repo);
      await revived.hydrateFromRepository();
      expect(revived.stateFor('u1').phase, MatchmakingQueuePhase.idle);
    });

    test('Realtime applyRemote does not peacock-assign', () {
      tracker.applyRemote(
        'u1',
        const MatchmakingQueueEntry(
          phase: MatchmakingQueuePhase.matched,
          lobbyId: 'lobby-9',
          gameName: 'Warzone',
          notificationId: 'n1',
        ),
      );
      expect(tracker.stateFor('u1').phase, MatchmakingQueuePhase.matched);
      expect(tracker.stateFor('u1').lobbyId, 'lobby-9');
      expect(peacock.stateFor('u1').phase, PeacockAssignmentPhase.idle);
      expect(peacock.stateFor('u1').showedLocal, isFalse);
      expect(peacock.stateFor('u1').sentFcmToSelf, isFalse);
    });

    test('processQueueAndPersist writes matched rows', () async {
      tracker.startLooking('u1');
      tracker.startLooking('u2');
      final matched = await tracker.processQueueAndPersist(
        lobbyId: 'lobby-9',
        gameName: 'Warzone',
        lobbyHasFreeSeat: true,
      );
      expect(matched, ['u1']);
      expect(repo.rows['u1']?.phase, MatchmakingQueuePhase.matched);
      expect(repo.rows['u1']?.lobbyId, 'lobby-9');
      expect(repo.rows['u2']?.phase, MatchmakingQueuePhase.looking);
    });
  });

  group('lobby-aware processQueue', () {
    test('full lobby pairs looking users instead of seating', () {
      tracker.startLooking('u1');
      tracker.startLooking('u2');
      final matched = tracker.processQueue(
        lobbyId: 'lobby-9',
        gameName: 'Warzone',
        lobbyHasFreeSeat: false,
      );
      expect(matched, ['u1', 'u2']);
      expect(tracker.stateFor('u1').lobbyId, isNull);
      expect(tracker.stateFor('u1').matchedUserId, 'u2');
      expect(tracker.stateFor('u2').matchedUserId, 'u1');
      expect(peacock.stateFor('u1').phase, PeacockAssignmentPhase.idle);
    });

    test('free seat matches FIFO looking user into the lobby', () {
      tracker.startLooking('u1');
      tracker.startLooking('u2');
      final matched = tracker.processQueue(
        lobbyId: 'lobby-9',
        gameName: 'Warzone',
        lobbyHasFreeSeat: true,
      );
      expect(matched, ['u1']);
      expect(tracker.stateFor('u1').lobbyId, 'lobby-9');
      expect(tracker.stateFor('u2').phase, MatchmakingQueuePhase.looking);
    });

    test('lobbyHasFreeSeatForMatchmaking subtracts reserved matches', () {
      expect(
        lobbyHasFreeSeatForMatchmaking(
          spots: [null, null],
          maxSpots: 2,
          alreadyMatchedToLobby: 0,
        ),
        isTrue,
      );
      expect(
        lobbyHasFreeSeatForMatchmaking(
          spots: [null, null],
          maxSpots: 2,
          alreadyMatchedToLobby: 2,
        ),
        isFalse,
      );
      expect(
        countFreeLobbySpots(['taken', null, ''], maxSpots: 3),
        2,
      );
    });

    test('FIFO uses queuedAt after hydrate', () async {
      final repo = _MemoryQueueRepo();
      addTearDown(repo.dispose);
      final older = MatchmakingQueueEntry(
        phase: MatchmakingQueuePhase.looking,
        queuedAt: DateTime.utc(2026, 9, 3, 10),
      );
      final newer = MatchmakingQueueEntry(
        phase: MatchmakingQueuePhase.looking,
        queuedAt: DateTime.utc(2026, 9, 3, 11),
      );
      await repo.upsert('u-new', newer);
      await repo.upsert('u-old', older);
      final hydrated = MatchmakingQueueTracker(
        peacock: peacock,
        repository: repo,
      );
      await hydrated.hydrateFromRepository();
      expect(hydrated.nextLookingUserId(), 'u-old');
      hydrated.processQueue(lobbyId: 'lobby-9', lobbyHasFreeSeat: true);
      expect(hydrated.stateFor('u-old').lobbyId, 'lobby-9');
      expect(hydrated.stateFor('u-new').phase, MatchmakingQueuePhase.looking);
    });
  });
}
