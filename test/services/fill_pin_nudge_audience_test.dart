import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/services/fill_pin_nudge_audience.dart';
import 'package:squad_sync/services/peacock_self_notify.dart';

/// PIN WAVE P2 — NUDGE AUDIENCE (RED, Tester-owned).
///
/// Pure-Dart "need one" audience filter for a Fill PIN. Maps UIDs only.
/// Not a send. No chat UI. No Tonight. Share-pin-not-chat is queued
/// elsewhere — this RED does not start it.
///
/// Contract Loop must implement (do not invent a notify send pipeline):
///
/// 1. [fillPinNudgeAudience] (`lib/services/fill_pin_nudge_audience.dart`)
///    — "need one" audience = only people who did **not** Sit / Coming /
///    Can't on **this pin**.
/// 2. Anyone who already Sit / Coming / Can't is **excluded**.
/// 3. Pure filter / reducer. Output shape is a [Set] / [List] of UIDs
///    (or equivalent [Iterable<String>]) — not a send plan, not FCM,
///    not [NotificationService].
/// 4. XOR stays [planPeacockSelfNotify]. Do not invent a second notify
///    path in this file.
///
/// Inputs (named, matching existing recipient filters):
/// - [memberUids] — candidate pool on this pin / group
/// - [sitUids] / [comingUids] / [cantUids] — already responded
///
/// Blanks, whitespace, and duplicate member UIDs are dropped. A stance
/// UID that is not in [memberUids] never appears in the audience.
///
/// Loop lease (≤3 product files + pubspec on green — Tester does not
/// edit `lib/**` or bump pubspec):
/// 1. `lib/services/fill_pin_nudge_audience.dart` (new; primary)
/// 2. Optional tiny related helper if already patterned — keep ≤3
///
/// Out of scope: chat_screen / chat_input_bar / Tonight-tab / AASA /
/// GATES / merge / share-pin-not-chat / pubspec bump (Tester).
void main() {
  Iterable<String> audience({
    required Iterable<String> memberUids,
    Iterable<String> sitUids = const [],
    Iterable<String> comingUids = const [],
    Iterable<String> cantUids = const [],
  }) {
    return fillPinNudgeAudience(
      memberUids: memberUids,
      sitUids: sitUids,
      comingUids: comingUids,
      cantUids: cantUids,
    );
  }

  group('need one audience = people who did not Sit / Coming / Can\'t', () {
    test(
      'includes only members who have not Sit / Coming / Can\'t on this pin',
      () {
        expect(
          audience(
            memberUids: const ['u1', 'u2', 'u3', 'u4', 'u5'],
            sitUids: const ['u1'],
            comingUids: const ['u2'],
            cantUids: const ['u3'],
          ).toSet(),
          {'u4', 'u5'},
        );
      },
    );

    test('all unanswered members remain when nobody has a stance', () {
      expect(
        audience(memberUids: const ['u1', 'u2', 'u3']).toSet(),
        {'u1', 'u2', 'u3'},
      );
    });

    test('empty when every member already Sit / Coming / Can\'t', () {
      expect(
        audience(
          memberUids: const ['u1', 'u2', 'u3'],
          sitUids: const ['u1'],
          comingUids: const ['u2'],
          cantUids: const ['u3'],
        ),
        isEmpty,
      );
    });
  });

  group('Sit / Coming / Can\'t are excluded from audience', () {
    test('Sit on this pin is excluded', () {
      expect(
        audience(
          memberUids: const ['u1', 'u2'],
          sitUids: const ['u1'],
        ).toSet(),
        {'u2'},
      );
      expect(
        audience(
          memberUids: const ['u1', 'u2'],
          sitUids: const ['u1'],
        ).contains('u1'),
        isFalse,
      );
    });

    test('Coming on this pin is excluded', () {
      expect(
        audience(
          memberUids: const ['u1', 'u2'],
          comingUids: const ['u2'],
        ).toSet(),
        {'u1'},
      );
      expect(
        audience(
          memberUids: const ['u1', 'u2'],
          comingUids: const ['u2'],
        ).contains('u2'),
        isFalse,
      );
    });

    test('Can\'t on this pin is excluded', () {
      expect(
        audience(
          memberUids: const ['u1', 'u2', 'u3'],
          cantUids: const ['u3'],
        ).toSet(),
        {'u1', 'u2'},
      );
      expect(
        audience(
          memberUids: const ['u1', 'u2', 'u3'],
          cantUids: const ['u3'],
        ).contains('u3'),
        isFalse,
      );
    });

    test('anyone who already Sit / Coming / Can\'t is excluded', () {
      final uids = audience(
        memberUids: const ['sit-1', 'coming-1', 'cant-1', 'open-1', 'open-2'],
        sitUids: const ['sit-1'],
        comingUids: const ['coming-1'],
        cantUids: const ['cant-1'],
      ).toSet();

      expect(uids, {'open-1', 'open-2'});
      expect(uids.contains('sit-1'), isFalse);
      expect(uids.contains('coming-1'), isFalse);
      expect(uids.contains('cant-1'), isFalse);
    });
  });

  group('output shape is UIDs only — not a send', () {
    test('maps a set/list of UIDs (or equivalent), not a send plan', () {
      final result = fillPinNudgeAudience(
        memberUids: const ['u1', 'u2', 'u3'],
        sitUids: const ['u1'],
        comingUids: const ['u2'],
      );

      expect(result, isA<Iterable<String>>());
      expect(result, everyElement(isA<String>()));
      expect(result.toSet(), {'u3'});
      expect(result, isNot(isA<Map>()));
    });

    test('drops blanks, whitespace, and duplicate member UIDs', () {
      expect(
        audience(
          memberUids: const ['u1', 'u2', ' u2 ', '', '  ', 'u3', 'u1'],
          sitUids: const ['u1'],
        ).toSet(),
        {'u2', 'u3'},
      );
    });

    test('stance UIDs outside the member pool never appear', () {
      expect(
        audience(
          memberUids: const ['u1', 'u2'],
          sitUids: const ['stranger-sit'],
          comingUids: const ['stranger-coming'],
          cantUids: const ['stranger-cant'],
        ).toSet(),
        {'u1', 'u2'},
      );
    });

    test('XOR stays planPeacockSelfNotify — filter is not a send pipeline', () {
      expect(
        planPeacockSelfNotify(
          notificationId: 'n1',
          currentUid: 'u1',
          isForeground: true,
          locallyPresentedIds: {},
        ).wouldDoubleNotifySelf,
        isFalse,
      );

      final src =
          File('lib/services/fill_pin_nudge_audience.dart').readAsStringSync();
      expect(src.contains('sendNotificationToUsers'), isFalse);
      expect(src.contains('FirebaseMessaging'), isFalse);
      expect(src.contains('NotificationService'), isFalse);
      expect(
        src.contains('fillPinNudgeAudience'),
        isTrue,
        reason: 'Loop lease: expose fillPinNudgeAudience in the new file.',
      );
    });
  });
}
