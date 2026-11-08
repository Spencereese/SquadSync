import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/chat/fill_pin_thread_header.dart';
import 'package:squad_sync/services/fill_pin_nudge_audience.dart';
import 'package:squad_sync/services/peacock_self_notify.dart';

/// PIN WAVE — NEED ONE on Fill PIN header (RED, Harness).
///
/// [fillPinNudgeAudience] exists
/// (`lib/services/fill_pin_nudge_audience.dart`) and LA Can't /
/// expire already calls it (UID filter only). The live pin header
/// still has Sit / Coming / Can't + poll / public / share — **no
/// compact Need-one friend tap**.
///
/// Friend tap: Need one on the pin header → audience via
/// [fillPinNudgeAudience] + existing [NotificationService]
/// `sendNotificationToUsers` (one notify pipeline). Members who
/// already Sit / Coming / Can't are excluded. Not share-pin.
///
/// FAIL-until-green contracts (adversarial):
///
/// 1. Header exposes a compact Need-one control
///    (`kFillPinNeedOneKey` / `fill-pin-need-one`, label
///    `Need one`) beside Sit / Coming / Can't / poll / public /
///    share.
/// 2. Header or thin helper **calls** [fillPinNudgeAudience]
///    with `sitUids` / `comingUids` / `cantUids` so those
///    stances are excluded.
/// 3. Thin helper sends through
///    [NotificationService.sendNotificationToUsers] only —
///    no second FCM / `FirebaseMessaging` path. Not
///    [shareFillPin] / [fillPinSharePayload].
/// 4. XOR stays [planPeacockSelfNotify]. No lobby_notifier /
///    message_bubble / chat_info_screen dual-edit.
///
/// Do **not** put `NotificationService` in:
/// - `lib/chat/fill_pin_thread_header.dart` (header_actions
///   suite forbids it)
/// - `lib/chat/fill_pin_header_actions.dart` (same)
/// - `lib/services/fill_pin_nudge_audience.dart` (audience
///   suite keeps the filter send-free)
///
/// Preferred helper (new file):
///
/// ```
/// lib/chat/fill_pin_need_one.dart
/// // or lib/services/fill_pin_need_one.dart
///
/// Future<void> nudgeFillPinNeedOne({ ... }) async {
///   final audience = fillPinNudgeAudience(
///     memberUids: memberUids,
///     sitUids: sitUids,
///     comingUids: comingUids,
///     cantUids: cantUids,
///   );
///   await NotificationService.sendNotificationToUsers(
///     title: ...,
///     body: ...,
///     recipientUids: audience.toList(),
///   );
/// }
/// ```
///
/// Header imports the helper (and/or the audience filter) —
/// friend tap → helper. Compact IconButton like poll / share.
///
/// Preferred friend-visible key:
///
/// ```
/// const kFillPinNeedOneKey = Key('fill-pin-need-one');
/// ```
///
/// Loop lease (Harness does not edit `lib/**` or bump pubspec;
/// still 3.4.185+187 until Loop greens → 3.4.186+188):
/// 1. `lib/chat/fill_pin_thread_header.dart` — compact Need-one
///    control; call into helper / [fillPinNudgeAudience]
/// 2. `lib/services/fill_pin_nudge_audience.dart` — reuse
///    (prefer untouched) + thin helper
///    `lib/chat/fill_pin_need_one.dart` or
///    `lib/services/fill_pin_need_one.dart` that calls
///    [fillPinNudgeAudience] +
///    [NotificationService.sendNotificationToUsers]
/// 3. `pubspec.yaml` bump to exactly `3.4.186+188` when Loop
///    greens
///
/// Never dual-edit `lobby_notifier.dart`. No `message_bubble` /
/// `chat_info_screen` rewrite. No GATES / AASA / Tonight /
/// merge / device. Not share-pin.
///
/// Out of scope: GATES / AASA / Tonight / merge / device claim /
/// pubspec bump (Harness).
const _kHeader = 'lib/chat/fill_pin_thread_header.dart';
const _kAudience = 'lib/services/fill_pin_nudge_audience.dart';
const _kHeaderActions = 'lib/chat/fill_pin_header_actions.dart';
const _kShare = 'lib/services/fill_pin_share.dart';
const _kLobbyNotifier = 'lib/presentation/notifiers/lobby_notifier.dart';
const _kMessageBubble = 'lib/chat/message_bubble.dart';
const _kChatInfo = 'lib/chat/screens/chat_info_screen.dart';
const _kHelperCandidates = [
  'lib/chat/fill_pin_need_one.dart',
  'lib/services/fill_pin_need_one.dart',
  'lib/chat/fill_pin_need_one_nudge.dart',
  'lib/services/fill_pin_need_one_nudge.dart',
];

const kFillPinNeedOneKeyProbe = Key('fill-pin-need-one');

String _read(String path) => File(path).readAsStringSync();

/// Header plus Need-one helper under lease. Not audience
/// definition, not share, not header_actions, not LA.
String _needOneLeaseSource() {
  final chunks = [_read(_kHeader)];
  for (final path in _kHelperCandidates) {
    if (File(path).existsSync()) {
      chunks.add(_read(path));
    }
  }
  return chunks.join('\n');
}

bool _exposesNeedOneControl(String src) {
  return src.contains('kFillPinNeedOneKey') ||
      src.contains('fill-pin-need-one');
}

bool _labelsNeedOne(String src) {
  return src.contains("'Need one'") ||
      src.contains('"Need one"') ||
      src.contains('kFillPinNeedOneLabel');
}

bool _callsAudienceFilter(String src) {
  return src.contains('fillPinNudgeAudience');
}

bool _passesStanceExclusions(String src) {
  return src.contains('sitUids') &&
      src.contains('comingUids') &&
      src.contains('cantUids');
}

bool _usesExistingNotifyPipeline(String src) {
  return src.contains('NotificationService') &&
      src.contains('sendNotificationToUsers');
}

bool _namesNeedOneHelper(String src) {
  return src.contains('nudgeFillPinNeedOne') ||
      src.contains('sendFillPinNeedOne') ||
      src.contains('notifyFillPinNeedOne') ||
      src.contains('fillPinNeedOne');
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

void main() {
  group('header exposes compact Need-one friend-visible control', () {
    test('header or helper declares Need-one key', () {
      expect(File(_kHeader).existsSync(), isTrue);
      expect(File(_kAudience).existsSync(), isTrue);
      expect(
        _exposesNeedOneControl(_needOneLeaseSource()),
        isTrue,
        reason:
            'Loop lease: expose compact Need one on the Fill PIN '
            'header (or a dedicated fill_pin_need_one helper). '
            'Prefer kFillPinNeedOneKey / Key(\'fill-pin-need-one\') '
            'beside Sit / Coming / Can\'t / poll / public / share. '
            'FAIL until that friend-visible control exists.',
      );
    });

    testWidgets('header row shows Need-one, distinct from share',
        (tester) async {
      await _pumpHeader(tester);

      expect(find.byKey(kFillPinThreadHeaderKey), findsOneWidget);
      expect(find.byKey(kFillPinShareKey), findsOneWidget);
      expect(find.byKey(kFillPinPollKey), findsOneWidget);
      expect(find.byKey(kFillPinPublicSwitchKey), findsOneWidget);

      expect(
        find.byKey(kFillPinNeedOneKeyProbe),
        findsOneWidget,
        reason:
            'Friend-visible Need-one control missing. Add '
            'Key(\'fill-pin-need-one\') / kFillPinNeedOneKey on '
            'the header row. Not the share-pin control.',
      );
      expect(
        find.byKey(kFillPinNeedOneKeyProbe),
        isNot(find.byKey(kFillPinShareKey)),
      );
    });

    test('header or helper labels Need one', () {
      expect(
        _labelsNeedOne(_needOneLeaseSource()),
        isTrue,
        reason:
            'Loop lease: friend-visible label Need one (tooltip, '
            'Semantics, or text). Compact IconButton like poll / '
            'share is fine.',
      );
    });
  });

  group('audience excludes members who already Sit / Coming / Can\'t', () {
    test('fillPinNudgeAudience drops Sit / Coming / Can\'t UIDs', () {
      expect(
        fillPinNudgeAudience(
          memberUids: const ['u1', 'u2', 'u3', 'u4', 'u5'],
          sitUids: const ['u1'],
          comingUids: const ['u2'],
          cantUids: const ['u3'],
        ).toSet(),
        {'u4', 'u5'},
      );
    });

    test('empty when every member already Sit / Coming / Can\'t', () {
      expect(
        fillPinNudgeAudience(
          memberUids: const ['u1', 'u2', 'u3'],
          sitUids: const ['u1'],
          comingUids: const ['u2'],
          cantUids: const ['u3'],
        ),
        isEmpty,
      );
    });

    test(
      'Need-one caller passes sitUids / comingUids / cantUids into the filter',
      () {
        final src = _needOneLeaseSource();
        expect(
          _callsAudienceFilter(src) && _passesStanceExclusions(src),
          isTrue,
          reason:
              'Loop lease: header or fill_pin_need_one helper must '
              'call fillPinNudgeAudience(memberUids:, sitUids:, '
              'comingUids:, cantUids:) so Sit / Coming / Can\'t '
              'are excluded. Audience file alone is not the header '
              'caller. FAIL until the Need-one path wires those '
              'named stance lists.',
        );
      },
    );
  });

  group('Need-one calls fillPinNudgeAudience + one notify pipeline', () {
    test('header or helper imports fill_pin_nudge_audience.dart', () {
      final src = _needOneLeaseSource();
      expect(
        src.contains('fill_pin_nudge_audience.dart'),
        isTrue,
        reason:
            'Loop lease: import fill_pin_nudge_audience.dart from '
            '$_kHeader or a thin fill_pin_need_one helper so '
            'Need-one can call fillPinNudgeAudience.',
      );
    });

    test('header or helper invokes fillPinNudgeAudience', () {
      expect(
        _callsAudienceFilter(_needOneLeaseSource()),
        isTrue,
        reason:
            'fillPinNudgeAudience exists but is not called from '
            'the pin-header Need-one path. Wire the filter into '
            'the header or fill_pin_need_one helper. Do not invent '
            'a second audience reducer.',
      );
    });

    test(
      'thin helper names Need-one and sends via NotificationService',
      () {
        final src = _needOneLeaseSource();
        expect(
          _namesNeedOneHelper(src),
          isTrue,
          reason:
              'Loop lease: name the thin helper nudgeFillPinNeedOne '
              '/ sendFillPinNeedOne / notifyFillPinNeedOne / '
              'fillPinNeedOne. Header friend-tap calls it. Not '
              'shareFillPin.',
        );
        expect(
          _usesExistingNotifyPipeline(src),
          isTrue,
          reason:
              'One notify pipeline only: '
              'NotificationService.sendNotificationToUsers with '
              'fillPinNudgeAudience recipients. Put the send in '
              'fill_pin_need_one.dart — not the header, not '
              'fill_pin_nudge_audience.dart, not '
              'fill_pin_header_actions.dart (those suites forbid '
              'NotificationService). FAIL until the helper exists '
              'and calls the existing send.',
        );
      },
    );

    testWidgets('Need-one tap is wired (control must exist first)',
        (tester) async {
      await _pumpHeader(tester);
      expect(
        find.byKey(kFillPinNeedOneKeyProbe),
        findsOneWidget,
        reason:
            'Loop lease: Need-one on the header must call '
            'fillPinNudgeAudience + NotificationService.'
            'sendNotificationToUsers. Add the control first.',
      );
      await tester.tap(find.byKey(kFillPinNeedOneKeyProbe));
      await tester.pump();
    });
  });

  group('one notify pipeline — not share-pin — XOR planPeacockSelfNotify',
      () {
    test('Need-one lease is not share-pin and not a second FCM path', () {
      final src = _needOneLeaseSource();
      final header = _read(_kHeader);

      expect(
        header.contains('fill_pin_live_activity.dart'),
        isFalse,
        reason:
            'Do not import fill_pin_live_activity.dart from '
            '$_kHeader (cycle). Need-one notify lives in a helper.',
      );
      expect(header.contains('sendNotificationToUsers'), isFalse);
      expect(header.contains('FirebaseMessaging'), isFalse);
      expect(header.contains('NotificationService'), isFalse);

      expect(src.contains('FirebaseMessaging'), isFalse);
      expect(src.contains('functions.invoke'), isFalse);
      expect(
        src.contains('send-push-notification'),
        isFalse,
        reason:
            'Do not invent a second Edge/FCM send. Reuse '
            'NotificationService.sendNotificationToUsers.',
      );

      for (final path in _kHelperCandidates) {
        if (!File(path).existsSync()) continue;
        final helper = _read(path);
        expect(
          helper.contains('shareFillPin'),
          isFalse,
          reason: 'Need-one is not share-pin.',
        );
        expect(helper.contains('fillPinSharePayload'), isFalse);
        expect(helper.contains('FirebaseMessaging'), isFalse);
      }

      expect(File(_kShare).existsSync(), isTrue);
      expect(_read(_kShare).contains('shareFillPin'), isTrue);
      expect(
        _read(_kAudience).contains('NotificationService'),
        isFalse,
        reason:
            'Keep fill_pin_nudge_audience.dart a UID filter. '
            'Send stays in the Need-one helper.',
      );
      expect(
        _read(_kHeaderActions).contains('NotificationService'),
        isFalse,
        reason:
            'Do not hang Need-one send on fill_pin_header_actions '
            '(header_actions suite forbids NotificationService).',
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
        _needOneLeaseSource().contains('FirebaseMessaging'),
        isFalse,
      );
    });

    test('lobby_notifier / bubble / chat_info are not the Need-one lease', () {
      expect(_read(_kLobbyNotifier).contains('fill-pin-need-one'), isFalse);
      expect(_read(_kLobbyNotifier).contains('kFillPinNeedOneKey'), isFalse);
      expect(_read(_kLobbyNotifier).contains('nudgeFillPinNeedOne'), isFalse);
      expect(_read(_kLobbyNotifier).contains('fill_pin_need_one'), isFalse);
      expect(_read(_kMessageBubble).contains('fill-pin-need-one'), isFalse);
      expect(_read(_kMessageBubble).contains('fill_pin_need_one'), isFalse);
      expect(_read(_kChatInfo).contains('fill-pin-need-one'), isFalse);
      expect(_read(_kChatInfo).contains('fill_pin_need_one'), isFalse);
    });
  });
}
