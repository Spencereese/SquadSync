import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/services/fill_pin_poll.dart';
import 'package:squad_sync/services/peacock_self_notify.dart';

/// PIN WAVE P3A-wire — POLL LIVE HEADER CALLER (RED, Tester-owned).
///
/// [attachPollToPin] / [resolvePollForPin] / [detachPollOnPinClear]
/// exist (`lib/services/fill_pin_poll.dart`; units CLOSED) but the
/// live Fill PIN path does not invoke them. App Tester: WIRED no.
///
/// This file is source-lease / import-call only. It fails until the
/// live caller wires the existing pin-scoped poll attach / resolve /
/// detach in. Do not invent a second notify send pipeline. XOR stays
/// [planPeacockSelfNotify].
///
/// Live poll caller (friend-visible pin header):
/// - `lib/chat/fill_pin_thread_header.dart`
///   [FillPinThreadHeader] is the friend-visible pin header (game +
///   n/max + Share). That site must import + call [attachPollToPin]
///   and/or [resolvePollForPin] so a friend tap attaches / resolves
///   the poll on that pin. Pin-scoped. [FillPinPoll.chatMessageId]
///   stays null.
///
/// Clear / end: [detachPollOnPinClear] must appear in the header
/// source on the clear/end pin path. If Loop uses a named end helper,
/// that helper must live in the same file so this source-scan still
/// sees the call site.
///
/// Loop lease (≤3 product files + pubspec on green — Tester does not
/// edit `lib/**` or bump pubspec; still 3.4.178+180 until Loop greens
/// → 3.4.179+181):
/// 1. `lib/chat/fill_pin_thread_header.dart` — primary; import +
///    call [attachPollToPin] and/or [resolvePollForPin] on friend
///    tap, and [detachPollOnPinClear] on clear/end
/// 2. Optional: `lib/services/fill_pin_poll.dart` only if a tiny
///    helper tweak is needed — prefer untouched
/// 3. `pubspec.yaml` bump to exactly `3.4.179+181` when Loop greens
///
/// Never dual-edit `lobby_notifier.dart`. Do not invent a new
/// poll store / pipeline. Never edit `message_bubble` or
/// `chat_info_screen`.
///
/// Out of scope: chat_screen / chat_input_bar / chat_info_screen /
/// lobby_notifier dual-edit / Tonight-tab / AASA / GATES / merge /
/// P3C / pubspec bump (Tester).
const _kLivePollCaller = 'lib/chat/fill_pin_thread_header.dart';
const _kPoll = 'lib/services/fill_pin_poll.dart';
const _kLobbyNotifier = 'lib/presentation/notifiers/lobby_notifier.dart';

String _read(String path) => File(path).readAsStringSync();

bool _callsAttachOrResolve(String src) {
  return src.contains('attachPollToPin') || src.contains('resolvePollForPin');
}

void main() {
  setUp(resetFillPinPollStore);
  tearDown(resetFillPinPollStore);

  group('live pin-header caller invokes fill pin poll', () {
    test('live Fill PIN caller file exists', () {
      expect(File(_kLivePollCaller).existsSync(), isTrue);
      expect(File(_kPoll).existsSync(), isTrue);
    });

    test(
      'live caller is still the pin header (create/update surface)',
      () {
        final src = _read(_kLivePollCaller);
        expect(src.contains('FillPinThreadHeader'), isTrue);
        expect(src.contains('resolveFillPinForThread'), isTrue);
        expect(src.contains('kFillPinThreadHeaderKey'), isTrue);
        expect(src.contains('kFillPinShareKey'), isTrue);
      },
    );

    test(
      'live pin-header caller imports fill_pin_poll.dart',
      () {
        final src = _read(_kLivePollCaller);
        expect(
          src.contains('fill_pin_poll.dart'),
          isTrue,
          reason:
              'Loop lease: import fill_pin_poll.dart from '
              '$_kLivePollCaller so the live pin header can '
              'call attachPollToPin and/or resolvePollForPin.',
        );
      },
    );

    test(
      'live pin-header caller invokes attachPollToPin '
      'and/or resolvePollForPin',
      () {
        final src = _read(_kLivePollCaller);
        expect(
          _callsAttachOrResolve(src),
          isTrue,
          reason:
              'App Tester + CoS: attachPollToPin / '
              'resolvePollForPin exist but are not called '
              'from the live pin path. Wire friend-tap '
              'attach/resolve into $_kLivePollCaller '
              '(pin-scoped; chatMessageId stays null). '
              'Do not invent a new poll store.',
        );
      },
    );

    test(
      'live pin-header caller invokes detachPollOnPinClear '
      'on clear/end',
      () {
        final src = _read(_kLivePollCaller);
        expect(
          src.contains('detachPollOnPinClear'),
          isTrue,
          reason:
              'Loop lease: call detachPollOnPinClear from the '
              'clear/end pin path in $_kLivePollCaller (or a '
              'named end helper in that same file). Header '
              'source must show the call site.',
        );
      },
    );

    test(
      'lobby_notifier is not the poll lease (no dual-edit)',
      () {
        final notifier = _read(_kLobbyNotifier);
        expect(notifier.contains('fill_pin_poll.dart'), isFalse);
        expect(notifier.contains('attachPollToPin'), isFalse);
        expect(notifier.contains('resolvePollForPin'), isFalse);
        expect(notifier.contains('detachPollOnPinClear'), isFalse);
      },
    );
  });

  group('poll stays pin-scoped non-chat — XOR planPeacockSelfNotify', () {
    test('store stays non-chat; no notify send in store or live caller', () {
      final attached = attachPollToPin(
        pinId: 'pin-1',
        pollId: 'poll-warzone-need-one',
      );
      expect(attached.chatMessageId, isNull);
      expect(
        const FillPinPoll(pinId: 'pin-x', pollId: 'poll-x').chatMessageId,
        isNull,
      );

      final store = _read(_kPoll);
      expect(store.contains('sendNotificationToUsers'), isFalse);
      expect(store.contains('FirebaseMessaging'), isFalse);
      expect(store.contains('NotificationService'), isFalse);

      final live = _read(_kLivePollCaller);
      expect(live.contains('sendNotificationToUsers'), isFalse);
      expect(live.contains('FirebaseMessaging'), isFalse);
      expect(live.contains('NotificationService'), isFalse);
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

      final live = _read(_kLivePollCaller);
      expect(live.contains('sendNotificationToUsers'), isFalse);
      expect(live.contains('FirebaseMessaging'), isFalse);
      expect(live.contains('NotificationService'), isFalse);
    });
  });
}
