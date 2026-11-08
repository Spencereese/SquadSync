import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/services/fill_pin_poll.dart';
import 'package:squad_sync/services/peacock_self_notify.dart';

/// PIN WAVE P3A — POLL-ON-PIN (RED, Tester-owned).
///
/// Pure-Dart attach / resolve / detach for a poll that lives on a Fill
/// PIN (lobby id). Not a free-floating chat message. No chat UI. No
/// Tonight. No second notify pipeline.
///
/// Contract Loop must implement (leave RED until the product file
/// exists under `lib/services/`):
///
/// 1. [attachPollToPin] binds a poll to the pin (lobby id), not a
///    chat-message id. [FillPinPoll.chatMessageId] stays null.
/// 2. [resolvePollForPin] (`pinId`) returns the attached poll for
///    **that pin only**.
/// 3. Ending / clearing the pin ([detachPollOnPinClear]) detaches
///    the poll — resolve returns null.
/// 4. Pin A's poll must not resolve under pin B.
///
/// Loop lease (≤3 product files + pubspec on green — Tester does not
/// edit `lib/**` or bump pubspec):
/// 1. `lib/services/fill_pin_poll.dart` (new; primary) — attach /
///    [resolvePollForPin] / detach-on-clear
///
/// XOR stays [planPeacockSelfNotify]. Do not invent a second notify
/// path in this file.
///
/// Out of scope: chat_screen / chat_input_bar / Tonight-tab / AASA /
/// GATES / merge / pubspec bump (Tester).
void main() {
  setUp(resetFillPinPollStore);
  tearDown(resetFillPinPollStore);

  group('poll attaches to the pin (lobby id), not a chat message', () {
    test('attachPollToPin binds pollId to pinId (lobby id)', () {
      final attached = attachPollToPin(
        pinId: 'pin-1',
        pollId: 'poll-warzone-need-one',
      );

      expect(attached.pinId, 'pin-1');
      expect(attached.pollId, 'poll-warzone-need-one');
      expect(
        attached.chatMessageId,
        isNull,
        reason: 'Poll must attach to the pin (lobby id), not a chat message.',
      );
    });

    test('attached poll is not keyed as a free-floating chat message', () {
      attachPollToPin(pinId: 'lobby-42', pollId: 'poll-42');
      final resolved = resolvePollForPin('lobby-42');

      expect(resolved, isNotNull);
      expect(resolved!.pinId, 'lobby-42');
      expect(resolved.pollId, 'poll-42');
      expect(resolved.chatMessageId, isNull);
    });
  });

  group('resolvePollForPin returns the attached poll for that pin only', () {
    test('resolvePollForPin(pinId) returns the poll attached to that pin', () {
      attachPollToPin(pinId: 'pin-1', pollId: 'poll-a');

      final resolved = resolvePollForPin('pin-1');
      expect(resolved, isNotNull);
      expect(resolved!.pinId, 'pin-1');
      expect(resolved.pollId, 'poll-a');
    });

    test('unknown pin has no attached poll', () {
      attachPollToPin(pinId: 'pin-1', pollId: 'poll-a');
      expect(resolvePollForPin('pin-missing'), isNull);
    });
  });

  group('ending / clearing the pin detaches the poll', () {
    test('detachPollOnPinClear makes resolvePollForPin return null', () {
      attachPollToPin(pinId: 'pin-1', pollId: 'poll-a');
      expect(resolvePollForPin('pin-1'), isNotNull);

      detachPollOnPinClear('pin-1');

      expect(
        resolvePollForPin('pin-1'),
        isNull,
        reason: 'Clearing / ending the pin must detach its poll.',
      );
    });

    test('clearing pin A does not detach pin B', () {
      attachPollToPin(pinId: 'pin-a', pollId: 'poll-a');
      attachPollToPin(pinId: 'pin-b', pollId: 'poll-b');

      detachPollOnPinClear('pin-a');

      expect(resolvePollForPin('pin-a'), isNull);
      expect(resolvePollForPin('pin-b')?.pollId, 'poll-b');
    });
  });

  group('pin A poll must not resolve under pin B', () {
    test('resolvePollForPin is pin-scoped — no cross-pin leak', () {
      attachPollToPin(pinId: 'pin-a', pollId: 'poll-a');
      attachPollToPin(pinId: 'pin-b', pollId: 'poll-b');

      final onA = resolvePollForPin('pin-a');
      final onB = resolvePollForPin('pin-b');

      expect(onA?.pollId, 'poll-a');
      expect(onA?.pinId, 'pin-a');
      expect(onB?.pollId, 'poll-b');
      expect(onB?.pinId, 'pin-b');
      expect(
        onB?.pollId,
        isNot('poll-a'),
        reason: "Pin A's poll must not resolve under pin B.",
      );
      expect(onA?.pollId, isNot('poll-b'));
    });
  });

  group('XOR stays planPeacockSelfNotify — not a send pipeline', () {
    test('Loop lease file exposes attach / resolve / detach-on-clear', () {
      expect(File('lib/services/fill_pin_poll.dart').existsSync(), isTrue);
      final src = File('lib/services/fill_pin_poll.dart').readAsStringSync();
      expect(src.contains('attachPollToPin'), isTrue);
      expect(src.contains('resolvePollForPin'), isTrue);
      expect(src.contains('detachPollOnPinClear'), isTrue);
    });

    test('XOR stays planPeacockSelfNotify — poll attach is not a send', () {
      expect(
        planPeacockSelfNotify(
          notificationId: 'n1',
          currentUid: 'u1',
          isForeground: true,
          locallyPresentedIds: {},
        ).wouldDoubleNotifySelf,
        isFalse,
      );

      final src = File('lib/services/fill_pin_poll.dart').readAsStringSync();
      expect(src.contains('sendNotificationToUsers'), isFalse);
      expect(src.contains('FirebaseMessaging'), isFalse);
      expect(src.contains('NotificationService'), isFalse);
    });
  });
}
