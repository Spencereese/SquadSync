import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/services/peacock_assignment_machine.dart';

void main() {
  group('peacock product phases', () {
    test('idle → queued on joinQueue', () {
      final next = reducePeacockAssignment(
        current: PeacockAssignmentState.idle,
        event: PeacockAssignmentEvent.joinQueue,
        gameName: 'Warzone',
      );
      expect(next.phase, PeacockAssignmentPhase.queued);
      expect(next.gameName, 'Warzone');
      expect(next.routeLocation, isNull);
    });

    test('queued → idle on leaveQueue', () {
      final queued = reducePeacockAssignment(
        current: PeacockAssignmentState.idle,
        event: PeacockAssignmentEvent.joinQueue,
      );
      final next = reducePeacockAssignment(
        current: queued,
        event: PeacockAssignmentEvent.leaveQueue,
      );
      expect(next.phase, PeacockAssignmentPhase.idle);
    });

    test('joinQueue while queued is idempotent', () {
      const queued = PeacockAssignmentState(
        phase: PeacockAssignmentPhase.queued,
      );
      final next = reducePeacockAssignment(
        current: queued,
        event: PeacockAssignmentEvent.joinQueue,
      );
      expect(next.phase, PeacockAssignmentPhase.queued);
    });

    test('queued → assigned on assignSpot', () {
      const queued = PeacockAssignmentState(
        phase: PeacockAssignmentPhase.queued,
      );
      final next = reducePeacockAssignment(
        current: queued,
        event: PeacockAssignmentEvent.assignSpot,
        lobbyId: 'lobby-9',
        gameName: 'Warzone',
        notificationId: 'n1',
      );
      expect(next.phase, PeacockAssignmentPhase.assigned);
      expect(next.lobbyId, 'lobby-9');
      expect(next.gameName, 'Warzone');
      expect(next.notificationId, 'n1');
      expect(next.routeLocation, '/squad/Warzone?lobby_id=lobby-9');
    });

    test('assigned route includes spot_index when the offered seat is known',
        () {
      const queued = PeacockAssignmentState(
        phase: PeacockAssignmentPhase.queued,
      );
      final next = reducePeacockAssignment(
        current: queued,
        event: PeacockAssignmentEvent.assignSpot,
        lobbyId: 'lobby-9',
        gameName: 'Warzone',
        spotIndex: 2,
      );
      expect(next.spotIndex, 2);
      expect(
        next.routeLocation,
        '/squad/Warzone?lobby_id=lobby-9&spot_index=2',
      );
    });

    test('idle can assign directly (skip queue)', () {
      final next = reducePeacockAssignment(
        current: PeacockAssignmentState.idle,
        event: PeacockAssignmentEvent.assignSpot,
        lobbyId: 'lobby-9',
        notificationId: 'n1',
      );
      expect(next.phase, PeacockAssignmentPhase.assigned);
      expect(next.routeLocation, '/squad?lobby_id=lobby-9');
    });

    test('leaveQueue after assigned is a no-op', () {
      const assigned = PeacockAssignmentState(
        phase: PeacockAssignmentPhase.assigned,
        lobbyId: 'lobby-9',
        notificationId: 'n1',
      );
      final next = reducePeacockAssignment(
        current: assigned,
        event: PeacockAssignmentEvent.leaveQueue,
      );
      expect(next.phase, PeacockAssignmentPhase.assigned);
      expect(next.lobbyId, 'lobby-9');
    });

    test('expire returns idle and clears assignment', () {
      const assigned = PeacockAssignmentState(
        phase: PeacockAssignmentPhase.assigned,
        lobbyId: 'lobby-9',
        notificationId: 'n1',
        showedLocal: true,
      );
      final next = reducePeacockAssignment(
        current: assigned,
        event: PeacockAssignmentEvent.expire,
      );
      expect(next.phase, PeacockAssignmentPhase.idle);
      expect(next.lobbyId, isNull);
      expect(next.showedLocal, isFalse);
      expect(next.routeLocation, isNull);
    });

    test('joinQueue after notified starts a new queue', () {
      const notified = PeacockAssignmentState(
        phase: PeacockAssignmentPhase.notified,
        lobbyId: 'lobby-9',
        notificationId: 'n1',
        showedLocal: true,
      );
      final next = reducePeacockAssignment(
        current: notified,
        event: PeacockAssignmentEvent.joinQueue,
      );
      expect(next.phase, PeacockAssignmentPhase.queued);
      expect(next.lobbyId, isNull);
      expect(next.showedLocal, isFalse);
    });
  });

  group('assigned → notified XOR', () {
    test('foreground notify is local only', () {
      const assigned = PeacockAssignmentState(
        phase: PeacockAssignmentPhase.assigned,
        lobbyId: 'lobby-9',
        notificationId: 'n1',
      );
      final next = reducePeacockAssignment(
        current: assigned,
        event: PeacockAssignmentEvent.notifySelf,
        isForeground: true,
        currentUid: 'uid-1',
      );
      expect(next.phase, PeacockAssignmentPhase.notified);
      expect(next.showedLocal, isTrue);
      expect(next.sentFcmToSelf, isFalse);
      expect(next.wouldDoubleNotifySelf, isFalse);
    });

    test('background notify is FCM only', () {
      const assigned = PeacockAssignmentState(
        phase: PeacockAssignmentPhase.assigned,
        lobbyId: 'lobby-9',
        notificationId: 'n1',
      );
      final next = reducePeacockAssignment(
        current: assigned,
        event: PeacockAssignmentEvent.notifySelf,
        isForeground: false,
        currentUid: 'uid-1',
      );
      expect(next.phase, PeacockAssignmentPhase.notified);
      expect(next.showedLocal, isFalse);
      expect(next.sentFcmToSelf, isTrue);
      expect(next.wouldDoubleNotifySelf, isFalse);
    });

    test('duplicate notify after local never FCMs the same id', () {
      const assigned = PeacockAssignmentState(
        phase: PeacockAssignmentPhase.assigned,
        notificationId: 'n1',
      );
      final local = reducePeacockAssignment(
        current: assigned,
        event: PeacockAssignmentEvent.notifySelf,
        isForeground: true,
        currentUid: 'uid-1',
      );
      final again = reducePeacockAssignment(
        current: local,
        event: PeacockAssignmentEvent.notifySelf,
        isForeground: false,
        currentUid: 'uid-1',
      );
      expect(again.showedLocal, isTrue);
      expect(again.sentFcmToSelf, isFalse);
      expect(again.wouldDoubleNotifySelf, isFalse);
    });

    test('duplicate notify after FCM never shows local for the same event_id',
        () {
      const assigned = PeacockAssignmentState(
        phase: PeacockAssignmentPhase.assigned,
        notificationId: 'evt-1',
      );
      final fcm = reducePeacockAssignment(
        current: assigned,
        event: PeacockAssignmentEvent.notifySelf,
        isForeground: false,
        currentUid: 'uid-1',
        notificationId: 'evt-1',
      );
      final again = reducePeacockAssignment(
        current: fcm,
        event: PeacockAssignmentEvent.notifySelf,
        isForeground: true,
        currentUid: 'uid-1',
        notificationId: 'evt-1',
      );
      expect(again.showedLocal, isFalse);
      expect(again.sentFcmToSelf, isTrue);
      expect(again.wouldDoubleNotifySelf, isFalse);
    });

    test('background with no uid does not FCM', () {
      const assigned = PeacockAssignmentState(
        phase: PeacockAssignmentPhase.assigned,
        notificationId: 'n1',
      );
      final next = reducePeacockAssignment(
        current: assigned,
        event: PeacockAssignmentEvent.notifySelf,
        isForeground: false,
        currentUid: null,
      );
      expect(next.phase, PeacockAssignmentPhase.notified);
      expect(next.showedLocal, isFalse);
      expect(next.sentFcmToSelf, isFalse);
    });

    test('notifySelf from idle or queued is a no-op', () {
      for (final phase in [
        PeacockAssignmentPhase.idle,
        PeacockAssignmentPhase.queued,
      ]) {
        final next = reducePeacockAssignment(
          current: PeacockAssignmentState(phase: phase),
          event: PeacockAssignmentEvent.notifySelf,
          isForeground: true,
          currentUid: 'uid-1',
        );
        expect(next.phase, phase, reason: '$phase');
        expect(next.showedLocal, isFalse, reason: '$phase');
        expect(next.sentFcmToSelf, isFalse, reason: '$phase');
      }
    });

    test('one notify path never local+FCM to the same uid', () {
      const assigned = PeacockAssignmentState(
        phase: PeacockAssignmentPhase.assigned,
        notificationId: 'n1',
      );
      for (final foreground in [true, false]) {
        final next = reducePeacockAssignment(
          current: assigned,
          event: PeacockAssignmentEvent.notifySelf,
          isForeground: foreground,
          currentUid: 'uid-1',
        );
        expect(next.wouldDoubleNotifySelf, isFalse, reason: '$foreground');
        if (next.showedLocal) {
          expect(next.sentFcmToSelf, isFalse);
        }
      }
    });
  });

  test('full idle → queued → assigned → notified path', () {
    var state = PeacockAssignmentState.idle;
    state = reducePeacockAssignment(
      current: state,
      event: PeacockAssignmentEvent.joinQueue,
    );
    expect(state.phase, PeacockAssignmentPhase.queued);

    state = reducePeacockAssignment(
      current: state,
      event: PeacockAssignmentEvent.assignSpot,
      lobbyId: 'lobby-9',
      gameName: 'Warzone',
      notificationId: 'n1',
    );
    expect(state.phase, PeacockAssignmentPhase.assigned);
    expect(state.routeLocation, '/squad/Warzone?lobby_id=lobby-9');

    state = reducePeacockAssignment(
      current: state,
      event: PeacockAssignmentEvent.notifySelf,
      isForeground: true,
      currentUid: 'uid-1',
    );
    expect(state.phase, PeacockAssignmentPhase.notified);
    expect(state.showedLocal, isTrue);
    expect(state.sentFcmToSelf, isFalse);
    expect(state.wouldDoubleNotifySelf, isFalse);
  });
}
