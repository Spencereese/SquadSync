import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/core/deep_link_routes.dart';
import 'package:squad_sync/core/notification_routes.dart';
import 'package:squad_sync/services/lobby_seat_status.dart';
import 'package:squad_sync/services/matchmaking_queue_machine.dart';
import 'package:squad_sync/services/peacock_assignment_machine.dart';
import 'package:squad_sync/services/peacock_lifecycle_machine.dart';

void main() {
  const lobbyId = 'lobby-9';
  const game = 'Warzone';
  const spotIndex = 2;
  const highlighted = '/squad/Warzone?lobby_id=lobby-9&spot_index=2';

  group('Waiting → Offered → Lock-in → Seated', () {
    test('joinQueue is Waiting', () {
      final next = reducePeacockLifecycle(
        current: PeacockLifecycleState.idle,
        event: PeacockLifecycleEvent.joinQueue,
      );
      expect(next.phase, PeacockLifecyclePhase.waiting);
      expect(next.routeLocation, isNull);
    });

    test('Waiting → Offered carries lobby + offered spot', () {
      final waiting = reducePeacockLifecycle(
        current: PeacockLifecycleState.idle,
        event: PeacockLifecycleEvent.joinQueue,
      );
      final offered = reducePeacockLifecycle(
        current: waiting,
        event: PeacockLifecycleEvent.offer,
        lobbyId: lobbyId,
        gameName: game,
        spotIndex: spotIndex,
      );
      expect(offered.phase, PeacockLifecyclePhase.offered);
      expect(offered.lobbyId, lobbyId);
      expect(offered.spotIndex, spotIndex);
      expect(offered.routeLocation, highlighted);
    });

    test('Offered → Lock-in keeps the offered seat', () {
      final offered = reducePeacockLifecycle(
        current: const PeacockLifecycleState(
          phase: PeacockLifecyclePhase.waiting,
        ),
        event: PeacockLifecycleEvent.offer,
        lobbyId: lobbyId,
        gameName: game,
        spotIndex: spotIndex,
      );
      final locked = reducePeacockLifecycle(
        current: offered,
        event: PeacockLifecycleEvent.lockIn,
      );
      expect(locked.phase, PeacockLifecyclePhase.lockIn);
      expect(locked.spotIndex, spotIndex);
      expect(locked.routeLocation, highlighted);
    });

    test('Lock-in → Seated is the success terminal', () {
      var state = PeacockLifecycleState.idle;
      state = reducePeacockLifecycle(
        current: state,
        event: PeacockLifecycleEvent.joinQueue,
      );
      state = reducePeacockLifecycle(
        current: state,
        event: PeacockLifecycleEvent.offer,
        lobbyId: lobbyId,
        gameName: game,
        spotIndex: spotIndex,
      );
      state = reducePeacockLifecycle(
        current: state,
        event: PeacockLifecycleEvent.lockIn,
      );
      state = reducePeacockLifecycle(
        current: state,
        event: PeacockLifecycleEvent.seat,
      );
      expect(state.phase, PeacockLifecyclePhase.seated);
      expect(state.routeLocation, highlighted);
    });

    test('Offered → Seated may skip Lock-in (accept immediately)', () {
      final offered = reducePeacockLifecycle(
        current: PeacockLifecycleState.idle,
        event: PeacockLifecycleEvent.offer,
        lobbyId: lobbyId,
        gameName: game,
        spotIndex: 0,
      );
      final seated = reducePeacockLifecycle(
        current: offered,
        event: PeacockLifecycleEvent.seat,
      );
      expect(seated.phase, PeacockLifecyclePhase.seated);
      expect(seated.spotIndex, 0);
      expect(
        seated.routeLocation,
        '/squad/Warzone?lobby_id=lobby-9&spot_index=0',
      );
    });
  });

  group('Expired / Declined terminals', () {
    test('Offered → Expired', () {
      final offered = reducePeacockLifecycle(
        current: const PeacockLifecycleState(
          phase: PeacockLifecyclePhase.waiting,
        ),
        event: PeacockLifecycleEvent.offer,
        lobbyId: lobbyId,
        spotIndex: spotIndex,
      );
      final expired = reducePeacockLifecycle(
        current: offered,
        event: PeacockLifecycleEvent.expire,
      );
      expect(expired.phase, PeacockLifecyclePhase.expired);
      expect(expired.routeLocation, isNull);
    });

    test('Offered → Declined', () {
      final offered = reducePeacockLifecycle(
        current: const PeacockLifecycleState(
          phase: PeacockLifecyclePhase.offered,
          lobbyId: lobbyId,
          spotIndex: spotIndex,
        ),
        event: PeacockLifecycleEvent.decline,
      );
      expect(offered.phase, PeacockLifecyclePhase.declined);
      expect(offered.routeLocation, isNull);
    });

    test('Lock-in → Expired and Lock-in → Declined', () {
      const locked = PeacockLifecycleState(
        phase: PeacockLifecyclePhase.lockIn,
        lobbyId: lobbyId,
        gameName: game,
        spotIndex: spotIndex,
      );
      expect(
        reducePeacockLifecycle(
          current: locked,
          event: PeacockLifecycleEvent.expire,
        ).phase,
        PeacockLifecyclePhase.expired,
      );
      expect(
        reducePeacockLifecycle(
          current: locked,
          event: PeacockLifecycleEvent.decline,
        ).phase,
        PeacockLifecyclePhase.declined,
      );
    });

    test('Waiting → Expired (queue timeout)', () {
      final expired = reducePeacockLifecycle(
        current: const PeacockLifecycleState(
          phase: PeacockLifecyclePhase.waiting,
        ),
        event: PeacockLifecycleEvent.expire,
      );
      expect(expired.phase, PeacockLifecyclePhase.expired);
    });

    test('Seated does not expire or decline', () {
      const seated = PeacockLifecycleState(
        phase: PeacockLifecyclePhase.seated,
        lobbyId: lobbyId,
        spotIndex: spotIndex,
      );
      expect(
        reducePeacockLifecycle(
          current: seated,
          event: PeacockLifecycleEvent.expire,
        ).phase,
        PeacockLifecyclePhase.seated,
      );
      expect(
        reducePeacockLifecycle(
          current: seated,
          event: PeacockLifecycleEvent.decline,
        ).phase,
        PeacockLifecyclePhase.seated,
      );
    });

    test('joinQueue after Expired / Declined starts Waiting again', () {
      for (final terminal in [
        PeacockLifecyclePhase.expired,
        PeacockLifecyclePhase.declined,
      ]) {
        final next = reducePeacockLifecycle(
          current: PeacockLifecycleState(phase: terminal),
          event: PeacockLifecycleEvent.joinQueue,
        );
        expect(next.phase, PeacockLifecyclePhase.waiting, reason: '$terminal');
        expect(next.lobbyId, isNull);
      }
    });

    test('illegal events are no-ops', () {
      const waiting = PeacockLifecycleState(
        phase: PeacockLifecyclePhase.waiting,
      );
      expect(
        reducePeacockLifecycle(
          current: waiting,
          event: PeacockLifecycleEvent.lockIn,
        ).phase,
        PeacockLifecyclePhase.waiting,
      );
      expect(
        reducePeacockLifecycle(
          current: waiting,
          event: PeacockLifecycleEvent.seat,
        ).phase,
        PeacockLifecyclePhase.waiting,
      );
      expect(
        reducePeacockLifecycle(
          current: waiting,
          event: PeacockLifecycleEvent.decline,
        ).phase,
        PeacockLifecyclePhase.waiting,
      );
    });
  });

  group('offered route shares ticket 33 deep-link table', () {
    test('lifecycle route equals notification + peacock card parse', () {
      final offered = reducePeacockLifecycle(
        current: PeacockLifecycleState.idle,
        event: PeacockLifecycleEvent.offer,
        lobbyId: lobbyId,
        gameName: game,
        spotIndex: spotIndex,
      );
      expect(offered.routeLocation, highlighted);

      expect(
        NotificationRoutes.locationFor({
          'type': 'peacock_assigned',
          'lobby_id': lobbyId,
          'game_name': game,
          'spot_index': spotIndex,
        }),
        highlighted,
      );
      expect(
        locationForDeepLink(
          peacockCardDeepLink(
            lobbyId: lobbyId,
            gameName: game,
            spotIndex: spotIndex,
          ),
        ),
        highlighted,
      );
    });

    test('chat peacock card tap opens lobby with offered-spot highlight', () {
      String? opened;
      openPeacockCard(
        lobbyId: lobbyId,
        gameName: game,
        spotIndex: spotIndex,
        go: (location) => opened = location,
      );
      expect(opened, highlighted);
      expect(pulseOfferedSpotAt(index: 2, highlightSpotIndex: 2), isTrue);
      expect(pulseOfferedSpotAt(index: 0, highlightSpotIndex: 2), isFalse);
    });
  });

  group('resolvePeacockLifecycle from assignment + seat (ticket 14)', () {
    test('queued is Waiting; assigned offer is Offered', () {
      final queued = reducePeacockAssignment(
        current: PeacockAssignmentState.idle,
        event: PeacockAssignmentEvent.joinQueue,
      );
      expect(
        resolvePeacockLifecycle(peacock: queued),
        PeacockLifecyclePhase.waiting,
      );

      final assigned = reducePeacockAssignment(
        current: queued,
        event: PeacockAssignmentEvent.assignSpot,
        lobbyId: lobbyId,
        spotIndex: 0,
      );
      final status = resolveLobbySeatStatus(
        userId: 'u1',
        peacock: assigned,
        lfg: MatchmakingQueueEntry.idle,
        spots: [null, null],
        maxSpots: 2,
      );
      expect(
        resolvePeacockLifecycle(peacock: assigned, seat: status),
        PeacockLifecyclePhase.offered,
      );
      expect(status!.pulseOfferedSpot, isTrue);
      expect(pulseOfferedSpotAt(index: 0, status: status), isTrue);
    });

    test('calling lock is Lock-in; occupying is Seated', () {
      final assigned = reducePeacockAssignment(
        current: PeacockAssignmentState.idle,
        event: PeacockAssignmentEvent.assignSpot,
        lobbyId: lobbyId,
      );
      final lockIn = resolveLobbySeatStatus(
        userId: 'u1',
        peacock: assigned,
        lfg: MatchmakingQueueEntry.idle,
        spots: ['u1_calling', null],
        maxSpots: 2,
        lockRemaining: const Duration(minutes: 4, seconds: 59),
        occupantStatus: 'Calling',
      );
      expect(
        resolvePeacockLifecycle(peacock: assigned, seat: lockIn),
        PeacockLifecyclePhase.lockIn,
      );

      final seated = resolveLobbySeatStatus(
        userId: 'u1',
        peacock: assigned,
        lfg: MatchmakingQueueEntry.idle,
        spots: ['u1', null],
        maxSpots: 2,
      );
      expect(
        resolvePeacockLifecycle(peacock: assigned, seat: seated),
        PeacockLifecyclePhase.seated,
      );
    });

    test('expired lock remaining maps to Expired', () {
      final assigned = reducePeacockAssignment(
        current: PeacockAssignmentState.idle,
        event: PeacockAssignmentEvent.assignSpot,
        lobbyId: lobbyId,
      );
      final status = resolveLobbySeatStatus(
        userId: 'u1',
        peacock: assigned,
        lfg: MatchmakingQueueEntry.idle,
        spots: ['u1_calling', null],
        maxSpots: 2,
        lockRemaining: Duration.zero,
        occupantStatus: 'Calling',
      );
      expect(
        resolvePeacockLifecycle(peacock: assigned, seat: status),
        PeacockLifecyclePhase.expired,
      );
    });
  });
}
