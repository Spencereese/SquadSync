import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/domain/entities/lobby.dart';
import 'package:squad_sync/services/discovery_swipe_gate.dart';
import 'package:squad_sync/services/matchmaking_queue_machine.dart';

Lobby _lobby({
  required String id,
  required List<String> members,
  int maxSpots = 4,
  List<String?>? spots,
}) {
  return Lobby.create(
    name: 'Squad',
    gameName: 'Warzone',
    maxSpots: maxSpots,
    createdBy: members.isEmpty ? 'host' : members.first,
  ).copyWith(
    id: id,
    memberUids: members,
    spots: spots ?? List<String?>.filled(maxSpots, null),
  );
}

MatchmakingQueueEntry get _looking => const MatchmakingQueueEntry(
      phase: MatchmakingQueuePhase.looking,
      squadId: 's1',
    );

void main() {
  group('openSpotCount', () {
    test('counts null and empty as open', () {
      expect(openSpotCount(const [null, '', 'u1', null]), 3);
      expect(openSpotCount(const []), 0);
    });
  });

  group('resolveLookingForFill', () {
    test('false when idle even with open seats', () {
      expect(
        resolveLookingForFill(
          lfg: MatchmakingQueueEntry.idle,
          openSpots: 3,
        ),
        isFalse,
      );
    });

    test('false when looking with no open seats', () {
      expect(resolveLookingForFill(lfg: _looking, openSpots: 0), isFalse);
    });

    test('true only when looking and an open seat exists', () {
      expect(resolveLookingForFill(lfg: _looking, openSpots: 1), isTrue);
    });
  });

  group('resolveSquadVouch', () {
    test('empty uid is not vouched', () {
      expect(
        resolveSquadVouch(userId: '', squadMemberIds: const ['u1']),
        isFalse,
      );
    });

    test('squad membership is the existing vouch', () {
      expect(
        resolveSquadVouch(userId: 'u1', squadMemberIds: const ['u1', 'u2']),
        isTrue,
      );
      expect(
        resolveSquadVouch(userId: 'u9', squadMemberIds: const ['u1', 'u2']),
        isFalse,
      );
    });

    test('explicit squadmate vouch counts without membership', () {
      expect(
        resolveSquadVouch(
          userId: 'fill-1',
          squadId: 's1',
          vouches: const [
            SquadVouch(
              squadId: 's1',
              vouchedUserId: 'fill-1',
              voucherUserId: 'u1',
            ),
          ],
        ),
        isTrue,
      );
      expect(
        resolveSquadVouch(
          userId: 'fill-1',
          squadId: 's1',
          vouches: const [
            SquadVouch(
              squadId: 'other',
              vouchedUserId: 'fill-1',
              voucherUserId: 'u1',
            ),
          ],
        ),
        isFalse,
      );
    });
  });

  group('resolveDiscoverySwipeGate', () {
    test('swipe only when looking-for-fill AND squad-vouch', () {
      expect(
        resolveDiscoverySwipeGate(
          lookingForFill: true,
          hasSquadVouch: true,
        ).canShowSwipe,
        isTrue,
      );
      expect(
        resolveDiscoverySwipeGate(
          lookingForFill: true,
          hasSquadVouch: false,
        ).canShowSwipe,
        isFalse,
      );
      expect(
        resolveDiscoverySwipeGate(
          lookingForFill: false,
          hasSquadVouch: true,
        ).canShowSwipe,
        isFalse,
      );
      expect(
        resolveDiscoverySwipeGate(
          lookingForFill: false,
          hasSquadVouch: false,
        ).canShowSwipe,
        isFalse,
      );
    });

    test('reasons distinguish fill vs vouch vs both', () {
      expect(
        resolveDiscoverySwipeGate(
          lookingForFill: true,
          hasSquadVouch: true,
        ).reason,
        DiscoverySwipeGateReason.open,
      );
      expect(
        resolveDiscoverySwipeGate(
          lookingForFill: false,
          hasSquadVouch: true,
        ).reason,
        DiscoverySwipeGateReason.notLookingForFill,
      );
      expect(
        resolveDiscoverySwipeGate(
          lookingForFill: true,
          hasSquadVouch: false,
        ).reason,
        DiscoverySwipeGateReason.missingSquadVouch,
      );
      expect(
        DiscoverySwipeGate.closed.reason,
        DiscoverySwipeGateReason.bothMissing,
      );
      expect(
        DiscoverySwipeGate.closed.message,
        kDiscoverySwipeNeedBothCopy,
      );
    });
  });

  group('resolveDiscoverySwipeGateFromContext', () {
    test('member looking with an open seat can swipe', () {
      final gate = resolveDiscoverySwipeGateFromContext(
        userId: 'u1',
        lfg: _looking,
        lobby: _lobby(id: 's1', members: const ['u1']),
      );
      expect(gate.canShowSwipe, isTrue);
      expect(gate.reason, DiscoverySwipeGateReason.open);
    });

    test('member not looking is gated', () {
      final gate = resolveDiscoverySwipeGateFromContext(
        userId: 'u1',
        lobby: _lobby(id: 's1', members: const ['u1']),
      );
      expect(gate.canShowSwipe, isFalse);
      expect(gate.reason, DiscoverySwipeGateReason.notLookingForFill);
      expect(gate.message, kDiscoverySwipeNeedFillCopy);
    });

    test('looking without a squad vouch is gated', () {
      final gate = resolveDiscoverySwipeGateFromContext(
        userId: 'stranger',
        lfg: _looking,
        lobby: _lobby(
          id: 's1',
          members: const ['u1'],
          spots: const [null, 'u1', null, null],
        ),
      );
      expect(gate.canShowSwipe, isFalse);
      expect(gate.reason, DiscoverySwipeGateReason.missingSquadVouch);
      expect(gate.message, kDiscoverySwipeNeedVouchCopy);
    });

    test('looking with a full lobby is not looking-for-fill', () {
      final gate = resolveDiscoverySwipeGateFromContext(
        userId: 'u1',
        lfg: _looking,
        lobby: _lobby(
          id: 's1',
          members: const ['u1', 'u2'],
          maxSpots: 2,
          spots: const ['u1', 'u2'],
        ),
      );
      expect(gate.lookingForFill, isFalse);
      expect(gate.hasSquadVouch, isTrue);
      expect(gate.canShowSwipe, isFalse);
    });

    test('explicit vouch plus looking-for-fill opens swipe', () {
      final gate = resolveDiscoverySwipeGateFromContext(
        userId: 'fill-1',
        lfg: _looking,
        lobby: _lobby(
          id: 's1',
          members: const ['u1'],
          spots: const ['u1', null, null, null],
        ),
        vouches: const [
          SquadVouch(
            squadId: 's1',
            vouchedUserId: 'fill-1',
            voucherUserId: 'u1',
          ),
        ],
      );
      expect(gate.canShowSwipe, isTrue);
    });

    test('idle stranger is gated on both', () {
      final gate = resolveDiscoverySwipeGateFromContext(
        userId: 'stranger',
      );
      expect(gate.reason, DiscoverySwipeGateReason.bothMissing);
      expect(gate.message, kDiscoverySwipeNeedBothCopy);
    });
  });
}
