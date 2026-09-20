import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/chat/fill_pin_header_actions.dart';
import 'package:squad_sync/chat/fill_pin_thread_header.dart';
import 'package:squad_sync/services/coming_hold_machine.dart';
import 'package:squad_sync/services/fill_pin_live_activity.dart';
import 'package:squad_sync/services/peacock_self_notify.dart';

/// PIN WAVE — SHORT FIX RED: drop [FillPinLiveActivity.debugHold]
/// prod fallback on [FillPinSpotOpenNudgeCue].
///
/// App Tester ANALYZE FAIL at tip `df929cf` / `3.4.182+184`:
/// `lib/chat/fill_pin_header_actions.dart:55` uses
/// `@visibleForTesting` [FillPinLiveActivity.debugHold]
/// (`invalid_use_of_visible_for_testing_member`).
///
/// Loop contract: **pass hold only**. Null hold ⇒ no cue
/// ([SizedBox.shrink]). Do not read LA debug hold from prod.
/// Expire / Can't still cue when [hold] is passed. One notify
/// pipeline only.
///
/// FAIL until prod callers drop `debugHold`.
///
/// Loop lease (Harness does not edit `lib/**` or bump pubspec;
/// still 3.4.182+184 until Loop greens → 3.4.183+185):
/// 1. `lib/chat/fill_pin_header_actions.dart` — drop `debugHold`
///    fallback; pass hold only
/// 2. Tiny related caller if needed (≤3) — header currently
///    builds `const FillPinSpotOpenNudgeCue()`; pass hold from
///    the live row so expire / Can't stay visible
/// 3. `pubspec.yaml` bump to exactly `3.4.183+185` when Loop greens
///
/// Never dual-edit `lobby_notifier.dart`. No `message_bubble` /
/// `chat_info_screen` rewrite. No GATES / AASA / Tonight / merge /
/// device. Groups-row Coming chrome RED is HOLD until this FIX
/// tip lands (Harness cuts that later — not this turn).
const _kHeaderActions = 'lib/chat/fill_pin_header_actions.dart';
const _kHeader = 'lib/chat/fill_pin_thread_header.dart';
const _kLiveActivity = 'lib/services/fill_pin_live_activity.dart';
const _kLobbyNotifier = 'lib/presentation/notifiers/lobby_notifier.dart';
const _kMessageBubble = 'lib/chat/message_bubble.dart';
const _kChatInfo = 'lib/chat/screens/chat_info_screen.dart';

/// Fill-PIN prod files that may not *call* [debugHold].
/// Definition stays on [FillPinLiveActivity] (`@visibleForTesting`).
const _kFillPinProdCallers = [
  'lib/chat/fill_pin_thread_header.dart',
  'lib/chat/fill_pin_group_row_badge.dart',
  'lib/core/fill_pin_suggestion_parser.dart',
  'lib/services/fill_pin_link_preview.dart',
  'lib/services/fill_pin_nudge_audience.dart',
  'lib/services/fill_pin_poll.dart',
  'lib/services/fill_pin_share.dart',
  'lib/services/fill_pin_visibility.dart',
];

String _read(String path) => File(path).readAsStringSync();

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

ComingHoldState _expiredHold() {
  return reduceComingHold(
    current: _startComing(),
    event: ComingHoldEvent.tick,
    elapsed: kComingHoldDuration,
  );
}

ComingHoldState _releasedHold() {
  return reduceComingHold(
    current: _startComing(),
    event: ComingHoldEvent.release,
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

Future<String?> _capture(FillPinLiveActivityPlan plan) async {
  return plan.op == FillPinLiveActivityOp.start
      ? 'act-pin-1'
      : plan.payload.activityId;
}

Future<void> _pumpCue(WidgetTester tester, {ComingHoldState? hold}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: FillPinSpotOpenNudgeCue(hold: hold),
      ),
    ),
  );
}

bool _cueVisible() {
  return find.byKey(kFillPinSpotOpenNudgeKey).evaluate().isNotEmpty ||
      find.text('Spot open').evaluate().isNotEmpty;
}

void main() {
  setUp(FillPinLiveActivity.resetTestHooks);
  tearDown(FillPinLiveActivity.resetTestHooks);

  group('prod ban — no debugHold fallback', () {
    test('fill_pin_header_actions.dart must not contain debugHold', () {
      expect(File(_kHeaderActions).existsSync(), isTrue);
      expect(
        _read(_kHeaderActions).contains('debugHold'),
        isFalse,
        reason:
            'ANALYZE FAIL: FillPinSpotOpenNudgeCue must not read '
            'FillPinLiveActivity.debugHold (@visibleForTesting). '
            'Loop: drop the hold ?? debugHold fallback; pass hold '
            'only. Null hold ⇒ no cue (SizedBox.shrink).',
      );
    });

    test('other fill-pin prod callers must not reference debugHold', () {
      for (final path in _kFillPinProdCallers) {
        if (!File(path).existsSync()) continue;
        expect(
          _read(path).contains('debugHold'),
          isFalse,
          reason:
              '$path is a non-test fill-pin prod caller. Do not '
              'read FillPinLiveActivity.debugHold from prod. '
              'Definition stays @visibleForTesting on '
              '$_kLiveActivity only.',
        );
      }
    });

    test('debugHold definition stays test-only on live activity', () {
      final src = _read(_kLiveActivity);
      expect(src.contains('@visibleForTesting'), isTrue);
      expect(src.contains('static ComingHoldState get debugHold'), isTrue);
    });
  });

  group('Loop contract — pass hold only; null hold ⇒ no cue', () {
    test('fillPinSpotOpenNudgeCue(null) is quiet (helper)', () {
      expect(fillPinSpotOpenNudgeCue(null), isNull);
      expect(fillPinSpotOpenNudgeCue(ComingHoldState.idle), isNull);
    });

    testWidgets(
      'null hold stays quiet even when LA debugHold would nudge',
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
        expect(FillPinLiveActivity.debugHold.shouldNudgeSpotOpen, isTrue);

        await _pumpCue(tester);
        expect(
          _cueVisible(),
          isFalse,
          reason:
              'Loop contract: pass hold only. FillPinSpotOpenNudgeCue '
              'with a null hold must stay quiet (SizedBox.shrink / no '
              'cue) without reading LA debugHold. Seeded expired '
              'debugHold must not leak a Spot open cue.',
        );
      },
    );
  });

  group('spot-open cue preserved when hold is passed', () {
    test('expire / Can\'t helper still returns Spot open', () {
      final expired = _expiredHold();
      final released = _releasedHold();
      expect(expired.shouldNudgeSpotOpen, isTrue);
      expect(released.shouldNudgeSpotOpen, isTrue);
      expect(fillPinSpotOpenNudgeCue(expired), 'Spot open');
      expect(fillPinSpotOpenNudgeCue(released), 'Spot open');
    });

    testWidgets('expire hold passed surfaces the cue', (tester) async {
      await _pumpCue(tester, hold: _expiredHold());
      expect(find.byKey(kFillPinSpotOpenNudgeKey), findsOneWidget);
      expect(find.text('Spot open'), findsOneWidget);
    });

    testWidgets('Can\'t / release hold passed surfaces the cue',
        (tester) async {
      await _pumpCue(tester, hold: _releasedHold());
      expect(find.byKey(kFillPinSpotOpenNudgeKey), findsOneWidget);
      expect(find.text('Spot open'), findsOneWidget);
    });

    testWidgets('idle / sit / coming-with-time stay quiet when hold passed',
        (tester) async {
      await _pumpCue(tester, hold: ComingHoldState.idle);
      expect(_cueVisible(), isFalse);

      await _pumpCue(tester, hold: _startComing());
      expect(_cueVisible(), isFalse);

      final seated = reduceComingHold(
        current: _startComing(),
        event: ComingHoldEvent.sit,
      );
      expect(seated.shouldNudgeSpotOpen, isFalse);
      await _pumpCue(tester, hold: seated);
      expect(_cueVisible(), isFalse);
    });
  });

  group('one notify pipeline — no second path', () {
    test('header actions do not invent FirebaseMessaging / sendNotification',
        () {
      final src = _read(_kHeaderActions);
      expect(src.contains('sendNotificationToUsers'), isFalse);
      expect(src.contains('FirebaseMessaging'), isFalse);
      expect(src.contains('NotificationService'), isFalse);
      expect(
        _read(_kHeader).contains('fill_pin_live_activity.dart'),
        isFalse,
        reason:
            'Do not import fill_pin_live_activity.dart from '
            '$_kHeader (cycle). Keep apply / cue in the helper.',
      );
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

    test('lobby_notifier / bubble / chat_info are not this lease', () {
      expect(_read(_kLobbyNotifier).contains('debugHold'), isFalse);
      expect(_read(_kLobbyNotifier).contains('fillPinSpotOpenNudgeCue'), isFalse);
      expect(_read(_kMessageBubble).contains('debugHold'), isFalse);
      expect(_read(_kMessageBubble).contains('fillPinSpotOpenNudgeCue'), isFalse);
      expect(_read(_kChatInfo).contains('debugHold'), isFalse);
      expect(_read(_kChatInfo).contains('fillPinSpotOpenNudgeCue'), isFalse);
    });
  });
}
