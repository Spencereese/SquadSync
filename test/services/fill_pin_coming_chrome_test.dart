import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/chat/fill_pin_thread_header.dart';
import 'package:squad_sync/domain/entities/lobby.dart';
import 'package:squad_sync/domain/entities/lobby_state.dart';
import 'package:squad_sync/services/coming_hold_machine.dart';
import 'package:squad_sync/services/fill_pin_live_activity.dart';
import 'package:squad_sync/services/peacock_self_notify.dart';

/// PIN WAVE — COMING COUNTDOWN CHROME on Fill PIN header (RED).
///
/// Friend tap / live Coming hold: the pin header shows the countdown
/// label from [FillPinSnapshot.comingCountdown]. Header UI already
/// renders a non-null label. Resolver still leaves the stub null
/// ("Coming-hold countdown chrome is a later slice.").
///
/// Wire path Loop must implement:
/// [coming_hold_machine] → [resolveFillPinForThread] / header text.
/// Prefer a tiny pure helper in the header file:
///
/// ```
/// String? fillPinComingCountdownLabel(ComingHoldState? hold)
/// ```
///
/// and/or extend the resolver:
///
/// ```
/// FillPinSnapshot? resolveFillPinForThread({
///   required LobbyState? state,
///   required String? chatGroupId,
///   ComingHoldState? hold,
/// })
/// ```
///
/// Populate `comingCountdown:` on the returned snapshot. Do **not**
/// import `fill_pin_live_activity.dart` from the header (cycle — live
/// activity already imports the header). If mm:ss is reused, copy the
/// one-liner or add a tiny helper on [coming_hold_machine] (prefer
/// that file untouched).
///
/// FAIL-until-green contracts (adversarial):
///
/// 1. Active hold ([ComingHoldPhase.coming] + remaining > 0) →
///    [FillPinSnapshot.comingCountdown] is **non-null**, non-empty,
///    and includes a time-like token (`mm:ss` like `5:00` / `4:59`,
///    or the remaining seconds). Prefer
///    [formatComingHoldMmSs] shape (`5:00` at startComing).
/// 2. Idle / expired / released / seated (chrome-clearing phases) →
///    [comingCountdown] is **null**. Null / omitted hold stays null.
/// 3. Coming duration remains 300s / [kComingHoldDuration]. Tick
///    never auto-sits. Chrome must not invent auto-sit.
/// 4. Unit tests hit the resolver (named `hold`) and/or
///    [fillPinComingCountdownLabel]. Source-scan: header imports
///    `coming_hold_machine.dart` and assigns `comingCountdown:`.
/// 5. No second notify send path. XOR stays [planPeacockSelfNotify].
///
/// This file compiles on RED by probing the extended resolver via
/// [Function.apply] (`hold:`). Loop greens by adding that named
/// parameter (or the helper + resolver wire). Direct
/// `resolveFillPinForThread(hold: …)` is the intended product API.
///
/// Loop lease (Harness does not edit `lib/**` or bump pubspec;
/// still 3.4.179+181 until Loop greens → 3.4.180+182):
/// 1. `lib/chat/fill_pin_thread_header.dart` — wire
///    comingCountdown into resolveFillPinForThread / snapshot
/// 2. `lib/services/coming_hold_machine.dart` — only if a tiny
///    helper is needed (prefer untouched)
/// 3. `pubspec.yaml` bump to exactly `3.4.180+182` when Loop greens
///
/// Never dual-edit `lobby_notifier.dart`. No `message_bubble` /
/// `chat_info_screen` rewrite. Do not invent a second notify path.
///
/// Out of scope: GATES / AASA / Tonight / merge / device claim /
/// pubspec bump (Tester).
const _kHeader = 'lib/chat/fill_pin_thread_header.dart';
const _kComingHold = 'lib/services/coming_hold_machine.dart';
const _kLobbyNotifier = 'lib/presentation/notifiers/lobby_notifier.dart';
const _kMessageBubble = 'lib/chat/message_bubble.dart';
const _kChatInfo = 'lib/chat/screens/chat_info_screen.dart';

/// mm:ss (`5:00`, `4:59`, `0:01`) — preferred chrome token.
final _kMmSs = RegExp(r'\d+:\d{2}');

String _read(String path) => File(path).readAsStringSync();

Lobby _pin({
  required String id,
  required String chatGroupId,
  String gameName = 'Warzone',
  int maxSpots = 4,
  List<String?>? spots,
  List<String>? memberUids,
}) {
  return Lobby.create(
    name: '$gameName pin',
    gameName: gameName,
    maxSpots: maxSpots,
    createdBy: 'u1',
  ).copyWith(
    id: id,
    chatGroupId: chatGroupId,
    isActive: true,
    spots: spots ?? const ['u1', 'u2', null, null],
    memberUids: memberUids ?? const ['u1', 'u2'],
    createdAt: DateTime(2026, 9, 8),
  );
}

LobbyState _stateWithPin(Lobby lobby) {
  return LobbyState.initial().copyWith(
    selectedLobbyId: lobby.id,
    currentLobby: lobby,
    userLobbies: {lobby.id: lobby},
    userLobbyIds: [lobby.id],
    memberDisplayNames: const {
      'u1': 'Alex',
      'u2': 'Chris',
    },
    gameLobbySpots: {lobby.gameName: lobby.spots},
  );
}

ComingHoldState _startComing({
  String pinId = 'pin-1',
  String userId = 'u9',
  int seatIndex = 2,
}) {
  return reduceComingHold(
    current: ComingHoldState.idle,
    event: ComingHoldEvent.startComing,
    seatIndex: seatIndex,
    pinId: pinId,
    userId: userId,
  );
}

/// Loop must accept `ComingHoldState? hold` on [resolveFillPinForThread].
FillPinSnapshot? resolveFillPinForThreadWithHold({
  required LobbyState? state,
  required String? chatGroupId,
  ComingHoldState? hold,
}) {
  try {
    return Function.apply(
      resolveFillPinForThread,
      const [],
      {
        #state: state,
        #chatGroupId: chatGroupId,
        #hold: hold,
      },
    ) as FillPinSnapshot?;
  } on NoSuchMethodError catch (e) {
    fail(
      'Loop lease: resolveFillPinForThread must accept '
      'ComingHoldState? hold and set snapshot.comingCountdown '
      'from the Coming hold. ($e)',
    );
  } on ArgumentError catch (e) {
    fail(
      'Loop lease: resolveFillPinForThread must accept '
      'ComingHoldState? hold and set snapshot.comingCountdown '
      'from the Coming hold. ($e)',
    );
  }
}

void _expectTimeLikeChrome(String? label, ComingHoldState hold) {
  expect(
    label,
    isNotNull,
    reason:
        'Active Coming hold (phase=${hold.phase}, remaining='
        '${hold.remaining.inSeconds}s) must populate '
        'comingCountdown. Wire hold into resolveFillPinForThread '
        'or fillPinComingCountdownLabel.',
  );
  expect(label!.trim(), isNotEmpty);
  final mmSs = _kMmSs.hasMatch(label);
  final secondsToken = label.contains('${hold.remaining.inSeconds}');
  expect(
    mmSs || secondsToken,
    isTrue,
    reason:
        'comingCountdown must include remaining seconds or an '
        'mm:ss token. Prefer formatComingHoldMmSs '
        '(${formatComingHoldMmSs(hold.remaining)}). Do not import '
        'fill_pin_live_activity.dart from the header (cycle).',
  );
  if (mmSs) {
    expect(label, contains(formatComingHoldMmSs(hold.remaining)));
  }
}

void main() {
  group('Coming duration 300s — chrome must not invent auto-sit', () {
    test('kComingHoldDuration is 300 seconds (5:00)', () {
      expect(kComingHoldDuration, const Duration(seconds: 300));
      expect(kComingHoldDuration.inMinutes, 5);
    });

    test('tick while Coming never auto-sits (machine invariant)', () {
      var hold = _startComing();
      expect(hold.remaining, kComingHoldDuration);
      expect(hold.phase, ComingHoldPhase.coming);

      hold = reduceComingHold(
        current: hold,
        event: ComingHoldEvent.tick,
        elapsed: const Duration(seconds: 60),
      );
      expect(hold.phase, ComingHoldPhase.coming);
      expect(hold.remaining, const Duration(seconds: 240));
      expect(hold.phase, isNot(ComingHoldPhase.seated));
      expect(hold.holdsSeat, isTrue);
    });

    test('expire frees the seat — tick does not sit', () {
      final expired = reduceComingHold(
        current: _startComing(),
        event: ComingHoldEvent.tick,
        elapsed: kComingHoldDuration,
      );
      expect(expired.phase, ComingHoldPhase.expired);
      expect(expired.remaining, Duration.zero);
      expect(expired.phase, isNot(ComingHoldPhase.seated));
      expect(expired.seatFreed, isTrue);
    });
  });

  group('active Coming hold → comingCountdown non-null chrome', () {
    test('startComing (300s remaining) labels the pin header', () {
      final lobby = _pin(id: 'pin-1', chatGroupId: 'group-1');
      final hold = _startComing();
      expect(hold.phase, ComingHoldPhase.coming);
      expect(hold.remaining > Duration.zero, isTrue);

      final snapshot = resolveFillPinForThreadWithHold(
        state: _stateWithPin(lobby),
        chatGroupId: 'group-1',
        hold: hold,
      );

      expect(snapshot, isNotNull);
      _expectTimeLikeChrome(snapshot!.comingCountdown, hold);
    });

    test('tick that leaves time on the clock keeps chrome', () {
      final lobby = _pin(id: 'pin-1', chatGroupId: 'group-1');
      final hold = reduceComingHold(
        current: _startComing(),
        event: ComingHoldEvent.tick,
        elapsed: const Duration(seconds: 60),
      );
      expect(hold.phase, ComingHoldPhase.coming);
      expect(hold.remaining, const Duration(seconds: 240));
      expect(hold.phase, isNot(ComingHoldPhase.seated));

      final snapshot = resolveFillPinForThreadWithHold(
        state: _stateWithPin(lobby),
        chatGroupId: 'group-1',
        hold: hold,
      );

      expect(snapshot, isNotNull);
      _expectTimeLikeChrome(snapshot!.comingCountdown, hold);
    });
  });

  group('idle / expired / released / seated → comingCountdown null', () {
    test('omitted hold leaves comingCountdown stub-null', () {
      final lobby = _pin(id: 'pin-1', chatGroupId: 'group-1');
      final snapshot = resolveFillPinForThread(
        state: _stateWithPin(lobby),
        chatGroupId: 'group-1',
      );
      expect(snapshot, isNotNull);
      expect(snapshot!.comingCountdown, isNull);
    });

    test('idle hold clears chrome', () {
      final lobby = _pin(id: 'pin-1', chatGroupId: 'group-1');
      final snapshot = resolveFillPinForThreadWithHold(
        state: _stateWithPin(lobby),
        chatGroupId: 'group-1',
        hold: ComingHoldState.idle,
      );
      expect(snapshot, isNotNull);
      expect(snapshot!.comingCountdown, isNull);
    });

    test('expired hold (t=0) clears chrome', () {
      final lobby = _pin(id: 'pin-1', chatGroupId: 'group-1');
      final expired = reduceComingHold(
        current: _startComing(),
        event: ComingHoldEvent.tick,
        elapsed: kComingHoldDuration,
      );
      expect(expired.phase, ComingHoldPhase.expired);
      expect(expired.remaining, Duration.zero);

      final snapshot = resolveFillPinForThreadWithHold(
        state: _stateWithPin(lobby),
        chatGroupId: 'group-1',
        hold: expired,
      );
      expect(snapshot, isNotNull);
      expect(snapshot!.comingCountdown, isNull);
    });

    test('released (Can\'t) and seated (I\'m in) clear chrome', () {
      final lobby = _pin(id: 'pin-1', chatGroupId: 'group-1');
      final coming = _startComing();
      final released = reduceComingHold(
        current: coming,
        event: ComingHoldEvent.release,
      );
      final seated = reduceComingHold(
        current: coming,
        event: ComingHoldEvent.sit,
      );
      expect(released.phase, ComingHoldPhase.released);
      expect(seated.phase, ComingHoldPhase.seated);

      final releasedSnap = resolveFillPinForThreadWithHold(
        state: _stateWithPin(lobby),
        chatGroupId: 'group-1',
        hold: released,
      );
      final seatedSnap = resolveFillPinForThreadWithHold(
        state: _stateWithPin(lobby),
        chatGroupId: 'group-1',
        hold: seated,
      );
      expect(releasedSnap!.comingCountdown, isNull);
      expect(seatedSnap!.comingCountdown, isNull);
    });
  });

  group('header wires coming_hold_machine — no second notify path', () {
    test('header imports coming_hold_machine and assigns comingCountdown', () {
      expect(File(_kHeader).existsSync(), isTrue);
      expect(File(_kComingHold).existsSync(), isTrue);
      final src = _read(_kHeader);
      expect(src.contains('resolveFillPinForThread'), isTrue);
      expect(src.contains('comingCountdown'), isTrue);
      expect(
        src.contains('coming_hold_machine.dart'),
        isTrue,
        reason:
            'Loop lease: import coming_hold_machine.dart from '
            '$_kHeader so resolveFillPinForThread / '
            'fillPinComingCountdownLabel can read ComingHoldState.',
      );
      expect(
        src.contains('ComingHoldState'),
        isTrue,
        reason:
            'Loop lease: resolveFillPinForThread (or '
            'fillPinComingCountdownLabel) must take ComingHoldState.',
      );
      expect(
        RegExp(r'comingCountdown\s*:').hasMatch(src),
        isTrue,
        reason:
            'Wire comingCountdown: fillPinComingCountdownLabel(hold) '
            '(or equivalent) into the FillPinSnapshot returned by '
            'resolveFillPinForThread. Field default / typedef is '
            'not enough — resolver still leaves the stub null.',
      );
    });

    test('preferred helper fillPinComingCountdownLabel lives in header', () {
      final src = _read(_kHeader);
      expect(
        src.contains('fillPinComingCountdownLabel'),
        isTrue,
        reason:
            'Prefer fillPinComingCountdownLabel(ComingHoldState? hold) '
            'in $_kHeader (pure; Coming + remaining > 0 → label, '
            'else null). Resolver assigns comingCountdown from it.',
      );
    });

    test('header does not import live_activity (cycle) or send notify', () {
      final src = _read(_kHeader);
      expect(src.contains('fill_pin_live_activity.dart'), isFalse);
      expect(src.contains('sendNotificationToUsers'), isFalse);
      expect(src.contains('FirebaseMessaging'), isFalse);
      expect(src.contains('NotificationService'), isFalse);

      final hold = _read(_kComingHold);
      expect(hold.contains('sendNotificationToUsers'), isFalse);
      expect(hold.contains('FirebaseMessaging'), isFalse);
      expect(hold.contains('kComingHoldDuration'), isTrue);
    });

    test('XOR stays planPeacockSelfNotify — no second self-notify path', () {
      expect(
        planPeacockSelfNotify(
          notificationId: 'n1',
          currentUid: 'u1',
          isForeground: true,
          locallyPresentedIds: {},
        ).wouldDoubleNotifySelf,
        isFalse,
      );
    });

    test('lobby_notifier / bubble / chat_info are not the chrome lease', () {
      expect(_read(_kLobbyNotifier).contains('comingCountdown'), isFalse);
      expect(_read(_kLobbyNotifier).contains('fill_pin_thread_header'), isFalse);
      expect(_read(_kMessageBubble).contains('comingCountdown'), isFalse);
      expect(_read(_kChatInfo).contains('comingCountdown'), isFalse);
    });
  });
}
