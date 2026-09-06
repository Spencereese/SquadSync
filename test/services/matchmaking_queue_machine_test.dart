import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/services/matchmaking_queue_machine.dart';

void main() {
  group('matchmaking product phases', () {
    test('idle → looking on startLooking', () {
      final next = reduceMatchmakingQueue(
        current: MatchmakingQueueEntry.idle,
        event: MatchmakingQueueEvent.startLooking,
        squadId: 'squad-1',
        gameName: 'Warzone',
      );
      expect(next.phase, MatchmakingQueuePhase.looking);
      expect(next.squadId, 'squad-1');
      expect(next.gameName, 'Warzone');
      expect(next.routeLocation, isNull);
      expect(next.hasJoinTarget, isFalse);
    });

    test('looking → idle on cancelLooking', () {
      final looking = reduceMatchmakingQueue(
        current: MatchmakingQueueEntry.idle,
        event: MatchmakingQueueEvent.startLooking,
      );
      final next = reduceMatchmakingQueue(
        current: looking,
        event: MatchmakingQueueEvent.cancelLooking,
      );
      expect(next.phase, MatchmakingQueuePhase.idle);
      expect(next.lobbyId, isNull);
    });

    test('startLooking while looking is idempotent', () {
      const looking = MatchmakingQueueEntry(
        phase: MatchmakingQueuePhase.looking,
        squadId: 'squad-1',
      );
      final next = reduceMatchmakingQueue(
        current: looking,
        event: MatchmakingQueueEvent.startLooking,
        squadId: 'other',
      );
      expect(next.phase, MatchmakingQueuePhase.looking);
      expect(next.squadId, 'squad-1');
    });

    test('looking → matched on matchFound with lobby', () {
      final queuedAt = DateTime.utc(2026, 9, 6, 12);
      final looking = MatchmakingQueueEntry(
        phase: MatchmakingQueuePhase.looking,
        squadId: 'squad-1',
        queuedAt: queuedAt,
      );
      final next = reduceMatchmakingQueue(
        current: looking,
        event: MatchmakingQueueEvent.matchFound,
        lobbyId: 'lobby-9',
        gameName: 'Warzone',
        matchedUserId: 'u2',
        notificationId: 'n1',
      );
      expect(next.phase, MatchmakingQueuePhase.matched);
      expect(next.lobbyId, 'lobby-9');
      expect(next.gameName, 'Warzone');
      expect(next.matchedUserId, 'u2');
      expect(next.notificationId, 'n1');
      expect(next.queuedAt, queuedAt);
      expect(next.hasJoinTarget, isTrue);
      expect(next.routeLocation, '/squad/Warzone?lobby_id=lobby-9');
    });

    test('idle can match directly (skip looking)', () {
      final next = reduceMatchmakingQueue(
        current: MatchmakingQueueEntry.idle,
        event: MatchmakingQueueEvent.matchFound,
        lobbyId: 'lobby-9',
        notificationId: 'n1',
      );
      expect(next.phase, MatchmakingQueuePhase.matched);
      expect(next.routeLocation, '/squad?lobby_id=lobby-9');
    });

    test('cancelLooking after matched returns idle', () {
      const matched = MatchmakingQueueEntry(
        phase: MatchmakingQueuePhase.matched,
        lobbyId: 'lobby-9',
        notificationId: 'n1',
      );
      final next = reduceMatchmakingQueue(
        current: matched,
        event: MatchmakingQueueEvent.cancelLooking,
      );
      expect(next.phase, MatchmakingQueuePhase.idle);
      expect(next.lobbyId, isNull);
    });

    test('cancelLooking after joined is a no-op', () {
      const joined = MatchmakingQueueEntry(
        phase: MatchmakingQueuePhase.joined,
        lobbyId: 'lobby-9',
      );
      final next = reduceMatchmakingQueue(
        current: joined,
        event: MatchmakingQueueEvent.cancelLooking,
      );
      expect(next.phase, MatchmakingQueuePhase.joined);
      expect(next.lobbyId, 'lobby-9');
    });

    test('joinMatched from looking is a no-op', () {
      const looking = MatchmakingQueueEntry(
        phase: MatchmakingQueuePhase.looking,
      );
      final next = reduceMatchmakingQueue(
        current: looking,
        event: MatchmakingQueueEvent.joinMatched,
      );
      expect(next.phase, MatchmakingQueuePhase.looking);
    });

    test('matched → joined on joinMatched', () {
      const matched = MatchmakingQueueEntry(
        phase: MatchmakingQueuePhase.matched,
        lobbyId: 'lobby-9',
        gameName: 'Warzone',
      );
      final next = reduceMatchmakingQueue(
        current: matched,
        event: MatchmakingQueueEvent.joinMatched,
      );
      expect(next.phase, MatchmakingQueuePhase.joined);
      expect(next.lobbyId, 'lobby-9');
      expect(next.routeLocation, '/squad/Warzone?lobby_id=lobby-9');
    });

    test('expire returns idle and clears the match', () {
      const matched = MatchmakingQueueEntry(
        phase: MatchmakingQueuePhase.matched,
        lobbyId: 'lobby-9',
        notificationId: 'n1',
        matchedUserId: 'u2',
      );
      final next = reduceMatchmakingQueue(
        current: matched,
        event: MatchmakingQueueEvent.expire,
      );
      expect(next.phase, MatchmakingQueuePhase.idle);
      expect(next.lobbyId, isNull);
      expect(next.routeLocation, isNull);
    });

    test('startLooking after joined starts a new queue', () {
      const joined = MatchmakingQueueEntry(
        phase: MatchmakingQueuePhase.joined,
        lobbyId: 'lobby-9',
        notificationId: 'n1',
      );
      final next = reduceMatchmakingQueue(
        current: joined,
        event: MatchmakingQueueEvent.startLooking,
        squadId: 'squad-2',
      );
      expect(next.phase, MatchmakingQueuePhase.looking);
      expect(next.lobbyId, isNull);
      expect(next.squadId, 'squad-2');
    });

    test('matchFound after joined is a no-op', () {
      const joined = MatchmakingQueueEntry(
        phase: MatchmakingQueuePhase.joined,
        lobbyId: 'lobby-9',
      );
      final next = reduceMatchmakingQueue(
        current: joined,
        event: MatchmakingQueueEvent.matchFound,
        lobbyId: 'other',
      );
      expect(next.phase, MatchmakingQueuePhase.joined);
      expect(next.lobbyId, 'lobby-9');
    });
  });

  test('full idle → looking → matched → joined path', () {
    var state = MatchmakingQueueEntry.idle;
    state = reduceMatchmakingQueue(
      current: state,
      event: MatchmakingQueueEvent.startLooking,
      squadId: 'squad-1',
    );
    expect(state.phase, MatchmakingQueuePhase.looking);

    state = reduceMatchmakingQueue(
      current: state,
      event: MatchmakingQueueEvent.matchFound,
      lobbyId: 'lobby-9',
      gameName: 'Warzone',
      notificationId: 'n1',
    );
    expect(state.phase, MatchmakingQueuePhase.matched);
    expect(state.routeLocation, '/squad/Warzone?lobby_id=lobby-9');

    state = reduceMatchmakingQueue(
      current: state,
      event: MatchmakingQueueEvent.joinMatched,
    );
    expect(state.phase, MatchmakingQueuePhase.joined);
    expect(state.hasJoinTarget, isTrue);
  });

  group('shouldApplyRemoteQueueEntry', () {
    test('late looking does not undo a local dequeue', () {
      const matched = MatchmakingQueueEntry(
        phase: MatchmakingQueuePhase.matched,
        lobbyId: 'lobby-9',
      );
      const looking = MatchmakingQueueEntry(
        phase: MatchmakingQueuePhase.looking,
      );
      expect(
        shouldApplyRemoteQueueEntry(local: matched, remote: looking),
        isFalse,
      );
      expect(
        shouldApplyRemoteQueueEntry(
          local: const MatchmakingQueueEntry(
            phase: MatchmakingQueuePhase.joined,
            lobbyId: 'lobby-9',
          ),
          remote: looking,
        ),
        isFalse,
      );
      expect(
        shouldApplyRemoteQueueEntry(local: matched, remote: null),
        isFalse,
      );
    });

    test('remote dequeue still applies over local looking', () {
      const looking = MatchmakingQueueEntry(
        phase: MatchmakingQueuePhase.looking,
      );
      const matched = MatchmakingQueueEntry(
        phase: MatchmakingQueuePhase.matched,
        lobbyId: 'lobby-9',
      );
      expect(
        shouldApplyRemoteQueueEntry(local: looking, remote: matched),
        isTrue,
      );
      expect(
        shouldApplyRemoteQueueEntry(
          local: MatchmakingQueueEntry.idle,
          remote: looking,
        ),
        isTrue,
      );
      expect(
        shouldApplyRemoteQueueEntry(local: looking, remote: null),
        isTrue,
      );
    });
  });

  group('stale looking cleanup stubs', () {
    test('looking older than TTL is stale; matched and unstamped are not', () {
      final now = DateTime.utc(2026, 9, 6, 12);
      expect(
        isStaleMatchmakingEntry(
          MatchmakingQueueEntry(
            phase: MatchmakingQueuePhase.looking,
            queuedAt: now.subtract(kLfgStaleEntryAfter),
          ),
          now: now,
        ),
        isTrue,
      );
      expect(
        isStaleMatchmakingEntry(
          MatchmakingQueueEntry(
            phase: MatchmakingQueuePhase.looking,
            queuedAt: now.subtract(
              kLfgStaleEntryAfter - const Duration(seconds: 1),
            ),
          ),
          now: now,
        ),
        isFalse,
      );
      expect(
        isStaleMatchmakingEntry(
          const MatchmakingQueueEntry(phase: MatchmakingQueuePhase.looking),
          now: now,
        ),
        isFalse,
      );
      expect(
        isStaleMatchmakingEntry(
          MatchmakingQueueEntry(
            phase: MatchmakingQueuePhase.matched,
            lobbyId: 'lobby-9',
            queuedAt: now.subtract(kLfgStaleEntryAfter * 2),
          ),
          now: now,
        ),
        isFalse,
      );
    });

    test('empty snapshot has no stale ids', () {
      expect(
        staleMatchmakingUserIds(
          const {},
          now: DateTime.utc(2026, 9, 6, 12),
        ),
        isEmpty,
      );
    });
  });
}
