import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/services/coming_hold_machine.dart';
import 'package:squad_sync/services/pin_expire_machine.dart';

/// PIN WAVE — P1 COMING-HOLD + PIN-EXPIRE (RED, Tester-owned).
///
/// Pure-Dart seat-hold + pin-lifetime reducers. No chat UI. No Tonight.
///
/// Contract Loop must implement (do not invent a second machine):
///
/// 1. [reduceComingHold] (`lib/services/coming_hold_machine.dart`)
///    — Coming holds a seat **5:00** ([kComingHoldDuration] = 300s).
///    At remaining `<= 0` the seat **frees**. Optional spot-open nudge
///    is a bool ([ComingHoldState.shouldNudgeSpotOpen]) plus an optional
///    [onSpotOpenNudge] callback stub on the reduce.
///
/// 2. While [ComingHoldPhase.coming]: the user must open the app and
///    tap **I'm in** ([ComingHoldEvent.sit]) or **Can't**
///    ([ComingHoldEvent.release]). Time passing ([ComingHoldEvent.tick])
///    never auto-sits. Expire frees the seat; it does not seat.
///
/// 3. [reducePinExpire] (`lib/services/pin_expire_machine.dart`)
///    — Pin lifetime default **45 min** ([kPinExpireDefault]). Tests
///    accept a 45–60 window ([kPinExpireWindowMin] /
///    [kPinExpireWindowMax]). Owner may end early
///    ([PinExpireEvent.ownerEnd] → [PinExpirePhase.endedEarly]).
///
/// Loop lease (≤3 under `lib/services/` + pubspec on green — Tester
/// does not edit):
/// 1. `lib/services/coming_hold_machine.dart`
/// 2. `lib/services/pin_expire_machine.dart`
///
/// Out of scope: chat_screen / chat_input_bar / chat_info_screen,
/// Tonight-tab, AASA, GATES, merge, pubspec bump (Tester).
void main() {
  group('Coming hold: 5:00 seat + t=0 frees', () {
    test('kComingHoldDuration is 300 seconds (5:00)', () {
      expect(kComingHoldDuration, const Duration(seconds: 300));
      expect(kComingHoldDuration.inMinutes, 5);
    });

    test('startComing holds the seat for 5:00', () {
      final next = reduceComingHold(
        current: ComingHoldState.idle,
        event: ComingHoldEvent.startComing,
        seatIndex: 2,
        pinId: 'pin-1',
        userId: 'u1',
      );

      expect(next.phase, ComingHoldPhase.coming);
      expect(next.seatIndex, 2);
      expect(next.pinId, 'pin-1');
      expect(next.userId, 'u1');
      expect(next.remaining, kComingHoldDuration);
      expect(next.holdsSeat, isTrue);
      expect(next.seatFreed, isFalse);
      expect(next.shouldNudgeSpotOpen, isFalse);
    });

    test('tick that leaves time on the clock keeps the seat', () {
      final coming = reduceComingHold(
        current: ComingHoldState.idle,
        event: ComingHoldEvent.startComing,
        seatIndex: 0,
        userId: 'u1',
      );

      final next = reduceComingHold(
        current: coming,
        event: ComingHoldEvent.tick,
        elapsed: const Duration(seconds: 60),
      );

      expect(next.phase, ComingHoldPhase.coming);
      expect(next.remaining, const Duration(seconds: 240));
      expect(next.holdsSeat, isTrue);
      expect(next.seatFreed, isFalse);
      expect(next.shouldNudgeSpotOpen, isFalse);
    });

    test('at t=0 the seat frees and the spot-open nudge hook fires', () {
      var nudgeFired = false;
      final coming = reduceComingHold(
        current: ComingHoldState.idle,
        event: ComingHoldEvent.startComing,
        seatIndex: 1,
        pinId: 'pin-9',
        userId: 'u2',
      );

      final next = reduceComingHold(
        current: coming,
        event: ComingHoldEvent.tick,
        elapsed: kComingHoldDuration,
        onSpotOpenNudge: () => nudgeFired = true,
      );

      expect(next.phase, ComingHoldPhase.expired);
      expect(next.remaining, Duration.zero);
      expect(next.holdsSeat, isFalse);
      expect(next.seatFreed, isTrue);
      expect(next.shouldNudgeSpotOpen, isTrue);
      expect(nudgeFired, isTrue);
      expect(
        next.phase,
        isNot(ComingHoldPhase.seated),
        reason: 'Expire frees the seat — it must not auto-sit.',
      );
    });

    test('overshoot tick still expires at zero (no negative remaining)', () {
      const coming = ComingHoldState(
        phase: ComingHoldPhase.coming,
        seatIndex: 0,
        remaining: Duration(seconds: 10),
      );

      final next = reduceComingHold(
        current: coming,
        event: ComingHoldEvent.tick,
        elapsed: const Duration(seconds: 30),
      );

      expect(next.phase, ComingHoldPhase.expired);
      expect(next.remaining, Duration.zero);
      expect(next.seatFreed, isTrue);
      expect(next.shouldNudgeSpotOpen, isTrue);
    });
  });

  group('Coming: open app → I\'m in (sit) or Can\'t (release); no auto-sit',
      () {
    test('tick while Coming never auto-sits', () {
      var state = reduceComingHold(
        current: ComingHoldState.idle,
        event: ComingHoldEvent.startComing,
        seatIndex: 3,
        userId: 'u1',
      );

      for (var i = 0; i < 5; i++) {
        state = reduceComingHold(
          current: state,
          event: ComingHoldEvent.tick,
          elapsed: const Duration(seconds: 30),
        );
        expect(
          state.phase,
          ComingHoldPhase.coming,
          reason: 'Clock-only ticks must stay Coming — no auto-sit.',
        );
        expect(state.holdsSeat, isTrue);
      }

      expect(state.remaining, const Duration(seconds: 150));
      expect(state.phase, isNot(ComingHoldPhase.seated));
    });

    test('I\'m in (sit) seats and keeps the seat — no spot-open nudge', () {
      var nudgeFired = false;
      final coming = reduceComingHold(
        current: ComingHoldState.idle,
        event: ComingHoldEvent.startComing,
        seatIndex: 1,
        userId: 'u1',
      );

      final seated = reduceComingHold(
        current: coming,
        event: ComingHoldEvent.sit,
        onSpotOpenNudge: () => nudgeFired = true,
      );

      expect(seated.phase, ComingHoldPhase.seated);
      expect(seated.holdsSeat, isTrue);
      expect(seated.seatFreed, isFalse);
      expect(seated.shouldNudgeSpotOpen, isFalse);
      expect(nudgeFired, isFalse);
      expect(seated.seatIndex, 1);
      expect(seated.userId, 'u1');
    });

    test('Can\'t (release) frees the seat and fires the spot-open nudge', () {
      var nudgeFired = false;
      final coming = reduceComingHold(
        current: ComingHoldState.idle,
        event: ComingHoldEvent.startComing,
        seatIndex: 2,
        userId: 'u3',
      );

      final released = reduceComingHold(
        current: coming,
        event: ComingHoldEvent.release,
        onSpotOpenNudge: () => nudgeFired = true,
      );

      expect(released.phase, ComingHoldPhase.released);
      expect(released.holdsSeat, isFalse);
      expect(released.seatFreed, isTrue);
      expect(released.shouldNudgeSpotOpen, isTrue);
      expect(nudgeFired, isTrue);
      expect(released.phase, isNot(ComingHoldPhase.seated));
    });

    test('sit and release are no-ops from idle (must start Coming first)', () {
      final sit = reduceComingHold(
        current: ComingHoldState.idle,
        event: ComingHoldEvent.sit,
      );
      final release = reduceComingHold(
        current: ComingHoldState.idle,
        event: ComingHoldEvent.release,
      );

      expect(sit.phase, ComingHoldPhase.idle);
      expect(sit.holdsSeat, isFalse);
      expect(release.phase, ComingHoldPhase.idle);
      expect(release.seatFreed, isFalse);
    });

    test('sit after expire is a no-op (no late auto-sit)', () {
      const expired = ComingHoldState(
        phase: ComingHoldPhase.expired,
        seatIndex: 0,
        remaining: Duration.zero,
        shouldNudgeSpotOpen: true,
      );

      final next = reduceComingHold(
        current: expired,
        event: ComingHoldEvent.sit,
      );

      expect(next.phase, ComingHoldPhase.expired);
      expect(next.holdsSeat, isFalse);
      expect(next.seatFreed, isTrue);
    });
  });

  group('Pin expire: 45 min default (45–60 window) or owner ends early', () {
    test('default lifetime is 45 minutes inside the 45–60 window', () {
      expect(kPinExpireDefault, const Duration(minutes: 45));
      expect(kPinExpireWindowMin, const Duration(minutes: 45));
      expect(kPinExpireWindowMax, const Duration(minutes: 60));
      expect(
        kPinExpireDefault.inMinutes,
        inInclusiveRange(45, 60),
      );
    });

    test('start uses the 45 min default and is live', () {
      final live = reducePinExpire(
        current: PinExpireState.idle,
        event: PinExpireEvent.start,
        pinId: 'pin-1',
        ownerId: 'owner-1',
      );

      expect(live.phase, PinExpirePhase.live);
      expect(live.pinId, 'pin-1');
      expect(live.ownerId, 'owner-1');
      expect(live.remaining, kPinExpireDefault);
      expect(live.remaining.inMinutes, inInclusiveRange(45, 60));
      expect(live.isLive, isTrue);
      expect(live.isExpired, isFalse);
      expect(live.ownerEndedEarly, isFalse);
    });

    test('lifetime override in the 45–60 window is accepted', () {
      final live = reducePinExpire(
        current: PinExpireState.idle,
        event: PinExpireEvent.start,
        pinId: 'pin-60',
        lifetime: const Duration(minutes: 60),
      );

      expect(live.phase, PinExpirePhase.live);
      expect(live.remaining, const Duration(minutes: 60));
      expect(live.remaining.inMinutes, inInclusiveRange(45, 60));
    });

    test('lifetime outside 45–60 clamps to the 45 min default', () {
      final short = reducePinExpire(
        current: PinExpireState.idle,
        event: PinExpireEvent.start,
        lifetime: const Duration(minutes: 30),
      );
      final long = reducePinExpire(
        current: PinExpireState.idle,
        event: PinExpireEvent.start,
        lifetime: const Duration(minutes: 90),
      );

      expect(short.remaining, kPinExpireDefault);
      expect(long.remaining, kPinExpireDefault);
    });

    test('tick to t=0 expires the pin', () {
      final live = reducePinExpire(
        current: PinExpireState.idle,
        event: PinExpireEvent.start,
        pinId: 'pin-1',
      );

      final expired = reducePinExpire(
        current: live,
        event: PinExpireEvent.tick,
        elapsed: live.remaining,
      );

      expect(expired.phase, PinExpirePhase.expired);
      expect(expired.remaining, Duration.zero);
      expect(expired.isLive, isFalse);
      expect(expired.isExpired, isTrue);
      expect(expired.ownerEndedEarly, isFalse);
    });

    test('owner ends early while live (remaining still on the clock)', () {
      final live = reducePinExpire(
        current: PinExpireState.idle,
        event: PinExpireEvent.start,
        pinId: 'pin-1',
        ownerId: 'owner-1',
      );
      final stillLive = reducePinExpire(
        current: live,
        event: PinExpireEvent.tick,
        elapsed: const Duration(minutes: 10),
      );

      expect(stillLive.isLive, isTrue);
      expect(stillLive.remaining, const Duration(minutes: 35));

      final ended = reducePinExpire(
        current: stillLive,
        event: PinExpireEvent.ownerEnd,
      );

      expect(ended.phase, PinExpirePhase.endedEarly);
      expect(ended.isLive, isFalse);
      expect(ended.isExpired, isFalse);
      expect(ended.ownerEndedEarly, isTrue);
      expect(ended.pinId, 'pin-1');
    });

    test('ownerEnd after expire is a no-op', () {
      const expired = PinExpireState(
        phase: PinExpirePhase.expired,
        pinId: 'pin-1',
        remaining: Duration.zero,
      );

      final next = reducePinExpire(
        current: expired,
        event: PinExpireEvent.ownerEnd,
      );

      expect(next.phase, PinExpirePhase.expired);
      expect(next.ownerEndedEarly, isFalse);
    });
  });
}
