import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/services/peacock_assignment_machine.dart';

void main() {
  late PeacockAssignmentTracker tracker;

  setUp(() {
    tracker = PeacockAssignmentTracker();
    PeacockAssignmentTracker.resetInstance();
  });

  tearDown(() {
    PeacockAssignmentTracker.resetInstance();
  });

  group('PeacockAssignmentTracker', () {
    test('joinQueue then leaveQueue is idle', () {
      tracker.joinQueue('u1');
      expect(tracker.stateFor('u1').phase, PeacockAssignmentPhase.queued);
      tracker.leaveQueue('u1');
      expect(tracker.stateFor('u1').phase, PeacockAssignmentPhase.idle);
      expect(tracker.snapshot.containsKey('u1'), isFalse);
    });

    test('tracks users independently', () {
      tracker.joinQueue('u1');
      tracker.joinQueue('u2');
      tracker.assignSpot('u1', lobbyId: 'lobby-9', notificationId: 'n1');
      expect(tracker.stateFor('u1').phase, PeacockAssignmentPhase.assigned);
      expect(tracker.stateFor('u2').phase, PeacockAssignmentPhase.queued);
    });

    test('assignSpot then notifySelf foreground is local XOR', () {
      tracker.joinQueue('u1');
      tracker.assignSpot(
        'u1',
        lobbyId: 'lobby-9',
        gameName: 'Warzone',
        notificationId: 'n1',
      );
      final dispatch = tracker.notifySelf(
        'u1',
        isForeground: true,
        currentUid: 'u1',
        notificationId: 'n1',
      );
      expect(dispatch.state.phase, PeacockAssignmentPhase.notified);
      expect(dispatch.plan.showLocal, isTrue);
      expect(dispatch.plan.sendFcmToSelf, isFalse);
      expect(dispatch.plan.wouldDoubleNotifySelf, isFalse);
      expect(dispatch.state.wouldDoubleNotifySelf, isFalse);
    });

    test('assignSpot then notifySelf background is FCM XOR', () {
      tracker.assignSpot('u1', lobbyId: 'lobby-9', notificationId: 'n1');
      final dispatch = tracker.notifySelf(
        'u1',
        isForeground: false,
        currentUid: 'u1',
        notificationId: 'n1',
      );
      expect(dispatch.plan.showLocal, isFalse);
      expect(dispatch.plan.sendFcmToSelf, isTrue);
      expect(dispatch.plan.recipientUids, ['u1']);
      expect(dispatch.plan.wouldDoubleNotifySelf, isFalse);
    });

    test('second notifySelf after local never FCMs the same id', () {
      tracker.assignSpot('u1', notificationId: 'n1');
      final first = tracker.notifySelf(
        'u1',
        isForeground: true,
        currentUid: 'u1',
        notificationId: 'n1',
      );
      expect(first.plan.showLocal, isTrue);
      final second = tracker.notifySelf(
        'u1',
        isForeground: false,
        currentUid: 'u1',
        notificationId: 'n1',
      );
      expect(second.plan.showLocal, isFalse);
      expect(second.plan.sendFcmToSelf, isFalse);
      expect(second.state.showedLocal, isTrue);
      expect(second.state.sentFcmToSelf, isFalse);
    });

    test('background notifySelf with no uid does not FCM', () {
      tracker.assignSpot('u1', notificationId: 'n1');
      final dispatch = tracker.notifySelf(
        'u1',
        isForeground: false,
        currentUid: null,
        notificationId: 'n1',
      );
      expect(dispatch.plan.showLocal, isFalse);
      expect(dispatch.plan.sendFcmToSelf, isFalse);
      expect(dispatch.plan.recipientUids, isEmpty);
    });

    test('nextQueuedUserId is FIFO among queued users', () {
      tracker.joinQueue('u1');
      tracker.joinQueue('u2');
      tracker.assignSpot('u1', lobbyId: 'lobby-9');
      expect(tracker.nextQueuedUserId(), 'u2');
      tracker.expire('u1');
      expect(tracker.nextQueuedUserId(), 'u2');
      tracker.leaveQueue('u2');
      expect(tracker.nextQueuedUserId(), isNull);
    });

    test('expire returns idle and drops the user', () {
      tracker.assignSpot('u1', lobbyId: 'lobby-9', notificationId: 'n1');
      tracker.notifySelf('u1', isForeground: true, currentUid: 'u1');
      tracker.expire('u1');
      expect(tracker.stateFor('u1').phase, PeacockAssignmentPhase.idle);
      expect(tracker.snapshot.containsKey('u1'), isFalse);
    });

    test('production singleton is shared across reset until resetInstance', () {
      PeacockAssignmentTracker.instance.joinQueue('u1');
      expect(
        PeacockAssignmentTracker.instance.stateFor('u1').phase,
        PeacockAssignmentPhase.queued,
      );
      PeacockAssignmentTracker.resetInstance();
      expect(
        PeacockAssignmentTracker.instance.stateFor('u1').phase,
        PeacockAssignmentPhase.idle,
      );
    });
  });
}
