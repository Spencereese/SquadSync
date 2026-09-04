import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/services/lobby_seat_status.dart';
import 'package:squad_sync/services/matchmaking_queue_machine.dart';
import 'package:squad_sync/services/peacock_assignment_machine.dart';

void main() {
  late PeacockAssignmentTracker peacock;
  late MatchmakingQueueTracker lfg;

  setUp(() {
    peacock = PeacockAssignmentTracker();
    lfg = MatchmakingQueueTracker(peacock: peacock);
  });

  group('claimSeatCopy / lfgJoinSnackbarMessage', () {
    test('uses concrete seat number when known (1-based)', () {
      expect(claimSeatCopy(0), 'Claim seat 1');
      expect(claimSeatCopy(2), 'Claim seat 3');
      expect(
        lfgJoinSnackbarMessage(claimedSpot: 1, handedOff: true),
        'Claim seat 2',
      );
    });

    test('replaces Handed off copy when seat is unknown', () {
      expect(claimSeatCopy(null), 'Claim seat');
      expect(
        lfgJoinSnackbarMessage(claimedSpot: null, handedOff: true),
        'Claim seat',
      );
      expect(
        lfgJoinSnackbarMessage(claimedSpot: null, handedOff: false),
        'Squad joined',
      );
    });
  });

  group('formatLockMmSs', () {
    test('pads lock mm:ss', () {
      expect(formatLockMmSs(const Duration(minutes: 4, seconds: 9)), '04:09');
      expect(formatLockMmSs(Duration.zero), '00:00');
    });
  });

  group('resolveLobbySeatStatus chip / pulse / banner', () {
    test('idle user has no chip', () {
      expect(
        resolveLobbySeatStatus(
          userId: 'u1',
          peacock: PeacockAssignmentState.idle,
          lfg: MatchmakingQueueEntry.idle,
        ),
        isNull,
      );
    });

    test('queued peacock is peacock chip, no offer banner', () {
      final queued = reducePeacockAssignment(
        current: PeacockAssignmentState.idle,
        event: PeacockAssignmentEvent.joinQueue,
      );
      final status = resolveLobbySeatStatus(
        userId: 'u1',
        peacock: queued,
        lfg: MatchmakingQueueEntry.idle,
      );
      expect(status!.chipLabel, 'peacock');
      expect(status.showOfferBanner, isFalse);
      expect(status.pulseOfferedSpot, isFalse);
    });

    test('LFG looking is peacock chip', () {
      final looking = reduceMatchmakingQueue(
        current: MatchmakingQueueEntry.idle,
        event: MatchmakingQueueEvent.startLooking,
      );
      final status = resolveLobbySeatStatus(
        userId: 'u1',
        peacock: PeacockAssignmentState.idle,
        lfg: looking,
      );
      expect(status!.chip, LobbySeatChipKind.peacock);
      expect(status.showOfferBanner, isFalse);
    });

    test('assigned peacock offers a seat that pulses', () {
      final assigned = reducePeacockAssignment(
        current: reducePeacockAssignment(
          current: PeacockAssignmentState.idle,
          event: PeacockAssignmentEvent.joinQueue,
        ),
        event: PeacockAssignmentEvent.assignSpot,
        lobbyId: 'lobby-9',
      );
      final status = resolveLobbySeatStatus(
        userId: 'u1',
        peacock: assigned,
        lfg: MatchmakingQueueEntry.idle,
        spots: [null, null, 'taken'],
        maxSpots: 3,
      );
      expect(status!.chipLabel, 'peacock');
      expect(status.seatIndex, 0);
      expect(status.seatNumber, 1);
      expect(status.showOfferBanner, isTrue);
      expect(status.pulseOfferedSpot, isTrue);
      expect(claimSeatCopy(status.seatIndex), 'Claim seat 1');
    });

    test('occupying a seat is seated (no pulse / banner)', () {
      final assigned = reducePeacockAssignment(
        current: PeacockAssignmentState.idle,
        event: PeacockAssignmentEvent.assignSpot,
        lobbyId: 'lobby-9',
      );
      final status = resolveLobbySeatStatus(
        userId: 'u1',
        peacock: assigned,
        lfg: MatchmakingQueueEntry.idle,
        spots: ['u1', null],
        maxSpots: 2,
      );
      expect(status!.chipLabel, 'seated');
      expect(status.seatIndex, 0);
      expect(status.showOfferBanner, isFalse);
      expect(status.pulseOfferedSpot, isFalse);
    });

    test('calling with lock remaining is lock mm:ss and pulses', () {
      final assigned = reducePeacockAssignment(
        current: PeacockAssignmentState.idle,
        event: PeacockAssignmentEvent.assignSpot,
        lobbyId: 'lobby-9',
      );
      final status = resolveLobbySeatStatus(
        userId: 'u1',
        peacock: assigned,
        lfg: MatchmakingQueueEntry.idle,
        spots: ['u1_calling', null],
        maxSpots: 2,
        lockRemaining: const Duration(minutes: 4, seconds: 59),
        occupantStatus: 'Calling',
      );
      expect(status!.chipLabel, 'lock 04:59');
      expect(status.chip, LobbySeatChipKind.lock);
      expect(status.seatIndex, 0);
      expect(status.showOfferBanner, isTrue);
      expect(status.pulseOfferedSpot, isTrue);
    });

    test('LFG matched with lobby offers next free seat', () {
      final matched = reduceMatchmakingQueue(
        current: reduceMatchmakingQueue(
          current: MatchmakingQueueEntry.idle,
          event: MatchmakingQueueEvent.startLooking,
        ),
        event: MatchmakingQueueEvent.matchFound,
        lobbyId: 'lobby-9',
        gameName: 'Warzone',
      );
      expect(matched.hasJoinTarget, isTrue);
      final status = resolveLobbySeatStatus(
        userId: 'u1',
        peacock: PeacockAssignmentState.idle,
        lfg: matched,
        spots: ['other', null],
        maxSpots: 2,
      );
      expect(status!.chipLabel, 'peacock');
      expect(status.seatIndex, 1);
      expect(status.showOfferBanner, isTrue);
      expect(status.pulseOfferedSpot, isTrue);
      expect(claimSeatCopy(status.seatIndex), 'Claim seat 2');
    });
  });

  group('declineOfferedSeat uses existing LFG + peacock expire (no XOR notify)',
      () {
    test('cancels matched LFG and expires peacock without notifySelf', () {
      lfg.startLooking('u1');
      lfg.matchFound('u1', lobbyId: 'lobby-9', notificationId: 'n1');
      peacock.assignSpot('u1', lobbyId: 'lobby-9', notificationId: 'n1');
      expect(peacock.stateFor('u1').phase, PeacockAssignmentPhase.assigned);
      expect(peacock.stateFor('u1').showedLocal, isFalse);
      expect(peacock.stateFor('u1').sentFcmToSelf, isFalse);

      declineOfferedSeat(
        userId: 'u1',
        lfg: lfg,
        expirePeacock: peacock.expire,
      );

      expect(lfg.stateFor('u1').phase, MatchmakingQueuePhase.idle);
      expect(peacock.stateFor('u1').phase, PeacockAssignmentPhase.idle);
      expect(peacock.stateFor('u1').showedLocal, isFalse);
      expect(peacock.stateFor('u1').sentFcmToSelf, isFalse);
      expect(peacock.stateFor('u1').wouldDoubleNotifySelf, isFalse);
    });

    test('joinMatched after assign is a single peacock reduce', () {
      lfg.startLooking('u1');
      lfg.matchFound('u1', lobbyId: 'lobby-9', notificationId: 'n1');
      peacock.assignSpot('u1', lobbyId: 'lobby-9', notificationId: 'n1');
      final handoff = lfg.joinMatched('u1', handoffToPeacock: false);
      expect(handoff.handedOffToPeacock, isTrue);
      expect(peacock.stateFor('u1').phase, PeacockAssignmentPhase.assigned);
      expect(peacock.stateFor('u1').showedLocal, isFalse);
      expect(peacock.stateFor('u1').sentFcmToSelf, isFalse);
    });
  });
}
