import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/chat/fill_pin_thread_header.dart';
import 'package:squad_sync/services/coming_hold_machine.dart';
import 'package:squad_sync/services/fill_pin_live_activity.dart';
import 'package:squad_sync/services/peacock_self_notify.dart';

/// PIN WAVE — FILL PIN HEADER Sit / Coming / Can't (RED).
///
/// LA lock-screen Sit / Coming / Can't is CLOSED via Widget Ext +
/// [FillPinLiveActivity.applyChannelAction] /
/// [applyIncomingChannelArgs] (see
/// `test/services/fill_pin_live_activity_buttons_test.dart`).
/// Header already has poll / public / share chrome +
/// [FillPinSnapshot.comingCountdown] — **no Sit / Coming / Can't
/// friend-visible row yet**.
///
/// Friend tap on Fill PIN header: compact Sit / Coming / Can't row
/// beside poll / public / share. Same semantics as LA App Intents:
/// - Sit → seats (I'm in)
/// - Coming → 300s hold, no auto-sit via [coming_hold_machine]
/// - Can't → releases
///
/// Reuse the existing apply / hold path. Not a new notify pipeline.
/// Not Widget Ext / not device.
///
/// Cycle: do **not** import `fill_pin_live_activity.dart` from
/// `fill_pin_thread_header.dart` (coming-chrome suite forbids it).
/// Prefer a dedicated helper under lease:
///
/// ```
/// lib/chat/fill_pin_header_actions.dart
/// // or lib/services/fill_pin_header_actions.dart
/// ```
///
/// that calls [FillPinLiveActivity.applyIncomingChannelArgs] /
/// [applyChannelAction] (or [applyFillPinLiveActivityAction]).
/// Header imports the helper — not live_activity. Thin wrappers
/// in the header that delegate to that helper are fine.
///
/// Preferred friend-visible keys (header or helper):
///
/// ```
/// const kFillPinSitKey    = Key('fill-pin-sit');
/// const kFillPinComingKey = Key('fill-pin-coming');
/// const kFillPinCantKey   = Key('fill-pin-cant');
/// ```
///
/// Labels: Sit / Coming / Can't (reuse
/// [kFillPinLiveActivitySitLabel] /
/// [kFillPinLiveActivityComingLabel] /
/// [kFillPinLiveActivityCantLabel] or the same strings).
///
/// FAIL-until-green contracts (adversarial):
///
/// 1. Header source (or a dedicated header-actions helper) exposes
///    Sit / Coming / Can't friend-visible controls
///    (keys / labels / widgets) — FAIL until present.
/// 2. Coming path starts 300s hold and does not sit
///    ([ComingHoldPhase.coming], remaining [kComingHoldDuration]).
/// 3. Sit path takes the seat ([ComingHoldPhase.seated]).
/// 4. Can't from Coming releases
///    ([ComingHoldPhase.released] / [ComingHoldState.seatFreed]).
/// 5. Prefer calling through the **same** apply path as LA
///    (`applyIncomingChannelArgs` / `applyChannelAction`) —
///    source-scan that header actions do not invent
///    FirebaseMessaging / sendNotificationToUsers.
/// 6. No lobby_notifier / message_bubble / chat_info_screen dual-edit.
/// 7. XOR [planPeacockSelfNotify] guard.
///
/// Hold semantics (2–4) are asserted two ways:
/// - Pure [applyIncomingChannelArgs] documents the shared reducer
///   Loop must reuse (already green on LA).
/// - Friend-tap on the header keys must drive that same apply path
///   ([FillPinLiveActivity.debugHold]) — FAIL until the row exists
///   and is wired.
///
/// Loop lease (Harness does not edit `lib/**` or bump pubspec;
/// still 3.4.180+182 until Loop greens → 3.4.181+183):
/// 1. `lib/chat/fill_pin_thread_header.dart` — primary; compact
///    Sit / Coming / Can't row beside poll / public / share
/// 2. Hold / apply helpers as needed (thin wrappers in header or
///    a dedicated `fill_pin_header_actions.dart` that calls
///    existing `fill_pin_live_activity.dart` apply — keep ≤3
///    product files)
/// 3. `pubspec.yaml` bump to exactly `3.4.181+183` when Loop greens
///
/// Never dual-edit `lobby_notifier.dart`. No `message_bubble` /
/// `chat_info_screen` rewrite. No `ios/**` this slice.
///
/// Out of scope: GATES / AASA / Tonight / merge / device claim /
/// Widget Ext / pubspec bump (Tester).
const _kHeader = 'lib/chat/fill_pin_thread_header.dart';
const _kLiveActivity = 'lib/services/fill_pin_live_activity.dart';
const _kComingHold = 'lib/services/coming_hold_machine.dart';
const _kLobbyNotifier = 'lib/presentation/notifiers/lobby_notifier.dart';
const _kMessageBubble = 'lib/chat/message_bubble.dart';
const _kChatInfo = 'lib/chat/screens/chat_info_screen.dart';
const _kHelperCandidates = [
  'lib/chat/fill_pin_header_actions.dart',
  'lib/services/fill_pin_header_actions.dart',
];

const kFillPinSitKeyProbe = Key('fill-pin-sit');
const kFillPinComingKeyProbe = Key('fill-pin-coming');
const kFillPinCantKeyProbe = Key('fill-pin-cant');

String _read(String path) => File(path).readAsStringSync();

/// Header plus any Loop helper file under lease.
String _actionLeaseSource() {
  final chunks = [_read(_kHeader)];
  for (final path in _kHelperCandidates) {
    if (File(path).existsSync()) {
      chunks.add(_read(path));
    }
  }
  return chunks.join('\n');
}

bool _exposesSitComingCant(String src) {
  final sit = src.contains('kFillPinSitKey') || src.contains('fill-pin-sit');
  final coming = src.contains('kFillPinComingKey') ||
      src.contains('fill-pin-coming');
  final cant = src.contains('kFillPinCantKey') || src.contains('fill-pin-cant');
  return sit && coming && cant;
}

bool _usesLaApplyPath(String src) {
  return src.contains('applyIncomingChannelArgs') ||
      src.contains('applyChannelAction') ||
      src.contains('applyFillPinLiveActivityAction');
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

  group('header exposes Sit / Coming / Can\'t friend-visible controls', () {
    test('header or helper declares Sit / Coming / Can\'t keys', () {
      expect(File(_kHeader).existsSync(), isTrue);
      final src = _actionLeaseSource();
      expect(
        _exposesSitComingCant(src),
        isTrue,
        reason:
            'Loop lease: expose compact Sit / Coming / Can\'t on the '
            'Fill PIN header (or a dedicated header-actions helper). '
            'Prefer kFillPinSitKey / kFillPinComingKey / '
            'kFillPinCantKey (fill-pin-sit / fill-pin-coming / '
            'fill-pin-cant) beside poll / public / share. FAIL until '
            'those friend-visible controls exist.',
      );
    });

    testWidgets('header row shows Sit / Coming / Can\'t keys', (tester) async {
      await _pumpHeader(tester);

      expect(find.byKey(kFillPinThreadHeaderKey), findsOneWidget);
      expect(find.byKey(kFillPinPollKey), findsOneWidget);
      expect(find.byKey(kFillPinPublicSwitchKey), findsOneWidget);
      expect(find.byKey(kFillPinShareKey), findsOneWidget);

      expect(
        find.byKey(kFillPinSitKeyProbe),
        findsOneWidget,
        reason:
            'Friend-visible Sit control missing. Add Key(\'fill-pin-sit\') '
            '/ kFillPinSitKey on the header row.',
      );
      expect(
        find.byKey(kFillPinComingKeyProbe),
        findsOneWidget,
        reason:
            'Friend-visible Coming control missing. Add '
            'Key(\'fill-pin-coming\') / kFillPinComingKey on the '
            'header row.',
      );
      expect(
        find.byKey(kFillPinCantKeyProbe),
        findsOneWidget,
        reason:
            'Friend-visible Can\'t control missing. Add '
            'Key(\'fill-pin-cant\') / kFillPinCantKey on the header '
            'row.',
      );
    });

    test('header or helper labels Sit / Coming / Can\'t', () {
      final src = _actionLeaseSource();
      final sit = src.contains("'Sit'") ||
          src.contains('"Sit"') ||
          src.contains('kFillPinLiveActivitySitLabel');
      final coming = src.contains("'Coming'") ||
          src.contains('"Coming"') ||
          src.contains('kFillPinLiveActivityComingLabel');
      final cant = src.contains('"Can\'t"') ||
          src.contains(r"'Can\'t'") ||
          src.contains('kFillPinLiveActivityCantLabel');
      expect(
        sit && coming && cant,
        isTrue,
        reason:
            'Loop lease: friend-visible labels Sit / Coming / Can\'t '
            '(tooltip, Semantics, or text). Reuse '
            'kFillPinLiveActivitySitLabel / ComingLabel / CantLabel '
            'or the same strings. Compact IconButtons like poll / '
            'share are fine.',
      );
    });
  });

  group('Coming / Sit / Can\'t reuse the LA apply path', () {
    test('Coming from applyIncomingChannelArgs starts 300s hold, no sit',
        () async {
      FillPinLiveActivity.invokeHook = _capture;
      FillPinLiveActivity.currentUidHook = () => 'u9';

      final hold = await FillPinLiveActivity.applyIncomingChannelArgs({
        'actionId': 'coming',
        'chatGroupId': 'group-1',
        'pinId': 'pin-1',
      });

      expect(hold.phase, ComingHoldPhase.coming);
      expect(hold.remaining, kComingHoldDuration);
      expect(hold.phase, isNot(ComingHoldPhase.seated));
      expect(hold.holdsSeat, isTrue);
    });

    test('Sit from applyIncomingChannelArgs takes the seat', () async {
      FillPinLiveActivity.invokeHook = _capture;
      FillPinLiveActivity.currentUidHook = () => 'u2';

      final hold = await FillPinLiveActivity.applyIncomingChannelArgs({
        'actionId': 'sit',
        'chatGroupId': 'group-1',
        'pinId': 'pin-1',
      });

      expect(hold.phase, ComingHoldPhase.seated);
      expect(hold.holdsSeat, isTrue);
    });

    test('Can\'t from Coming via applyIncomingChannelArgs releases', () async {
      FillPinLiveActivity.invokeHook = _capture;
      await FillPinLiveActivity.applyIncomingChannelArgs({
        'actionId': 'coming',
        'chatGroupId': 'group-1',
        'pinId': 'pin-1',
      });
      final released = await FillPinLiveActivity.applyIncomingChannelArgs({
        'actionId': 'cant',
        'chatGroupId': 'group-1',
        'pinId': 'pin-1',
      });

      expect(released.phase, ComingHoldPhase.released);
      expect(released.seatFreed, isTrue);
    });

    testWidgets('Coming tap on header starts 300s hold and does not sit',
        (tester) async {
      FillPinLiveActivity.invokeHook = _capture;
      FillPinLiveActivity.currentUidHook = () => 'u9';
      await _pumpHeader(tester);

      expect(
        find.byKey(kFillPinComingKeyProbe),
        findsOneWidget,
        reason:
            'Loop lease: Coming on the header must call the same '
            'applyIncomingChannelArgs / applyChannelAction path as LA. '
            'Add the Coming control first.',
      );
      await tester.tap(find.byKey(kFillPinComingKeyProbe));
      await tester.pump();

      final hold = FillPinLiveActivity.debugHold;
      expect(hold.phase, ComingHoldPhase.coming);
      expect(hold.remaining, kComingHoldDuration);
      expect(hold.phase, isNot(ComingHoldPhase.seated));
      expect(hold.holdsSeat, isTrue);
    });

    testWidgets('Sit tap on header takes the seat', (tester) async {
      FillPinLiveActivity.invokeHook = _capture;
      FillPinLiveActivity.currentUidHook = () => 'u2';
      await _pumpHeader(tester);

      expect(
        find.byKey(kFillPinSitKeyProbe),
        findsOneWidget,
        reason:
            'Loop lease: Sit on the header must call the same '
            'applyIncomingChannelArgs / applyChannelAction path as LA.',
      );
      await tester.tap(find.byKey(kFillPinSitKeyProbe));
      await tester.pump();

      final hold = FillPinLiveActivity.debugHold;
      expect(hold.phase, ComingHoldPhase.seated);
      expect(hold.holdsSeat, isTrue);
    });

    testWidgets('Can\'t tap from Coming on header releases', (tester) async {
      FillPinLiveActivity.invokeHook = _capture;
      FillPinLiveActivity.currentUidHook = () => 'u9';
      await FillPinLiveActivity.applyIncomingChannelArgs({
        'actionId': 'coming',
        'chatGroupId': 'group-1',
        'pinId': 'pin-1',
      });
      expect(FillPinLiveActivity.debugHold.phase, ComingHoldPhase.coming);

      await _pumpHeader(tester);
      expect(
        find.byKey(kFillPinCantKeyProbe),
        findsOneWidget,
        reason:
            'Loop lease: Can\'t on the header must call the same '
            'applyIncomingChannelArgs / applyChannelAction path as LA.',
      );
      await tester.tap(find.byKey(kFillPinCantKeyProbe));
      await tester.pump();

      final released = FillPinLiveActivity.debugHold;
      expect(released.phase, ComingHoldPhase.released);
      expect(released.seatFreed, isTrue);
    });
  });

  group('Coming duration 300s — header must not invent auto-sit', () {
    test('kComingHoldDuration is 300 seconds (5:00)', () {
      expect(kComingHoldDuration, const Duration(seconds: 300));
      expect(kComingHoldDuration.inMinutes, 5);
    });

    test('tick while Coming never auto-sits (machine invariant)', () {
      var hold = reduceComingHold(
        current: ComingHoldState.idle,
        event: ComingHoldEvent.startComing,
        seatIndex: 2,
        pinId: 'pin-1',
        userId: 'u9',
      );
      expect(hold.phase, ComingHoldPhase.coming);
      expect(hold.remaining, kComingHoldDuration);

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
  });

  group('header actions reuse LA apply — no second notify path', () {
    test('header or helper calls applyIncomingChannelArgs / applyChannelAction',
        () {
      final src = _actionLeaseSource();
      expect(
        _usesLaApplyPath(src),
        isTrue,
        reason:
            'Loop lease: header actions must reuse '
            'FillPinLiveActivity.applyIncomingChannelArgs / '
            'applyChannelAction (or applyFillPinLiveActivityAction). '
            'Do not invent a second hold reducer. Prefer a dedicated '
            'helper (fill_pin_header_actions.dart) so the header does '
            'not import fill_pin_live_activity.dart (cycle).',
      );
    });

    test('header does not import live_activity (cycle) or send notify', () {
      final header = _read(_kHeader);
      expect(
        header.contains('fill_pin_live_activity.dart'),
        isFalse,
        reason:
            'Do not import fill_pin_live_activity.dart from '
            '$_kHeader (cycle — live activity already imports the '
            'header). Put apply wiring in a helper under lease.',
      );
      expect(header.contains('sendNotificationToUsers'), isFalse);
      expect(header.contains('FirebaseMessaging'), isFalse);
      expect(header.contains('NotificationService'), isFalse);

      for (final path in _kHelperCandidates) {
        if (!File(path).existsSync()) continue;
        final helper = _read(path);
        expect(helper.contains('sendNotificationToUsers'), isFalse);
        expect(helper.contains('FirebaseMessaging'), isFalse);
        expect(helper.contains('NotificationService'), isFalse);
      }

      expect(_read(_kComingHold).contains('sendNotificationToUsers'), isFalse);
      expect(_read(_kComingHold).contains('FirebaseMessaging'), isFalse);
      expect(_read(_kLiveActivity).contains('applyIncomingChannelArgs'), isTrue);
      expect(_read(_kLiveActivity).contains('applyChannelAction'), isTrue);
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
    });

    test('lobby_notifier / bubble / chat_info are not the header-actions lease',
        () {
      expect(_read(_kLobbyNotifier).contains('fill-pin-sit'), isFalse);
      expect(_read(_kLobbyNotifier).contains('kFillPinSitKey'), isFalse);
      expect(_read(_kLobbyNotifier).contains('fill_pin_header_actions'), isFalse);
      expect(_read(_kMessageBubble).contains('fill-pin-sit'), isFalse);
      expect(_read(_kMessageBubble).contains('fill_pin_header_actions'), isFalse);
      expect(_read(_kChatInfo).contains('fill-pin-sit'), isFalse);
      expect(_read(_kChatInfo).contains('fill_pin_header_actions'), isFalse);
    });
  });
}
