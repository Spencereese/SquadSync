import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/chat/fill_pin_group_row_badge.dart';
import 'package:squad_sync/chat/fill_pin_thread_header.dart';
import 'package:squad_sync/domain/entities/lobby.dart';
import 'package:squad_sync/domain/entities/lobby_state.dart';
import 'package:squad_sync/services/coming_hold_machine.dart';
import 'package:squad_sync/services/peacock_self_notify.dart';

/// PIN WAVE — GROUPS-ROW COMING CHROME on My Groups badge (RED).
///
/// debugHold + expire-tick just CLOSED on tip `5e48881` / 3.4.184+186.
/// Header already renders [FillPinSnapshot.comingCountdown] (mm:ss)
/// from [fillPinComingCountdownLabel] / [resolveFillPinForThread]
/// (`hold:`). My Groups row badge is still only
/// `gameName seatLabel` — no Coming chrome.
///
/// Friend sees: when hold is active, the Groups row badge shows
/// Coming mm:ss. Quiet when idle / expired (gameName + seatLabel
/// only).
///
/// Reuse the header snapshot field. Do **not** invent a second
/// countdown helper or a second notify path. Do not import
/// `fill_pin_live_activity.dart` from the badge (header already
/// forbids that cycle). Do not read
/// [FillPinLiveActivity.debugHold] (prod ban).
///
/// FAIL-until-green contracts (adversarial):
///
/// 1. Non-null time-like [comingCountdown] (`5:00` / `4:59`) →
///    [FillPinGroupRowBadgeView] shows that token.
/// 2. Idle / expired / null / empty / whitespace → badge stays
///    quiet on countdown. `gameName` + `seatLabel` only.
/// 3. Source-scan: [fill_pin_group_row_badge.dart] reads
///    `comingCountdown` (field default on the snapshot is not
///    enough — View still concatenates game + seats only).
/// 4. XOR stays [planPeacockSelfNotify]. No lobby_notifier /
///    message_bubble / chat_info_screen dual-edit.
///
/// Loop lease (Harness does not edit `lib/**` or bump pubspec;
/// still 3.4.184+186 until Loop greens → 3.4.185+187):
/// 1. `lib/chat/fill_pin_group_row_badge.dart` — show
///    [FillPinSnapshot.comingCountdown] on
///    [FillPinGroupRowBadgeView] when set; stay quiet when
///    null / empty. Host may pass `hold:` into
///    [resolveFillPinForThread] (header snapshot already wired)
///    — tiny related ≤3 if needed:
///    `lib/chat/fill_pin_thread_header.dart` /
///    `lib/chat/fill_pin_header_actions.dart`
///    (`listenFillPinHeaderHold`) so the live Groups row
///    actually receives a non-null label. Prefer no
///    `debugHold`.
/// 2. `pubspec.yaml` bump to exactly `3.4.185+187` when Loop
///    greens
///
/// Never dual-edit `lobby_notifier.dart`. No `message_bubble` /
/// `chat_info_screen` rewrite. No GATES / AASA / Tonight /
/// merge / device.
///
/// Out of scope: GATES / AASA / Tonight / merge / device claim /
/// pubspec bump (Tester).
const _kBadge = 'lib/chat/fill_pin_group_row_badge.dart';
const _kHeader = 'lib/chat/fill_pin_thread_header.dart';
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

FillPinSnapshot _snap({String? comingCountdown}) {
  return FillPinSnapshot(
    lobbyId: 'pin-1',
    gameName: 'Warzone',
    seated: 2,
    maxSpots: 4,
    seatedUids: const ['u1', 'u2'],
    comingCountdown: comingCountdown,
  );
}

Future<void> _pumpView(WidgetTester tester, FillPinSnapshot snapshot) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: FillPinGroupRowBadgeView(snapshot: snapshot),
      ),
    ),
  );
}

Iterable<String> _badgeTexts(WidgetTester tester) {
  return tester
      .widgetList<Text>(
        find.descendant(
          of: find.byKey(kFillPinGroupRowBadgeKey),
          matching: find.byType(Text),
        ),
      )
      .map((t) => t.data ?? '')
      .where((s) => s.isNotEmpty);
}

void _expectQuietCountdown(WidgetTester tester) {
  expect(find.byKey(kFillPinGroupRowBadgeKey), findsOneWidget);
  expect(find.byKey(kFillPinGroupRowBadgeSeatKey), findsOneWidget);
  expect(find.text('Warzone 2/4'), findsOneWidget);
  for (final text in _badgeTexts(tester)) {
    expect(
      _kMmSs.hasMatch(text),
      isFalse,
      reason:
          'Idle / expired / empty comingCountdown must stay quiet. '
          'Groups row badge should be gameName + seatLabel only '
          '(no mm:ss Coming chrome). Found "$text".',
    );
    expect(
      text.toLowerCase().contains('coming'),
      isFalse,
      reason:
          'No Coming chrome when countdown is null / empty. '
          'Found "$text".',
    );
  }
}

void main() {
  group('active comingCountdown → Groups row shows mm:ss', () {
    testWidgets('FillPinGroupRowBadgeView shows 5:00 when set', (tester) async {
      await _pumpView(tester, _snap(comingCountdown: '5:00'));

      expect(find.byKey(kFillPinGroupRowBadgeKey), findsOneWidget);
      expect(find.textContaining('Warzone'), findsWidgets);
      expect(find.textContaining('2/4'), findsWidgets);
      expect(
        find.textContaining('5:00'),
        findsOneWidget,
        reason:
            'Loop lease: FillPinGroupRowBadgeView must show '
            'snapshot.comingCountdown when set (reuse header '
            'mm:ss). Today the badge concatenates gameName + '
            'seatLabel only.',
      );
    });

    testWidgets('ticked remaining (4:59) stays visible on the row',
        (tester) async {
      await _pumpView(tester, _snap(comingCountdown: '4:59'));

      expect(
        find.textContaining('4:59'),
        findsOneWidget,
        reason:
            'Coming chrome must follow the snapshot label, not a '
            'hard-coded 5:00. Header uses fillPinComingCountdownLabel.',
      );
    });

    testWidgets(
        'resolver hold → comingCountdown → badge view (reuse header wire)',
        (tester) async {
      final lobby = _pin(id: 'pin-1', chatGroupId: 'group-1');
      final hold = _startComing();
      expect(hold.phase, ComingHoldPhase.coming);
      expect(hold.remaining, kComingHoldDuration);

      final snapshot = resolveFillPinForThread(
        state: _stateWithPin(lobby),
        chatGroupId: 'group-1',
        hold: hold,
      );
      expect(snapshot, isNotNull);
      expect(snapshot!.comingCountdown, isNotNull);
      expect(snapshot.comingCountdown, fillPinComingCountdownLabel(hold));

      await _pumpView(tester, snapshot);
      expect(
        find.textContaining(snapshot.comingCountdown!),
        findsOneWidget,
        reason:
            'Header already populates comingCountdown from hold. '
            'Groups row View must render that label.',
      );
    });
  });

  group('idle / expired / empty → Groups row stays quiet', () {
    testWidgets('null comingCountdown is gameName + seatLabel only',
        (tester) async {
      await _pumpView(tester, _snap());
      _expectQuietCountdown(tester);
    });

    testWidgets('empty / whitespace comingCountdown stays quiet',
        (tester) async {
      await _pumpView(tester, _snap(comingCountdown: ''));
      _expectQuietCountdown(tester);

      await _pumpView(tester, _snap(comingCountdown: '   '));
      _expectQuietCountdown(tester);
    });

    testWidgets('omitted hold / expired hold stay quiet on the view',
        (tester) async {
      final lobby = _pin(id: 'pin-1', chatGroupId: 'group-1');
      final idle = resolveFillPinForThread(
        state: _stateWithPin(lobby),
        chatGroupId: 'group-1',
      );
      expect(idle, isNotNull);
      expect(idle!.comingCountdown, isNull);

      await _pumpView(tester, idle);
      _expectQuietCountdown(tester);

      final expired = reduceComingHold(
        current: _startComing(),
        event: ComingHoldEvent.tick,
        elapsed: kComingHoldDuration,
      );
      expect(expired.phase, ComingHoldPhase.expired);
      final expiredSnap = resolveFillPinForThread(
        state: _stateWithPin(lobby),
        chatGroupId: 'group-1',
        hold: expired,
      );
      expect(expiredSnap!.comingCountdown, isNull);

      await _pumpView(tester, expiredSnap);
      _expectQuietCountdown(tester);
    });
  });

  group('badge source wires comingCountdown — no second notify path', () {
    test('badge view reads comingCountdown (not game+seats only)', () {
      expect(File(_kBadge).existsSync(), isTrue);
      expect(File(_kHeader).existsSync(), isTrue);
      final src = _read(_kBadge);
      expect(src.contains('FillPinGroupRowBadgeView'), isTrue);
      expect(src.contains('gameName'), isTrue);
      expect(src.contains('seatLabel'), isTrue);
      expect(
        src.contains('comingCountdown'),
        isTrue,
        reason:
            'Loop lease: FillPinGroupRowBadgeView must read '
            'snapshot.comingCountdown and show the mm:ss when '
            'non-null / non-empty. Header already assigns the '
            'field — the Groups row still ignores it.',
      );
    });

    test('header snapshot wire stays; badge does not import live_activity', () {
      final header = _read(_kHeader);
      expect(header.contains('comingCountdown:'), isTrue);
      expect(header.contains('fillPinComingCountdownLabel'), isTrue);

      final src = _read(_kBadge);
      expect(src.contains('fill_pin_live_activity.dart'), isFalse);
      expect(src.contains('debugHold'), isFalse);
      expect(src.contains('sendNotificationToUsers'), isFalse);
      expect(src.contains('FirebaseMessaging'), isFalse);
      expect(src.contains('NotificationService'), isFalse);
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
      expect(_read(_kLobbyNotifier).contains('fill_pin_group_row_badge'), isFalse);
      expect(_read(_kMessageBubble).contains('comingCountdown'), isFalse);
      expect(_read(_kChatInfo).contains('comingCountdown'), isFalse);
    });
  });
}
