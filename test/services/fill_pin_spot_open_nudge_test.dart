import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/chat/fill_pin_thread_header.dart';
import 'package:squad_sync/domain/entities/lobby.dart';
import 'package:squad_sync/domain/entities/lobby_state.dart';
import 'package:squad_sync/services/coming_hold_machine.dart';
import 'package:squad_sync/services/fill_pin_live_activity.dart';
import 'package:squad_sync/services/peacock_self_notify.dart';

/// PIN WAVE — SPOT-OPEN NUDGE UI WIRE (RED, Tester-owned).
///
/// [coming_hold_machine] already frees the seat and stubs
/// [ComingHoldState.shouldNudgeSpotOpen] + [onSpotOpenNudge] on
/// expire (Coming → tick past remaining) and Can't / release.
/// Comments still say "UI wiring is later."
///
/// Prior P2 NUDGE AUDIENCE / WIRE slices filter UIDs on the LA
/// "need one" path (`fill_pin_nudge_audience` +
/// `fill_pin_live_activity`). This cut is **not** that, and is
/// **not** LA Widget Ext (`fill_pin_live_activity_buttons_test`).
/// This cut is specifically **spot-open into live friend UI** —
/// snackbar or pin-header cue — when Coming frees a seat.
///
/// Friend sees: expire or Can't → nudge surfaces. Idle / Sit stay
/// quiet (no seat-free). Reuse [reduceComingHold]. One notify
/// pipeline only. XOR stays [planPeacockSelfNotify].
///
/// Preferred Loop contract (header or thin nudge helper):
///
/// ```
/// String? fillPinSpotOpenNudgeCue(ComingHoldState? hold)
/// // non-null when hold.shouldNudgeSpotOpen (expire / Can't)
/// // null when idle / sit / coming-with-time / omitted
///
/// const kFillPinSpotOpenNudgeKey = Key('fill-pin-spot-open-nudge');
/// // and/or showFillPinSpotOpenNudge snackbar helper
/// ```
///
/// Wire [onSpotOpenNudge] and/or read [shouldNudgeSpotOpen] from
/// the header (or thin helper). Do **not** import
/// `fill_pin_live_activity.dart` from the header (cycle — live
/// activity already imports the header). Prefer a helper under
/// lease if apply / snackbar needs the LA path.
///
/// Adversarial RED asserts (FAIL until Loop greens):
///
/// 1. After expire (Coming → tick past remaining) or Can't /
///    release, the nudge flag/callback surfaces to a live UI path
///    (header cue key/text OR snackbar helper OR
///    [shouldNudgeSpotOpen] == true consumed by a named fill-pin
///    nudge surface Loop will add).
/// 2. Idle start / Sit path leaves the nudge quiet
///    ([shouldNudgeSpotOpen] false; no cue).
/// 3. Prefer a pure helper + source-scan that the header (or thin
///    nudge helper) wires [onSpotOpenNudge] / reads
///    [shouldNudgeSpotOpen] — FAIL until wired.
/// 4. No second notify pipeline (no FirebaseMessaging /
///    sendNotificationToUsers in the nudge surface).
/// 5. No lobby_notifier / message_bubble / chat_info_screen
///    dual-edit.
/// 6. XOR [planPeacockSelfNotify] guard.
///
/// Loop lease (Harness does not edit `lib/**` or bump pubspec;
/// still 3.4.181+183 until Loop greens → 3.4.182+184):
/// 1. `lib/services/coming_hold_machine.dart` — only if a tiny
///    helper is needed (prefer untouched)
/// 2. `lib/chat/fill_pin_thread_header.dart` OR a thin nudge
///    helper under lease (`fill_pin_spot_open_nudge.dart` /
///    `fill_pin_header_actions.dart`)
/// 3. `pubspec.yaml` bump to exactly `3.4.182+184` when Loop greens
///
/// Never dual-edit `lobby_notifier.dart`. No `message_bubble` /
/// `chat_info_screen` rewrite. No Tonight rewrite. Do not invent
/// a second FCM / send path. Do not duplicate LA Widget Ext.
///
/// Out of scope: GATES / AASA / Tonight / merge / device claim /
/// pubspec bump (Tester).
const _kHeader = 'lib/chat/fill_pin_thread_header.dart';
const _kComingHold = 'lib/services/coming_hold_machine.dart';
const _kLiveActivity = 'lib/services/fill_pin_live_activity.dart';
const _kLobbyNotifier = 'lib/presentation/notifiers/lobby_notifier.dart';
const _kMessageBubble = 'lib/chat/message_bubble.dart';
const _kChatInfo = 'lib/chat/screens/chat_info_screen.dart';
const _kHelperCandidates = [
  'lib/chat/fill_pin_spot_open_nudge.dart',
  'lib/services/fill_pin_spot_open_nudge.dart',
  'lib/chat/fill_pin_header_actions.dart',
];

const kFillPinSpotOpenNudgeKeyProbe = Key('fill-pin-spot-open-nudge');

String _read(String path) => File(path).readAsStringSync();

/// Header plus any Loop helper file under lease. Not LA / machine.
String _nudgeLeaseSource() {
  final chunks = [_read(_kHeader)];
  for (final path in _kHelperCandidates) {
    if (File(path).existsSync()) {
      chunks.add(_read(path));
    }
  }
  return chunks.join('\n');
}

bool _leaseDeclaresSpotOpenHelper(String src) {
  return src.contains('fillPinSpotOpenNudgeCue') ||
      src.contains('showFillPinSpotOpenNudge');
}

bool _leaseReadsSpotOpenFlag(String src) {
  return src.contains('shouldNudgeSpotOpen') ||
      src.contains('onSpotOpenNudge');
}

bool _leaseHasSpotOpenSurface(String src) {
  return src.contains('kFillPinSpotOpenNudgeKey') ||
      src.contains('fill-pin-spot-open-nudge') ||
      src.contains('showFillPinSpotOpenNudge') ||
      src.contains('fillPinSpotOpenNudgeSnack') ||
      src.contains('SnackBar') ||
      src.contains('showSnackBar');
}

Object? _tryDyn(Object? Function() read) {
  try {
    return read();
  } on NoSuchMethodError {
    return null;
  }
}

/// Loop may hang the cue on [FillPinSnapshot] (spotOpenNudge /
/// spotOpenNudgeCue / spotOpenCue). Missing getters stay null on RED.
Object? _readSnapshotSpotOpenCue(FillPinSnapshot? snapshot) {
  if (snapshot == null) return null;
  final dyn = snapshot as dynamic;
  return _tryDyn(() => dyn.spotOpenNudge) ??
      _tryDyn(() => dyn.spotOpenNudgeCue) ??
      _tryDyn(() => dyn.spotOpenCue);
}

bool _liveNudgeVisible() {
  return find.byKey(kFillPinSpotOpenNudgeKeyProbe).evaluate().isNotEmpty ||
      find.byType(SnackBar).evaluate().isNotEmpty ||
      find.textContaining('Spot open', findRichText: true).evaluate().isNotEmpty ||
      find.textContaining('Need one', findRichText: true).evaluate().isNotEmpty ||
      find.textContaining('seat open', findRichText: true).evaluate().isNotEmpty ||
      find.textContaining('Seat open', findRichText: true).evaluate().isNotEmpty;
}

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

FillPinSnapshot _snapshot() {
  return const FillPinSnapshot(
    lobbyId: 'pin-1',
    gameName: 'Warzone',
    seated: 1,
    maxSpots: 4,
    seatedUids: ['u1'],
    displayNames: {'u1': 'Alex'},
  );
}

Future<void> _pumpHeader(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: FillPinThreadHeader(
          snapshot: _snapshot(),
          chatGroupId: 'group-1',
        ),
      ),
    ),
  );
}

Future<String?> _capture(FillPinLiveActivityPlan plan) async {
  return plan.op == FillPinLiveActivityOp.start
      ? 'act-pin-1'
      : plan.payload.activityId;
}

void main() {
  setUp(FillPinLiveActivity.resetTestHooks);
  tearDown(FillPinLiveActivity.resetTestHooks);

  group('machine reuse — expire / Can\'t nudge; idle / sit quiet', () {
    test('expire (Coming → tick past remaining) sets shouldNudgeSpotOpen', () {
      var nudged = false;
      final expired = reduceComingHold(
        current: _startComing(),
        event: ComingHoldEvent.tick,
        elapsed: kComingHoldDuration,
        onSpotOpenNudge: () => nudged = true,
      );

      expect(expired.phase, ComingHoldPhase.expired);
      expect(expired.seatFreed, isTrue);
      expect(expired.shouldNudgeSpotOpen, isTrue);
      expect(nudged, isTrue);
      expect(expired.phase, isNot(ComingHoldPhase.seated));
    });

    test('Can\'t / release frees the seat and sets shouldNudgeSpotOpen', () {
      var nudged = false;
      final released = reduceComingHold(
        current: _startComing(),
        event: ComingHoldEvent.release,
        onSpotOpenNudge: () => nudged = true,
      );

      expect(released.phase, ComingHoldPhase.released);
      expect(released.seatFreed, isTrue);
      expect(released.shouldNudgeSpotOpen, isTrue);
      expect(nudged, isTrue);
    });

    test('idle start and Sit leave shouldNudgeSpotOpen quiet', () {
      var idleNudged = false;
      final idle = reduceComingHold(
        current: ComingHoldState.idle,
        event: ComingHoldEvent.sit,
        onSpotOpenNudge: () => idleNudged = true,
      );
      expect(ComingHoldState.idle.shouldNudgeSpotOpen, isFalse);
      expect(idle.shouldNudgeSpotOpen, isFalse);
      expect(idleNudged, isFalse);

      var sitNudged = false;
      final coming = _startComing();
      expect(coming.shouldNudgeSpotOpen, isFalse);
      final seated = reduceComingHold(
        current: coming,
        event: ComingHoldEvent.sit,
        onSpotOpenNudge: () => sitNudged = true,
      );
      expect(seated.phase, ComingHoldPhase.seated);
      expect(seated.shouldNudgeSpotOpen, isFalse);
      expect(sitNudged, isFalse);
      expect(seated.seatFreed, isFalse);
    });
  });

  group('named fill-pin nudge surface consumes shouldNudgeSpotOpen', () {
    test('header or thin helper declares fillPinSpotOpenNudgeCue', () {
      expect(File(_kHeader).existsSync(), isTrue);
      expect(File(_kComingHold).existsSync(), isTrue);
      final src = _nudgeLeaseSource();
      expect(
        _leaseDeclaresSpotOpenHelper(src),
        isTrue,
        reason:
            'Loop lease: add fillPinSpotOpenNudgeCue(ComingHoldState? hold) '
            'on $_kHeader (or a thin fill_pin_spot_open_nudge / '
            'fill_pin_header_actions helper). Non-null when '
            'hold.shouldNudgeSpotOpen (expire / Can\'t); null when '
            'idle / sit / coming-with-time. FAIL until the named '
            'surface exists. Do not treat LA Widget Ext as this cut.',
      );
    });

    test(
      'header or thin helper reads shouldNudgeSpotOpen / wires onSpotOpenNudge',
      () {
        final src = _nudgeLeaseSource();
        expect(
          _leaseReadsSpotOpenFlag(src),
          isTrue,
          reason:
              'Loop lease: header (or thin nudge helper) must read '
              'shouldNudgeSpotOpen and/or wire onSpotOpenNudge into the '
              'live snackbar / pin-header cue. coming_hold_machine stub '
              'alone is not UI wiring. FAIL until the live surface '
              'consumes the flag.',
        );
      },
    );

    test(
      'expire / Can\'t cue hangs on snapshot, helper, header key, or snackbar',
      () {
        final lobby = _pin(id: 'pin-1', chatGroupId: 'group-1');
        final expired = reduceComingHold(
          current: _startComing(),
          event: ComingHoldEvent.tick,
          elapsed: kComingHoldDuration,
        );
        final released = reduceComingHold(
          current: _startComing(),
          event: ComingHoldEvent.release,
        );
        expect(expired.shouldNudgeSpotOpen, isTrue);
        expect(released.shouldNudgeSpotOpen, isTrue);

        final expiredSnap = resolveFillPinForThread(
          state: _stateWithPin(lobby),
          chatGroupId: 'group-1',
          hold: expired,
        );
        final releasedSnap = resolveFillPinForThread(
          state: _stateWithPin(lobby),
          chatGroupId: 'group-1',
          hold: released,
        );

        final src = _nudgeLeaseSource();
        final consumed = _readSnapshotSpotOpenCue(expiredSnap) != null ||
            _readSnapshotSpotOpenCue(releasedSnap) != null ||
            _leaseDeclaresSpotOpenHelper(src) ||
            _leaseHasSpotOpenSurface(src);
        expect(
          consumed,
          isTrue,
          reason:
              'After expire or Can\'t, shouldNudgeSpotOpen must reach a '
              'live UI path. Loop: populate FillPinSnapshot.spotOpenNudge '
              '(or spotOpenNudgeCue), add fillPinSpotOpenNudgeCue, and/or '
              'show Key(\'fill-pin-spot-open-nudge\') / a snackbar helper. '
              'Machine stub without UI is not enough.',
        );
      },
    );
  });

  group('live header cue / snackbar after seat-free; quiet when idle / sit',
      () {
    testWidgets('Can\'t from Coming surfaces the spot-open cue or snackbar',
        (tester) async {
      FillPinLiveActivity.invokeHook = _capture;
      FillPinLiveActivity.currentUidHook = () => 'u9';
      await FillPinLiveActivity.applyIncomingChannelArgs({
        'actionId': 'coming',
        'chatGroupId': 'group-1',
        'pinId': 'pin-1',
      });
      expect(FillPinLiveActivity.debugHold.phase, ComingHoldPhase.coming);

      await _pumpHeader(tester);
      expect(find.byKey(kFillPinThreadHeaderKey), findsOneWidget);
      await tester.tap(find.byKey(const Key('fill-pin-cant')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(FillPinLiveActivity.debugHold.shouldNudgeSpotOpen, isTrue);
      expect(
        _liveNudgeVisible(),
        isTrue,
        reason:
            'Friend-visible spot-open nudge missing after Can\'t frees '
            'a seat. Show Key(\'fill-pin-spot-open-nudge\') on the pin '
            'header and/or a snackbar (Spot open / Need one). Reuse '
            'coming_hold_machine — do not invent a second notify path.',
      );
    });

    testWidgets('expire tick surfaces the spot-open cue or snackbar',
        (tester) async {
      FillPinLiveActivity.invokeHook = _capture;
      FillPinLiveActivity.currentUidHook = () => 'u9';
      await FillPinLiveActivity.applyIncomingChannelArgs({
        'actionId': 'coming',
        'chatGroupId': 'group-1',
        'pinId': 'pin-1',
      });
      await FillPinLiveActivity.tick(
        chatGroupId: 'group-1',
        snapshot: _snapshot(),
        elapsed: kComingHoldDuration,
      );
      expect(FillPinLiveActivity.debugHold.phase, ComingHoldPhase.expired);
      expect(FillPinLiveActivity.debugHold.shouldNudgeSpotOpen, isTrue);

      await _pumpHeader(tester);
      await tester.pump();

      expect(
        _liveNudgeVisible(),
        isTrue,
        reason:
            'Friend-visible spot-open nudge missing after Coming '
            'expires (tick past remaining). Header cue key/text or '
            'snackbar must consume shouldNudgeSpotOpen. FAIL until '
            'wired into live UI.',
      );
    });

    testWidgets('idle header leaves the spot-open nudge quiet', (tester) async {
      await _pumpHeader(tester);
      expect(find.byKey(kFillPinThreadHeaderKey), findsOneWidget);
      expect(ComingHoldState.idle.shouldNudgeSpotOpen, isFalse);
      expect(
        _liveNudgeVisible(),
        isFalse,
        reason: 'Idle start must not show a spot-open cue or snackbar.',
      );
    });

    testWidgets('Sit path leaves the spot-open nudge quiet', (tester) async {
      FillPinLiveActivity.invokeHook = _capture;
      FillPinLiveActivity.currentUidHook = () => 'u2';
      await _pumpHeader(tester);
      await tester.tap(find.byKey(const Key('fill-pin-sit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(FillPinLiveActivity.debugHold.phase, ComingHoldPhase.seated);
      expect(FillPinLiveActivity.debugHold.shouldNudgeSpotOpen, isFalse);
      expect(
        _liveNudgeVisible(),
        isFalse,
        reason:
            'Sit keeps the seat — no seat-free, so the spot-open cue '
            'must stay quiet.',
      );
    });
  });

  group('one notify pipeline — XOR planPeacockSelfNotify', () {
    test('nudge surface does not invent FirebaseMessaging / sendNotification',
        () {
      final src = _nudgeLeaseSource();
      expect(src.contains('sendNotificationToUsers'), isFalse);
      expect(src.contains('FirebaseMessaging'), isFalse);
      expect(src.contains('NotificationService'), isFalse);

      final header = _read(_kHeader);
      expect(
        header.contains('fill_pin_live_activity.dart'),
        isFalse,
        reason:
            'Do not import fill_pin_live_activity.dart from '
            '$_kHeader (cycle). Put apply / snackbar wiring in a '
            'helper under lease.',
      );

      expect(_read(_kComingHold).contains('sendNotificationToUsers'), isFalse);
      expect(_read(_kComingHold).contains('FirebaseMessaging'), isFalse);
      expect(_read(_kComingHold).contains('onSpotOpenNudge'), isTrue);
      expect(_read(_kComingHold).contains('shouldNudgeSpotOpen'), isTrue);
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
      expect(
        _read(_kLiveActivity).contains('planPeacockSelfNotify'),
        isTrue,
      );
      expect(
        _nudgeLeaseSource().contains('FirebaseMessaging'),
        isFalse,
      );
    });

    test('lobby_notifier / bubble / chat_info are not the spot-open lease', () {
      expect(_read(_kLobbyNotifier).contains('shouldNudgeSpotOpen'), isFalse);
      expect(_read(_kLobbyNotifier).contains('onSpotOpenNudge'), isFalse);
      expect(_read(_kLobbyNotifier).contains('fillPinSpotOpenNudgeCue'), isFalse);
      expect(_read(_kLobbyNotifier).contains('fill_pin_spot_open_nudge'), isFalse);
      expect(_read(_kMessageBubble).contains('shouldNudgeSpotOpen'), isFalse);
      expect(_read(_kMessageBubble).contains('fillPinSpotOpenNudgeCue'), isFalse);
      expect(_read(_kChatInfo).contains('shouldNudgeSpotOpen'), isFalse);
      expect(_read(_kChatInfo).contains('fillPinSpotOpenNudgeCue'), isFalse);
    });
  });
}
